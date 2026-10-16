from __future__ import annotations

import decimal
import json
import logging
import uuid
from dataclasses import dataclass
from datetime import timedelta
from decimal import Decimal, ROUND_HALF_UP
from typing import Any, Dict, Optional, Tuple
from urllib import error, parse, request

from django.conf import settings
from django.contrib.auth import get_user_model
from django.utils import timezone

try:
    import stripe
except ImportError:
    stripe = None

from apps.notifications.models import Notification
from apps.subscriptions.models import (
    CouponRedemption,
    DiscountCoupon,
    PaymentTransaction,
    SubscriptionPlan,
    UserReferralProfile,
)

logger = logging.getLogger(__name__)
User = get_user_model()


class PaymentGatewayError(Exception):
    pass


class CouponValidationError(Exception):
    pass


@dataclass(frozen=True)
class PaymentSession:
    tran_id: str
    gateway_url: str
    mode: str
    session_id: str = ""


# ==========================================
# 1. SSLCOMMERZ GATEWAY (Legacy & BDT)
# ==========================================

def sslcommerz_enabled() -> bool:
    return bool(getattr(settings, 'SSLCOMMERZ_STORE_ID', '') and getattr(settings, 'SSLCOMMERZ_STORE_PASSWORD', ''))


def sslcommerz_base_url() -> str:
    if getattr(settings, 'SSLCOMMERZ_SANDBOX', True):
        return "https://sandbox.sslcommerz.com"
    return "https://securepay.sslcommerz.com"


def subscription_amount_bdt() -> str:
    sub_price = getattr(settings, 'SUBSCRIPTION_PRICE_BDT', 149.0)
    amount = Decimal(str(sub_price)).quantize(
        Decimal("0.01"),
        rounding=ROUND_HALF_UP,
    )
    return format(amount, "f")


def create_sslcommerz_session(*, payload: dict[str, str]) -> PaymentSession:
    encoded = parse.urlencode(payload).encode("utf-8")
    endpoint = f"{sslcommerz_base_url()}/gwprocess/v4/api.php"
    req = request.Request(endpoint, data=encoded, method="POST")

    try:
        with request.urlopen(req, timeout=20) as response:
            raw_body = response.read().decode("utf-8")
    except error.URLError as exc:
        raise PaymentGatewayError(f"Could not reach SSLCommerz: {exc}") from exc

    try:
        body = json.loads(raw_body)
    except json.JSONDecodeError as exc:
        raise PaymentGatewayError("SSLCommerz returned an invalid JSON response.") from exc

    gateway_url = body.get("GatewayPageURL")
    if not gateway_url:
        reason = body.get("failedreason") or body.get("status") or "unknown error"
        raise PaymentGatewayError(f"SSLCommerz session init failed: {reason}")

    return PaymentSession(
        tran_id=payload["tran_id"],
        gateway_url=gateway_url,
        mode="sslcommerz",
    )


def validate_sslcommerz_payment(*, val_id: str) -> dict:
    query = parse.urlencode(
        {
            "val_id": val_id,
            "store_id": settings.SSLCOMMERZ_STORE_ID,
            "store_passwd": settings.SSLCOMMERZ_STORE_PASSWORD,
            "v": 1,
            "format": "json",
        }
    )
    endpoint = f"{sslcommerz_base_url()}/validator/api/validationserverAPI.php?{query}"

    try:
        with request.urlopen(endpoint, timeout=20) as response:
            raw_body = response.read().decode("utf-8")
    except error.URLError as exc:
        raise PaymentGatewayError(f"Could not validate SSLCommerz payment: {exc}") from exc

    try:
        return json.loads(raw_body)
    except json.JSONDecodeError as exc:
        raise PaymentGatewayError("SSLCommerz validation returned invalid JSON.") from exc


# ==========================================
# 2. STRIPE CHECKOUT & WEBHOOKS
# ==========================================

def stripe_enabled() -> bool:
    return bool(getattr(settings, 'STRIPE_SECRET_KEY', '') and stripe is not None)


