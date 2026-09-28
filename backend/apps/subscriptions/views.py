import uuid
from datetime import timedelta
from urllib.parse import urlencode

from django.conf import settings
from django.contrib.auth import get_user_model
from django.http import HttpResponse
from django.urls import reverse
from django.utils import timezone
from rest_framework import permissions, status, views
from rest_framework.response import Response

from .services import (
    PaymentGatewayError,
    create_sslcommerz_session,
    sslcommerz_enabled,
    subscription_amount_bdt,
    validate_sslcommerz_payment,
)

User = get_user_model()


def _build_absolute(request, path: str) -> str:
    return request.build_absolute_uri(path)


def _request_data(request) -> dict:
    if request.method == "POST" and request.data:
        if hasattr(request.data, "dict"):
            return request.data.dict()
        return dict(request.data)
    return request.query_params


def _render_checkout_result(*, title: str, body: str, tone: str) -> HttpResponse:
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
      .card {{ max-width: 420px; width: 100%; background: white; border-radius: 24px; padding: 28px; box-shadow: 0 16px 40px rgba(15, 23, 42, 0.08); }}
      .pill {{ display: inline-block; border-radius: 999px; background: rgba(0, 0, 0, 0.04); color: {color}; padding: 8px 12px; font-weight: 700; margin-bottom: 14px; }}
      h1 {{ margin: 0 0 8px; font-size: 28px; }}
      p {{ margin: 0; line-height: 1.5; color: #475569; }}
    </style>
  </head>
  <body>
    <div class="wrap">
      <div class="card">
        <div class="pill">{title}</div>
        <h1>{title}</h1>
        <p>{body}</p>
      </div>
    </div>
  </body>
</html>
"""
    return HttpResponse(html, content_type="text/html")


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


def _build_mobile_app_url(*, status_value: str, tran_id: str) -> str:
    query = urlencode(
        {
            "status": status_value,
            "tran_id": tran_id,
        }
    )
    return f"{settings.MOBILE_APP_RETURN_URL}?{query}"


def _activate_subscription_for_user(user: User):
    user.subscription_status = User.SubscriptionStatus.ACTIVE
    user.subscription_end_date = timezone.now() + timedelta(days=30)
    user.is_premium = True
    user.sslcommerz_tran_id = None
    user.save(
        update_fields=[
            "is_premium",
            "subscription_status",
            "subscription_end_date",
            "sslcommerz_tran_id",
        ]
    )


def _clear_pending_transaction(user: User, *, next_status: str):
    user.subscription_status = next_status
    user.sslcommerz_tran_id = None
    user.save(update_fields=["subscription_status", "sslcommerz_tran_id"])


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


class PaymentSuccessView(views.APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        return self._complete(request)

    def post(self, request):
        return self._complete(request)

    def _complete(self, request):
        data = _request_data(request)
        tran_id = data.get("tran_id")
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

        if not sslcommerz_enabled():
            _activate_subscription_for_user(user)
            return _render_app_handoff(
                title="Payment successful",
                body="Your premium subscription is now active. Return to the app and refresh the account screen.",
                tone="success",
                app_url=_build_mobile_app_url(
                    status_value="success",
                    tran_id=tran_id,
                ),
            )

        val_id = data.get("val_id")
        if not val_id:
            return Response(
                {"detail": "Missing val_id"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            validation = validate_sslcommerz_payment(val_id=val_id)
        except PaymentGatewayError as exc:
            return Response(
                {"detail": str(exc)},
                status=status.HTTP_502_BAD_GATEWAY,
            )

        validation_tran_id = validation.get("tran_id")
        validation_status = (validation.get("status") or "").upper()
        if validation_tran_id != tran_id or validation_status not in {"VALID", "VALIDATED"}:
            return Response(
                {"detail": "Payment validation failed."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        _activate_subscription_for_user(user)
        return _render_app_handoff(
            title="Payment successful",
            body="Your premium subscription is now active. Return to the app and refresh the account screen.",
            tone="success",
            app_url=_build_mobile_app_url(
                status_value="success",
                tran_id=tran_id,
            ),
        )


class PaymentFailView(views.APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        data = _request_data(request)
        tran_id = data.get("tran_id")
        if not tran_id:
            return Response(
                {"detail": "Missing tran_id"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user = User.objects.filter(sslcommerz_tran_id=tran_id).first()
        if user:
            _clear_pending_transaction(
                user,
                next_status=User.SubscriptionStatus.EXPIRED,
            )

        return _render_app_handoff(
            title="Payment failed",
            body="The payment did not complete. You can try subscribing again from the app.",
            tone="fail",
            app_url=_build_mobile_app_url(
                status_value="failed",
                tran_id=tran_id,
            ),
        )


class PaymentCancelView(views.APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        data = _request_data(request)
        tran_id = data.get("tran_id")
        if not tran_id:
            return Response(
                {"detail": "Missing tran_id"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user = User.objects.filter(sslcommerz_tran_id=tran_id).first()
        if user:
            _clear_pending_transaction(
                user,
                next_status=User.SubscriptionStatus.CANCELLED,
            )

        return _render_app_handoff(
            title="Payment cancelled",
            body="No charge was completed. You can resume checkout any time from the app.",
            tone="cancel",
            app_url=_build_mobile_app_url(
                status_value="cancelled",
                tran_id=tran_id,
            ),
        )


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
            return Response(
                {"detail": "Mock mode does not process IPN."},
                status=status.HTTP_200_OK,
            )

        if not val_id or not tran_id:
            return Response(
                {"detail": "Missing val_id or tran_id"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user = User.objects.filter(sslcommerz_tran_id=tran_id).first()
        if not user:
            return Response(
                {"detail": "Unknown tran_id"},
                status=status.HTTP_404_NOT_FOUND,
            )

        try:
            validation = validate_sslcommerz_payment(val_id=val_id)
        except PaymentGatewayError as exc:
            return Response(
                {"detail": str(exc)},
                status=status.HTTP_502_BAD_GATEWAY,
            )

        validation_tran_id = validation.get("tran_id")
        validation_status = (validation.get("status") or "").upper()
        if validation_tran_id != tran_id or validation_status not in {"VALID", "VALIDATED"}:
            return Response(
                {"detail": "Payment validation failed."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        _activate_subscription_for_user(user)
        return Response({"status": "success"}, status=status.HTTP_200_OK)
