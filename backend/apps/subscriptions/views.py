import uuid
from datetime import timedelta

from django.contrib.auth import get_user_model
from django.http import HttpResponse
from django.urls import reverse
from django.utils import timezone
from rest_framework import permissions, status, views
from rest_framework.response import Response

User = get_user_model()


def _build_absolute(request, path: str) -> str:
    return request.build_absolute_uri(path)


class InitiatePaymentView(views.APIView):
    """
    Phase 2 scaffolding:
    - Generates a transaction id
    - Returns a gateway URL (mock checkout by default)

    Later: integrate SSLCommerz Session API and return the real gateway URL.
    """

    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        tran_id = uuid.uuid4().hex

        request.user.sslcommerz_tran_id = tran_id
        request.user.save(update_fields=["sslcommerz_tran_id"])

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


class MockCheckoutView(views.APIView):
    """
    Simple local mock of a payment gateway for development/testing without
    SSLCommerz credentials.
    """

    permission_classes = [permissions.AllowAny]

    def get(self, request):
        tran_id = request.query_params.get("tran_id", "")
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
    <title>Mock Checkout</title>
    <style>
      body {{ font-family: -apple-system, system-ui, sans-serif; padding: 24px; }}
      .btn {{ display: block; padding: 14px 16px; margin: 12px 0; border-radius: 10px; text-decoration: none; color: white; text-align: center; }}
      .success {{ background: #16a34a; }}
      .fail {{ background: #dc2626; }}
      .cancel {{ background: #6b7280; }}
      code {{ background: #f3f4f6; padding: 2px 6px; border-radius: 6px; }}
    </style>
  </head>
  <body>
    <h2>Mock Checkout</h2>
    <p>Transaction: <code>{tran_id}</code></p>
    <a class="btn success" href="{success_url}">Simulate Success</a>
    <a class="btn fail" href="{fail_url}">Simulate Fail</a>
    <a class="btn cancel" href="{cancel_url}">Simulate Cancel</a>
  </body>
</html>
"""
        return HttpResponse(html, content_type="text/html")


def _activate_subscription_for_user(user: User):
    user.subscription_status = User.SubscriptionStatus.ACTIVE
    user.subscription_end_date = timezone.now() + timedelta(days=30)
    user.sslcommerz_tran_id = None
    user.save(
        update_fields=[
            "subscription_status",
            "subscription_end_date",
            "sslcommerz_tran_id",
        ]
    )


class PaymentSuccessView(views.APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        tran_id = request.query_params.get("tran_id")
        if not tran_id:
            return Response(
                {"detail": "Missing tran_id"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user = User.objects.filter(sslcommerz_tran_id=tran_id).first()
        if not user:
            return Response(
                {"detail": "Unknown tran_id"},
                status=status.HTTP_404_NOT_FOUND,
            )

        _activate_subscription_for_user(user)
        return Response({"status": "success"})


class PaymentFailView(views.APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        tran_id = request.query_params.get("tran_id")
        if not tran_id:
            return Response(
                {"detail": "Missing tran_id"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user = User.objects.filter(sslcommerz_tran_id=tran_id).first()
        if user:
            user.subscription_status = User.SubscriptionStatus.EXPIRED
            user.sslcommerz_tran_id = None
            user.save(update_fields=["subscription_status", "sslcommerz_tran_id"])

        return Response({"status": "fail"})


class PaymentCancelView(views.APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        tran_id = request.query_params.get("tran_id")
        if not tran_id:
            return Response(
                {"detail": "Missing tran_id"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user = User.objects.filter(sslcommerz_tran_id=tran_id).first()
        if user:
            user.subscription_status = User.SubscriptionStatus.CANCELLED
            user.sslcommerz_tran_id = None
            user.save(update_fields=["subscription_status", "sslcommerz_tran_id"])

        return Response({"status": "cancel"})


class PaymentIPNView(views.APIView):
    """
    SSLCommerz will send server-to-server IPN callbacks.
    This is a stub endpoint for Phase 2; add secure validation before enabling.
    """

    permission_classes = [permissions.AllowAny]

    def post(self, request):
        return Response(
            {"detail": "IPN received (not yet validated)."},
            status=status.HTTP_200_OK,
        )