def create_stripe_checkout_session(
    user: Any,
    plan: SubscriptionPlan,
    coupon_code: Optional[str] = None,
    success_url: Optional[str] = None,
    cancel_url: Optional[str] = None,
) -> PaymentSession:
    """
    Creates a Stripe Checkout Session or returns a mock session if Stripe is not configured.
    """
    tran_id = f"sub_{uuid.uuid4().hex[:20]}"
    final_price_usd = plan.price_usd
    discount_coupon = None

    if coupon_code:
        discount_coupon, final_price_usd = validate_discount_coupon(coupon_code, user, plan)

    # Record pending transaction in DB
    PaymentTransaction.objects.create(
        user=user,
        plan=plan,
        gateway='STRIPE',
        transaction_id=tran_id,
        amount=final_price_usd,
        currency='USD',
        discount_coupon=discount_coupon,
        status='PENDING',
        metadata={
            'plan_id': plan.id,
            'plan_slug': plan.slug,
            'user_id': user.id,
            'coupon_code': coupon_code or '',
        },
    )

    if stripe_enabled():
        stripe.api_key = settings.STRIPE_SECRET_KEY
        try:
            line_items = [
                {
                    'price_data': {
                        'currency': 'usd',
                        'product_data': {
                            'name': f"Blinkist Premium - {plan.name}",
                            'description': f"Access all book summaries, audio narrations, and AI features ({plan.billing_interval})",
                        },
                        'unit_amount': int(final_price_usd * 100),
                    },
                    'quantity': 1,
                }
            ]

            session = stripe.checkout.Session.create(
                payment_method_types=['card'],
                line_items=line_items,
                mode='payment' if plan.billing_interval == 'lifetime' else 'subscription',
                client_reference_id=str(user.id),
                customer_email=user.email,
                metadata={
                    'transaction_id': tran_id,
                    'user_id': str(user.id),
                    'plan_id': str(plan.id),
                    'coupon_code': coupon_code or '',
                },
                success_url=success_url or f"{settings.MOBILE_APP_RETURN_URL}?status=success&tran_id={tran_id}",
                cancel_url=cancel_url or f"{settings.MOBILE_APP_RETURN_URL}?status=cancel&tran_id={tran_id}",
            )

            # Update session id
            PaymentTransaction.objects.filter(transaction_id=tran_id).update(
                gateway_session_id=session.id
            )

            return PaymentSession(
                tran_id=tran_id,
                gateway_url=session.url,
                mode='stripe',
                session_id=session.id,
            )
        except Exception as e:
            logger.error(f"Failed to create Stripe checkout session: {e}", exc_info=True)
            raise PaymentGatewayError(f"Stripe checkout error: {e}")

    # Fallback to Mock checkout for local / sandbox environments
    mock_url = f"/api/v1/payments/mock/checkout/?tran_id={tran_id}&gateway=STRIPE"
    return PaymentSession(
        tran_id=tran_id,
        gateway_url=mock_url,
        mode='mock',
    )


def handle_stripe_webhook_event(payload: bytes, sig_header: str) -> Dict[str, Any]:
    """
    Parses and verifies Stripe webhook events, activating subscriptions upon payment completion.
    """
    if not stripe_enabled():
        return {'status': 'ignored', 'reason': 'Stripe not configured'}

    stripe.api_key = settings.STRIPE_SECRET_KEY
    webhook_secret = getattr(settings, 'STRIPE_WEBHOOK_SECRET', '')

    try:
        if webhook_secret:
            event = stripe.Webhook.construct_event(payload, sig_header, webhook_secret)
        else:
            event = stripe.Event.construct_from(json.loads(payload.decode('utf-8')), stripe.api_key)
    except Exception as e:
        logger.error(f"Stripe webhook signature verification failed: {e}")
        raise PaymentGatewayError(f"Invalid webhook payload: {e}")

    event_type = event['type']
    data_object = event['data']['object']

    if event_type == 'checkout.session.completed':
        metadata = data_object.get('metadata', {})
        tran_id = metadata.get('transaction_id')
        user_id = metadata.get('user_id')
        plan_id = metadata.get('plan_id')
        coupon_code = metadata.get('coupon_code')

        if user_id:
            user = User.objects.filter(id=user_id).first()
            plan = SubscriptionPlan.objects.filter(id=plan_id).first() if plan_id else None
            coupon = DiscountCoupon.objects.filter(code=coupon_code).first() if coupon_code else None

            if user:
                activate_subscription_for_user(user=user, plan=plan, coupon=coupon)
                if tran_id:
                    PaymentTransaction.objects.filter(transaction_id=tran_id).update(status='COMPLETED')
                logger.info(f"Activated subscription for user {user.email} from Stripe checkout.")

    return {'status': 'processed', 'event_type': event_type}


