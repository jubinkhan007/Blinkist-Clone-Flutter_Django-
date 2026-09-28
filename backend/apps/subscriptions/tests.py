from unittest.mock import patch
from django.utils import timezone

from django.contrib.auth import get_user_model
from django.test import TestCase, override_settings
from django.urls import reverse
from rest_framework.test import APIClient

User = get_user_model()


class SubscriptionPaymentsTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(
            email="reader@example.com",
            username="reader",
            password="secret123",
        )
        self.client.force_authenticate(self.user)

    @override_settings(
        SSLCOMMERZ_STORE_ID="",
        SSLCOMMERZ_STORE_PASSWORD="",
    )
    def test_initiate_payment_returns_mock_checkout_when_sslcommerz_not_configured(self):
        response = self.client.post(reverse("payments_initiate"))

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["mode"], "mock")
        self.assertIn("/api/v1/payments/mock/checkout/", response.data["gateway_url"])

        self.user.refresh_from_db()
        self.assertTrue(self.user.sslcommerz_tran_id)

    @override_settings(
        SSLCOMMERZ_STORE_ID="test_store",
        SSLCOMMERZ_STORE_PASSWORD="test_password",
        SSLCOMMERZ_SANDBOX=True,
    )
    @patch("apps.subscriptions.views.create_sslcommerz_session")
    def test_initiate_payment_uses_sslcommerz_when_configured(
        self,
        mock_create_session,
    ):
        mock_create_session.return_value = type(
            "Session",
            (),
            {
                "tran_id": "tran123",
                "gateway_url": "https://sandbox.sslcommerz.com/example",
                "mode": "sslcommerz",
            },
        )()

        response = self.client.post(reverse("payments_initiate"))

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["mode"], "sslcommerz")
        self.assertEqual(
            response.data["gateway_url"],
            "https://sandbox.sslcommerz.com/example",
        )

    @override_settings(
        SSLCOMMERZ_STORE_ID="test_store",
        SSLCOMMERZ_STORE_PASSWORD="test_password",
        SSLCOMMERZ_SANDBOX=True,
    )
    @patch("apps.subscriptions.views.validate_sslcommerz_payment")
    def test_success_callback_activates_subscription_after_validation(
        self,
        mock_validate,
    ):
        self.user.sslcommerz_tran_id = "tran123"
        self.user.save(update_fields=["sslcommerz_tran_id"])
        mock_validate.return_value = {
            "status": "VALID",
            "tran_id": "tran123",
        }

        response = self.client.post(
            reverse("payments_success"),
            {"tran_id": "tran123", "val_id": "val456"},
        )

        self.assertEqual(response.status_code, 200)
        self.assertContains(
            response,
            "blinkist:/payment-return?status=success&tran_id=tran123",
        )
        self.user.refresh_from_db()
        self.assertEqual(
            self.user.subscription_status,
            User.SubscriptionStatus.ACTIVE,
        )
        self.assertIsNone(self.user.sslcommerz_tran_id)

    @override_settings(CANCEL_AT_PERIOD_END=True)
    def test_cancel_subscription_marks_cancelled_at_period_end(self):
        self.user.subscription_status = User.SubscriptionStatus.ACTIVE
        self.user.is_premium = True
        self.user.subscription_end_date = timezone.now()
        self.user.save(update_fields=["subscription_status", "is_premium", "subscription_end_date"])

        response = self.client.post(
            reverse("subscription_cancel"),
            {"reason": "done reading"},
            format="json",
        )

        self.assertEqual(response.status_code, 200)
        self.user.refresh_from_db()
        self.assertEqual(self.user.subscription_status, User.SubscriptionStatus.CANCELLED)
        self.assertTrue(response.data["cancel_at_period_end"])

    @override_settings(CANCEL_AT_PERIOD_END=False)
    def test_cancel_subscription_can_end_immediately(self):
        self.user.subscription_status = User.SubscriptionStatus.ACTIVE
        self.user.is_premium = True
        self.user.subscription_end_date = timezone.now() + timezone.timedelta(days=30)
        self.user.save(update_fields=["subscription_status", "is_premium", "subscription_end_date"])

        response = self.client.post(reverse("subscription_cancel"))

        self.assertEqual(response.status_code, 200)
        self.user.refresh_from_db()
        self.assertFalse(self.user.is_premium)
