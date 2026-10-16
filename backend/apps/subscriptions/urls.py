from django.urls import path

from .views import (
    CancelSubscriptionView,
    InAppPurchaseVerifyView,
    InitiatePaymentView,
    MockCheckoutView,
    PaymentCancelView,
    PaymentFailView,
    PaymentIPNView,
    PaymentSuccessView,
    StartFreeTrialView,
    StripeCheckoutView,
    StripeWebhookView,
    SubscriptionPlanListView,
    SubscriptionStatusView,
    UserReferralView,
    ValidateCouponView,
)

urlpatterns = [
    # Plans, Status & Trials
    path("plans/", SubscriptionPlanListView.as_view(), name="subscription_plans"),
    path("status/", SubscriptionStatusView.as_view(), name="subscription_status"),
    path("trial/start/", StartFreeTrialView.as_view(), name="subscription_trial_start"),
    path("subscription/cancel/", CancelSubscriptionView.as_view(), name="subscription_cancel"),

    # Promo Coupons & Referrals
    path("coupons/validate/", ValidateCouponView.as_view(), name="coupon_validate"),
    path("referral/", UserReferralView.as_view(), name="user_referral"),

    # Stripe Payments
    path("stripe/checkout/", StripeCheckoutView.as_view(), name="stripe_checkout"),
    path("stripe/webhook/", StripeWebhookView.as_view(), name="stripe_webhook"),

    # In-App Purchases (Apple StoreKit & Google Play Billing)
    path("iap/verify/", InAppPurchaseVerifyView.as_view(), name="iap_verify"),

    # Legacy & Mock Gateways
    path("initiate/", InitiatePaymentView.as_view(), name="payments_initiate"),
    path("success/", PaymentSuccessView.as_view(), name="payments_success"),
    path("fail/", PaymentFailView.as_view(), name="payments_fail"),
    path("cancel/", PaymentCancelView.as_view(), name="payments_cancel"),
    path("ipn/", PaymentIPNView.as_view(), name="payments_ipn"),
    path("mock/checkout/", MockCheckoutView.as_view(), name="payments_mock"),
]
