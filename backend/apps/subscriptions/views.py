from __future__ import annotations

import decimal
import json
import logging
import uuid
from datetime import timedelta
from typing import Any, Dict
from urllib.parse import urlencode

from django.conf import settings
from django.contrib.auth import get_user_model
from django.http import HttpResponse
from django.shortcuts import get_object_or_404
from django.urls import reverse
from django.utils import timezone
from rest_framework import permissions, status, views
from rest_framework.response import Response

from apps.subscriptions.models import (
    DiscountCoupon,
    PaymentTransaction,
    SubscriptionPlan,
    UserReferralProfile,
)
from apps.subscriptions.serializers import (
    CouponValidateRequestSerializer,
    CouponValidateResponseSerializer,
    InAppPurchaseVerifySerializer,
    StripeCheckoutRequestSerializer,
    SubscriptionPlanSerializer,
    SubscriptionStatusResponseSerializer,
    UserReferralStatsSerializer,
)
from apps.subscriptions.services import (
    CouponValidationError,
    PaymentGatewayError,
    activate_subscription_for_user,
    create_sslcommerz_session,
    create_stripe_checkout_session,
    get_or_create_user_referral_profile,
    handle_stripe_webhook_event,
    sslcommerz_enabled,
    start_user_free_trial,
    subscription_amount_bdt,
    validate_discount_coupon,
    validate_sslcommerz_payment,
    verify_mobile_in_app_purchase,
)

logger = logging.getLogger(__name__)
User = get_user_model()


def _build_absolute(request, path: str) -> str:
    return request.build_absolute_uri(path)


def _request_data(request) -> dict:
    if request.method == "POST" and request.data:
        if hasattr(request.data, "dict"):
            return request.data.dict()
        return dict(request.data)
    return request.query_params


def _build_mobile_app_url(*, status_value: str, tran_id: str) -> str:
    query = urlencode(
        {
            "status": status_value,
            "tran_id": tran_id,
        }
    )
    return f"{settings.MOBILE_APP_RETURN_URL}?{query}"


def _render_app_handoff(*, title: str, body: str, tone: str, app_url: str) -> HttpResponse:
    color = {
        "success": "#0f9d58",
        "fail": "#dc2626",
        "cancel": "#6b7280",
    }.get(tone, "#0f766e")
    html = f"""
<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>{title}</title>
    <style>
      body {{ font-family: -apple-system, system-ui, sans-serif; background: #f7f9fa; color: #0f172a; margin: 0; }}
      .wrap {{ min-height: 100vh; display: grid; place-items: center; padding: 24px; }}
      .card {{ max-width: 440px; width: 100%; background: white; border-radius: 24px; padding: 28px; box-shadow: 0 16px 40px rgba(15, 23, 42, 0.08); }}
      .pill {{ display: inline-block; border-radius: 999px; background: rgba(0, 0, 0, 0.04); color: {color}; padding: 8px 12px; font-weight: 700; margin-bottom: 14px; }}
      h1 {{ margin: 0 0 8px; font-size: 28px; }}
      p {{ margin: 0 0 18px; line-height: 1.5; color: #475569; }}
      .btn {{ display: inline-block; padding: 14px 18px; border-radius: 14px; background: #00bfa5; color: white; text-decoration: none; font-weight: 700; }}
      .hint {{ margin-top: 14px; font-size: 14px; color: #64748b; }}
    </style>
  </head>
  <body>
    <div class="wrap">
      <div class="card">
        <div class="pill">{title}</div>
        <h1>{title}</h1>
        <p>{body}</p>
        <a class="btn" href="{app_url}">Return to app</a>
        <p class="hint">If the app does not open automatically, tap the button above.</p>
      </div>
    </div>
    <script>
      window.location.replace({app_url!r});
    </script>
  </body>
</html>
"""
    return HttpResponse(html, content_type="text/html")


def _render_checkout_result(*, title: str, body: str, tone: str) -> HttpResponse:
    return _render_app_handoff(
        title=title,
        body=body,
        tone=tone,
        app_url=settings.MOBILE_APP_RETURN_URL,
    )