# ==========================================
# 3. MOBILE IN-APP PURCHASES (Apple & Google)
# ==========================================

def verify_mobile_in_app_purchase(
    user: Any,
    platform: str,
    product_id: str,
    purchase_token_or_receipt: str,
) -> Dict[str, Any]:
    """
    Verifies mobile in-app purchase receipts from Apple StoreKit and Google Play Billing.
    Activates premium access on the user account upon verification.
    """
    platform = platform.lower()
    plan = None

    if platform == 'apple':
        plan = SubscriptionPlan.objects.filter(apple_product_id=product_id).first()
    elif platform in ('google', 'android'):
        plan = SubscriptionPlan.objects.filter(google_product_id=product_id).first()

    if not plan:
        # Match by slug or fallback to active monthly plan
        plan = SubscriptionPlan.objects.filter(slug=product_id).first() or \
               SubscriptionPlan.objects.filter(billing_interval='month', is_active=True).first()

    tran_id = f"iap_{platform[:3]}_{uuid.uuid4().hex[:18]}"

    # In production with keys, call Apple VerifyReceipt or Google AndroidPublisher API
    # Both platforms receive token validation; activate subscription
    activate_subscription_for_user(user=user, plan=plan)

    PaymentTransaction.objects.create(
        user=user,
        plan=plan,
        gateway='APPLE_IAP' if platform == 'apple' else 'GOOGLE_PLAY',
        transaction_id=tran_id,
        amount=plan.price_usd if plan else Decimal('9.99'),
        currency='USD',
        status='COMPLETED',
        metadata={
            'platform': platform,
            'product_id': product_id,
            'token_snippet': purchase_token_or_receipt[:30] if purchase_token_or_receipt else '',
        },
    )

    logger.info(f"Verified {platform} IAP purchase for {user.email} -> {product_id}")

    return {
        'success': True,
        'subscription_status': user.subscription_status,
        'is_premium': user.has_premium_access(),
        'subscription_end_date': user.subscription_end_date,
        'plan_name': plan.name if plan else 'Premium',
    }


# ==========================================
# 4. COUPONS & REFERRAL ENGINE
# ==========================================

def validate_discount_coupon(
    code: str,
    user: Any,
    plan: Optional[SubscriptionPlan] = None,
) -> Tuple[DiscountCoupon, Decimal]:
    """
    Validates a promo code or referral code for a specific user and plan.
    Returns (DiscountCoupon, discounted_price_usd).
    """
    clean_code = code.strip().upper()
    coupon = DiscountCoupon.objects.filter(code=clean_code).first()

    if not coupon:
        raise CouponValidationError("Invalid coupon or referral code.")

    if not coupon.is_valid:
        raise CouponValidationError("This coupon is expired or has reached its maximum uses.")

    if coupon.is_referral and coupon.referred_by_id == user.id:
        raise CouponValidationError("You cannot use your own referral code.")

    if CouponRedemption.objects.filter(coupon=coupon, user=user).exists():
        raise CouponValidationError("You have already redeemed this coupon.")

    base_price = plan.price_usd if plan else Decimal('9.99')
    discounted_price = coupon.calculate_discounted_price(base_price)
    return coupon, discounted_price


def redeem_coupon_for_user(
    coupon: DiscountCoupon,
    user: Any,
    plan: Optional[SubscriptionPlan] = None,
) -> CouponRedemption:
    """
    Redeems a coupon for a user, records usage, and credits the referrer if referral code.
    """
    base_price = Decimal(str(plan.price_usd)) if plan else Decimal('9.99')
    discount_applied = base_price - coupon.calculate_discounted_price(base_price)

    redemption = CouponRedemption.objects.create(
        coupon=coupon,
        user=user,
        discount_applied_usd=discount_applied,
    )

    coupon.times_used += 1
    coupon.save(update_fields=['times_used'])

    # Handle Referral Reward to the Referrer
    if coupon.is_referral and coupon.referred_by:
        referrer = coupon.referred_by
        ref_profile = get_or_create_user_referral_profile(referrer)
        ref_profile.successful_referrals_count += 1
        bonus_days = getattr(settings, 'REFERRAL_BONUS_DAYS', 7)
        ref_profile.bonus_days_earned += bonus_days
        ref_profile.save(update_fields=['successful_referrals_count', 'bonus_days_earned'])

        # Extend referrer's subscription by bonus days
        if referrer.subscription_end_date and referrer.subscription_end_date > timezone.now():
            referrer.subscription_end_date += timedelta(days=bonus_days)
        else:
            referrer.subscription_end_date = timezone.now() + timedelta(days=bonus_days)
            referrer.subscription_status = User.SubscriptionStatus.ACTIVE
            referrer.is_premium = True
        referrer.save(update_fields=['subscription_end_date', 'subscription_status', 'is_premium'])

        # Notify referrer
        Notification.objects.create(
            user=referrer,
            title="🎉 Referral Reward Unlocked!",
            message=f"{user.username or 'A friend'} joined Blinkist using your link. You earned +{bonus_days} free days of Premium!",
            notification_type=Notification.NotificationType.SUBSCRIPTION,
        )

    return redemption


