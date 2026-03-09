from django.urls import path

from .views import (
    InitiatePaymentView,
    PaymentCancelView,
    PaymentFailView,
    PaymentIPNView,
    PaymentSuccessView,
    MockCheckoutView,
)

urlpatterns = [
    path("initiate/", InitiatePaymentView.as_view(), name="payments_initiate"),
    path("success/", PaymentSuccessView.as_view(), name="payments_success"),
    path("fail/", PaymentFailView.as_view(), name="payments_fail"),
    path("cancel/", PaymentCancelView.as_view(), name="payments_cancel"),
    path("ipn/", PaymentIPNView.as_view(), name="payments_ipn"),
    path("mock/checkout/", MockCheckoutView.as_view(), name="payments_mock"),
]