def _ensure_default_plans_exist() -> None:
    if not SubscriptionPlan.objects.exists():
        SubscriptionPlan.objects.create(
            name="Monthly Premium",
            slug="monthly",
            billing_interval="month",
            price_usd=decimal.Decimal("9.99"),
            price_bdt=decimal.Decimal("999.00"),
            trial_days=0,
            badge_text="",
            is_featured=False,
            order=1,
            features=[
                "Unlimited audio & text book summaries",
                "Offline downloads & background listening",
                "In-Reader AI Book Companion (RAG)",
                "Active-Recall Spaced Repetition Flashcards",
                "Personalized Action Plan Habit Roadmaps",
            ],
            apple_product_id="com.blinkist.monthly",
            google_product_id="blinkist_monthly",
        )
        SubscriptionPlan.objects.create(
            name="Annual Premium (Save 50%)",
            slug="annual",
            billing_interval="year",
            price_usd=decimal.Decimal("59.99"),
            price_bdt=decimal.Decimal("5999.00"),
            trial_days=7,
            badge_text="MOST POPULAR",
            is_featured=True,
            order=2,
            features=[
                "Everything in Monthly",
                "7-Day Free Trial included",
                "Save 50% compared to monthly billing",
                "Full catalog offline caching",
                "Priority access to newly synthesized books",
            ],
            apple_product_id="com.blinkist.annual",
            google_product_id="blinkist_annual",
        )
        SubscriptionPlan.objects.create(
            name="Lifetime Mastery",
            slug="lifetime",
            billing_interval="lifetime",
            price_usd=decimal.Decimal("199.99"),
            price_bdt=decimal.Decimal("19999.00"),
            trial_days=0,
            badge_text="BEST VALUE",
            is_featured=False,
            order=3,
            features=[
                "One-time payment, permanent access",
                "All current & future audio summaries",
                "All upcoming generative AI features",
                "VIP early access to new creator tools",
            ],
            apple_product_id="com.blinkist.lifetime",
            google_product_id="blinkist_lifetime",
        )


# ==========================================
# 1. PLANS & STATUS APIS
# ==========================================

class SubscriptionPlanListView(views.APIView):
    """
    GET: Return all active subscription plans with pricing and features.
    """
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        _ensure_default_plans_exist()
        plans = SubscriptionPlan.objects.filter(is_active=True).order_by('order', 'price_usd')
        serializer = SubscriptionPlanSerializer(plans, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)


class SubscriptionStatusView(views.APIView):
    """
    GET: Return detailed subscription status for current user.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        last_tx = PaymentTransaction.objects.filter(user=user, status='COMPLETED').order_by('-created_at').first()
        active_plan_name = last_tx.plan.name if (last_tx and last_tx.plan) else None

        data = {
            'is_premium': user.has_premium_access(),
            'subscription_status': user.subscription_status,
            'subscription_end_date': user.subscription_end_date,
            'trial_started_at': user.trial_started_at,
            'trial_days_remaining': user.trial_days_remaining(),
            'can_start_trial': user.trial_started_at is None,
            'active_plan': active_plan_name,
        }
        return Response(data, status=status.HTTP_200_OK)


class StartFreeTrialView(views.APIView):
    """
    POST: Activate 7-day free trial for user.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        trial_days = getattr(settings, 'DEFAULT_TRIAL_DAYS', 7)
        result = start_user_free_trial(request.user, trial_days=trial_days)
        if not result['success']:
            return Response(result, status=status.HTTP_400_BAD_REQUEST)
        return Response(result, status=status.HTTP_200_OK)


# ==========================================
# 2. COUPON & REFERRAL APIS
# ==========================================

class ValidateCouponView(views.APIView):
    """
    POST: Validate a promo code or referral code and calculate discounts.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = CouponValidateRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        code = serializer.validated_data['code']
        plan_id = serializer.validated_data.get('plan_id')

        plan = None
        if plan_id:
            plan = SubscriptionPlan.objects.filter(id=plan_id).first()
        if not plan:
            plan = SubscriptionPlan.objects.filter(billing_interval='year', is_active=True).first() or \
                   SubscriptionPlan.objects.filter(is_active=True).first()

        try:
            coupon, discounted_price = validate_discount_coupon(code, request.user, plan)
            base_price = plan.price_usd if plan else decimal.Decimal('9.99')
            savings = base_price - discounted_price

            return Response(
                {
                    'code': coupon.code,
                    'discount_percent': coupon.discount_percent,
                    'original_price_usd': base_price,
                    'discounted_price_usd': discounted_price,
                    'savings_usd': savings,
                    'is_referral': coupon.is_referral,
                },
                status=status.HTTP_200_OK,
            )
        except CouponValidationError as e:
            return Response({'detail': str(e)}, status=status.HTTP_400_BAD_REQUEST)


class UserReferralView(views.APIView):
    """
    GET: Get current user's referral code, shareable link, and earnings.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        profile = get_or_create_user_referral_profile(request.user)
        serializer = UserReferralStatsSerializer(profile)
        return Response(serializer.data, status=status.HTTP_200_OK)