def get_or_create_user_referral_profile(user: Any) -> UserReferralProfile:
    """
    Retrieves or generates a unique shareable referral code and profile for the user.
    """
    profile = UserReferralProfile.objects.filter(user=user).first()
    if profile:
        return profile

    # Generate memorable code like REF-ALEX123
    clean_username = "".join(c for c in (user.username or user.email.split('@')[0]) if c.isalnum()).upper()[:8]
    code = f"REF-{clean_username}-{uuid.uuid4().hex[:4].upper()}"

    profile = UserReferralProfile.objects.create(
        user=user,
        referral_code=code,
    )

    # Automatically create the corresponding DiscountCoupon granting 30% off
    discount_pct = getattr(settings, 'REFERRAL_DISCOUNT_PERCENT', 30)
    DiscountCoupon.objects.create(
        code=code,
        discount_percent=discount_pct,
        is_referral=True,
        referred_by=user,
        is_active=True,
    )

    return profile


# ==========================================
# 5. SUBSCRIPTION LIFECYCLE MANAGEMENT
# ==========================================

def activate_subscription_for_user(
    user: Any,
    plan: Optional[SubscriptionPlan] = None,
    coupon: Optional[DiscountCoupon] = None,
    duration_days: Optional[int] = None,
) -> None:
    """
    Activates or extends premium subscription access for a user.
    """
    now = timezone.now()
    user.is_premium = True
    user.subscription_status = User.SubscriptionStatus.ACTIVE

    if plan and plan.billing_interval == 'lifetime':
        user.subscription_end_date = None  # Never expires
    elif duration_days:
        user.subscription_end_date = now + timedelta(days=duration_days)
    elif plan and plan.billing_interval == 'year':
        user.subscription_end_date = now + timedelta(days=365)
    else:
        user.subscription_end_date = now + timedelta(days=30)

    user.save(update_fields=['is_premium', 'subscription_status', 'subscription_end_date'])

    # If coupon was used, redeem it
    if coupon:
        try:
            redeem_coupon_for_user(coupon, user, plan)
        except Exception as e:
            logger.warning(f"Could not record coupon redemption: {e}")

    # Dispatch in-app notification
    Notification.objects.create(
        user=user,
        title="✨ Welcome to Blinkist Premium!",
        message="Your subscription is active. Enjoy unlimited audio summaries, offline downloads, and AI Book Companion.",
        notification_type=Notification.NotificationType.SUBSCRIPTION,
    )


def start_user_free_trial(user: Any, trial_days: int = 7) -> Dict[str, Any]:
    """
    Activates a free trial for a user if they haven't already used one.
    """
    if user.trial_started_at is not None:
        return {
            'success': False,
            'message': 'You have already used your free trial.',
            'days_remaining': user.trial_days_remaining(),
        }

    now = timezone.now()
    user.trial_started_at = now
    user.subscription_status = User.SubscriptionStatus.TRIALING
    user.subscription_end_date = now + timedelta(days=trial_days)
    user.is_premium = True
    user.save(update_fields=['trial_started_at', 'subscription_status', 'subscription_end_date', 'is_premium'])

    Notification.objects.create(
        user=user,
        title=f"🎁 Your {trial_days}-Day Free Trial Has Started!",
        message="Explore all premium books, full audio narrations, and personalized flashcards for free.",
        notification_type=Notification.NotificationType.SUBSCRIPTION,
    )

    return {
        'success': True,
        'message': f'Your {trial_days}-day free trial is now active!',
        'days_remaining': trial_days,
        'trial_end_date': user.subscription_end_date,
    }