# ==========================================
# 3. STRIPE CHECKOUT & WEBHOOK
# ==========================================

class StripeCheckoutView(views.APIView):
    """
    POST: Create a Stripe checkout session for a subscription plan.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = StripeCheckoutRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        plan_id = serializer.validated_data['plan_id']
        coupon_code = serializer.validated_data.get('coupon_code')
        success_url = serializer.validated_data.get('success_url')
        cancel_url = serializer.validated_data.get('cancel_url')

        plan = get_object_or_404(SubscriptionPlan, id=plan_id, is_active=True)

        try:
            session = create_stripe_checkout_session(
                user=request.user,
                plan=plan,
                coupon_code=coupon_code,
                success_url=success_url,
                cancel_url=cancel_url,
            )
            return Response(
                {
                    'tran_id': session.tran_id,
                    'gateway_url': session.gateway_url,
                    'mode': session.mode,
                    'session_id': session.session_id,
                },
                status=status.HTTP_200_OK,
            )
        except (PaymentGatewayError, CouponValidationError) as e:
            return Response({'detail': str(e)}, status=status.HTTP_400_BAD_REQUEST)


class StripeWebhookView(views.APIView):
    """
    POST: Stripe webhook endpoint for asynchronous payment confirmations.
    """
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        payload = request.body
        sig_header = request.META.get('HTTP_STRIPE_SIGNATURE', '')

        try:
            result = handle_stripe_webhook_event(payload, sig_header)
            return Response(result, status=status.HTTP_200_OK)
        except PaymentGatewayError as e:
            return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)


# ==========================================
# 4. MOBILE IN-APP PURCHASES (Apple & Google)
# ==========================================

class InAppPurchaseVerifyView(views.APIView):
    """
    POST: Verify Apple StoreKit or Google Play In-App Purchase receipt/token.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = InAppPurchaseVerifySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        platform = serializer.validated_data['platform']
        product_id = serializer.validated_data['product_id']
        purchase_token = serializer.validated_data['purchase_token']

        result = verify_mobile_in_app_purchase(
            user=request.user,
            platform=platform,
            product_id=product_id,
            purchase_token_or_receipt=purchase_token,
        )
        return Response(result, status=status.HTTP_200_OK)


# ==========================================
# 5. LEGACY & MOCK CHECKOUT VIEWS
# ==========================================

class InitiatePaymentView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        tran_id = uuid.uuid4().hex[:30]
        request.user.sslcommerz_tran_id = tran_id
        request.user.save(update_fields=["sslcommerz_tran_id"])

        if not sslcommerz_enabled():
            mock_url = _build_absolute(
                request,
                f"{reverse('payments_mock')}?tran_id={tran_id}",
            )
            return Response(
                {
                    "tran_id": tran_id,
                    "gateway_url": mock_url,
                    "mode": "mock",
                }
            )

        payload = {
            "store_id": settings.SSLCOMMERZ_STORE_ID,
            "store_passwd": settings.SSLCOMMERZ_STORE_PASSWORD,
            "total_amount": subscription_amount_bdt(),
            "currency": "BDT",
            "tran_id": tran_id,
            "success_url": _build_absolute(request, reverse("payments_success")),
            "fail_url": _build_absolute(request, reverse("payments_fail")),
            "cancel_url": _build_absolute(request, reverse("payments_cancel")),
            "ipn_url": _build_absolute(request, reverse("payments_ipn")),
            "shipping_method": "NO",
            "product_name": "Blinkist Premium Subscription",
            "product_category": "Subscription",
            "product_profile": "general",
            "cus_name": request.user.get_full_name() or request.user.username or request.user.email,
            "cus_email": request.user.email,
            "cus_add1": "N/A",
            "cus_city": "Dhaka",
            "cus_country": "Bangladesh",
            "cus_phone": getattr(request.user, "phone", "") or "01700000000",
            "num_of_item": "1",
            "value_a": str(request.user.pk),
        }

        try:
            session = create_sslcommerz_session(payload=payload)
        except PaymentGatewayError as exc:
            return Response(
                {"detail": str(exc)},
                status=status.HTTP_502_BAD_GATEWAY,
            )

        return Response(
            {
                "tran_id": session.tran_id,
                "gateway_url": session.gateway_url,
                "mode": session.mode,
            }
        )


class MockCheckoutView(views.APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        tran_id = request.query_params.get("tran_id", "")
        gateway = request.query_params.get("gateway", "MOCK")
        success_url = _build_absolute(
            request,
            f"{reverse('payments_success')}?tran_id={tran_id}",
        )
        fail_url = _build_absolute(
            request,
            f"{reverse('payments_fail')}?tran_id={tran_id}",
        )
        cancel_url = _build_absolute(
            request,
            f"{reverse('payments_cancel')}?tran_id={tran_id}",
        )

        html = f"""
<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Mock Checkout ({gateway})</title>
    <style>
      body {{ font-family: -apple-system, system-ui, sans-serif; background: #0f172a; color: #f8fafc; padding: 32px; display: grid; place-items: center; min-height: 90vh; }}
      .card {{ background: #1e293b; border-radius: 16px; padding: 28px; max-width: 420px; width: 100%; box-shadow: 0 10px 25px rgba(0,0,0,0.3); border: 1px solid #334155; }}
      h2 {{ margin-top: 0; color: #38bdf8; }}
      .btn {{ display: block; padding: 14px 16px; margin: 12px 0; border-radius: 10px; text-decoration: none; color: white; text-align: center; font-weight: 600; }}
      .success {{ background: #10b981; }}
      .fail {{ background: #ef4444; }}
      .cancel {{ background: #64748b; }}
      code {{ background: #0f172a; padding: 4px 8px; border-radius: 6px; font-family: monospace; color: #facc15; }}
    </style>
  </head>
  <body>
    <div class="card">
      <h2>Blinkist Pay Simulation</h2>
      <p>Gateway: <strong>{gateway}</strong></p>
      <p>Transaction ID: <code>{tran_id}</code></p>
      <a class="btn success" href="{success_url}">Simulate Successful Payment</a>
      <a class="btn fail" href="{fail_url}">Simulate Failed Payment</a>
      <a class="btn cancel" href="{cancel_url}">Simulate Cancel</a>
    </div>
  </body>
</html>
"""
        return HttpResponse(html)


class PaymentSuccessView(views.APIView):
    permission_classes = [permissions.AllowAny]

    def _resolve_response(self, request):
        data = _request_data(request)
        tran_id = data.get("tran_id") or data.get("tran_id_") or request.query_params.get("tran_id", "")
        val_id = data.get("val_id")

        user = None
        tx = PaymentTransaction.objects.filter(transaction_id=tran_id).first()
        if tx:
            user = tx.user
            tx.status = 'COMPLETED'
            tx.save(update_fields=['status'])
            activate_subscription_for_user(user, plan=tx.plan, coupon=tx.discount_coupon)
        else:
            if val_id and sslcommerz_enabled():
                try:
                    validation = validate_sslcommerz_payment(val_id=val_id)
                except PaymentGatewayError as exc:
                    return Response({"detail": str(exc)}, status=status.HTTP_502_BAD_GATEWAY)
                validation_status = (validation.get("status") or "").upper()
                if validation_status not in {"VALID", "VALIDATED"}:
                    return Response({"detail": "Payment validation failed."}, status=status.HTTP_400_BAD_REQUEST)

            user = User.objects.filter(sslcommerz_tran_id=tran_id).first()
            if user:
                activate_subscription_for_user(user)
                user.sslcommerz_tran_id = None
                user.save(update_fields=['sslcommerz_tran_id'])

        if not user:
            return Response({"detail": "User not found for payment confirmation."}, status=status.HTTP_404_NOT_FOUND)

        app_url = _build_mobile_app_url(status_value="success", tran_id=tran_id)
        if request.headers.get("Accept") != "application/json" and request.content_type != "application/json":
            return _render_app_handoff(
                title="Payment successful",
                body="Your premium subscription is now active. Return to the app and refresh the account screen.",
                tone="success",
                app_url=app_url,
            )

        return Response(
            {
                "status": "success",
                "subscription_status": user.subscription_status,
                "subscription_end_date": user.subscription_end_date,
            },
            status=status.HTTP_200_OK,
        )

    def get(self, request):
        return self._resolve_response(request)

    def post(self, request):
        return self._resolve_response(request)


class PaymentFailView(views.APIView):
    permission_classes = [permissions.AllowAny]

    def _resolve_response(self, request):
        data = _request_data(request)
        tran_id = data.get("tran_id") or request.query_params.get("tran_id", "")
        tx = PaymentTransaction.objects.filter(transaction_id=tran_id).first()
        if tx:
            tx.status = 'FAILED'
            tx.save(update_fields=['status'])

        app_url = _build_mobile_app_url(status_value="fail", tran_id=tran_id)
        return _render_app_handoff(
            title="Payment failed",
            body="No charge was completed. You can resume checkout whenever you are ready.",
            tone="fail",
            app_url=app_url,
        )

    def get(self, request):
        return self._resolve_response(request)

    def post(self, request):
        return self._resolve_response(request)


class PaymentCancelView(views.APIView):
    permission_classes = [permissions.AllowAny]

    def _resolve_response(self, request):
        data = _request_data(request)
        tran_id = data.get("tran_id") or request.query_params.get("tran_id", "")
        tx = PaymentTransaction.objects.filter(transaction_id=tran_id).first()
        if tx:
            tx.status = 'FAILED'
            tx.save(update_fields=['status'])

        app_url = _build_mobile_app_url(status_value="cancel", tran_id=tran_id)
        return _render_app_handoff(
            title="Payment cancelled",
            body="You have cancelled the checkout process. No charge was made.",
            tone="cancel",
            app_url=app_url,
        )

    def get(self, request):
        return self._resolve_response(request)

    def post(self, request):
        return self._resolve_response(request)


class CancelSubscriptionView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        user = request.user
        cancellable = {
            User.SubscriptionStatus.ACTIVE,
            User.SubscriptionStatus.TRIALING,
        }
        if user.subscription_status not in cancellable:
            return Response(
                {"detail": "No active subscription to cancel."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        cancel_at_period_end = getattr(settings, "CANCEL_AT_PERIOD_END", True)
        cancellation_reason = request.data.get("reason", "").strip()
        user.subscription_status = User.SubscriptionStatus.CANCELLED
        if cancel_at_period_end and user.subscription_end_date is not None:
            effective_end_date = user.subscription_end_date
        else:
            effective_end_date = timezone.now()
            user.subscription_end_date = effective_end_date
            user.is_premium = False

        user.save(update_fields=["subscription_status", "subscription_end_date", "is_premium"])
        return Response(
            {
                "detail": "Subscription cancelled.",
                "subscription_status": user.subscription_status,
                "subscription_end_date": effective_end_date,
                "cancel_at_period_end": cancel_at_period_end,
                "reason": cancellation_reason,
            },
            status=status.HTTP_200_OK,
        )


class PaymentIPNView(views.APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        data = _request_data(request)
        val_id = data.get("val_id")
        tran_id = data.get("tran_id")

        if not sslcommerz_enabled():
            return Response({"detail": "Mock mode does not process IPN."}, status=status.HTTP_200_OK)

        if not val_id or not tran_id:
            return Response({"detail": "Missing val_id or tran_id"}, status=status.HTTP_400_BAD_REQUEST)

        user = User.objects.filter(sslcommerz_tran_id=tran_id).first()
        if not user:
            return Response({"detail": "Unknown tran_id"}, status=status.HTTP_404_NOT_FOUND)

        try:
            validation = validate_sslcommerz_payment(val_id=val_id)
        except PaymentGatewayError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_502_BAD_GATEWAY)

        validation_tran_id = validation.get("tran_id")
        validation_status = (validation.get("status") or "").upper()
        if validation_tran_id != tran_id or validation_status not in {"VALID", "VALIDATED"}:
            return Response({"detail": "Payment validation failed."}, status=status.HTTP_400_BAD_REQUEST)

        activate_subscription_for_user(user)
        return Response({"status": "success"}, status=status.HTTP_200_OK)
