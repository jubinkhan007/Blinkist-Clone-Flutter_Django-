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

    def test_list_subscription_plans(self):
        response = self.client.get(reverse("subscription_plans"))
        self.assertEqual(response.status_code, 200)
        self.assertGreaterEqual(len(response.data), 3)
        slugs = [p["slug"] for p in response.data]
        self.assertIn("monthly", slugs)
        self.assertIn("annual", slugs)
        self.assertIn("lifetime", slugs)

    def test_start_free_trial(self):
        self.user.trial_started_at = None
        self.user.subscription_status = User.SubscriptionStatus.EXPIRED
        self.user.is_premium = False
        self.user.save()

        # 1. Start trial
        response = self.client.post(reverse("subscription_trial_start"))
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.data["success"])
        self.assertEqual(response.data["days_remaining"], 7)

        self.user.refresh_from_db()
        self.assertEqual(self.user.subscription_status, User.SubscriptionStatus.TRIALING)
        self.assertTrue(self.user.is_premium)
        self.assertTrue(self.user.has_premium_access())

        # 2. Cannot start trial again once used
        dup_res = self.client.post(reverse("subscription_trial_start"))
        self.assertEqual(dup_res.status_code, 400)
        self.assertFalse(dup_res.data["success"])

    def test_coupon_validation_and_discount_calculation(self):
        from apps.subscriptions.models import DiscountCoupon, SubscriptionPlan
        plan = SubscriptionPlan.objects.create(
            name="Test Annual Plan",
            slug="test-annual",
            billing_interval="year",
            price_usd=100.00,
        )
        coupon = DiscountCoupon.objects.create(
            code="SUMMER30",
            discount_percent=30,
            is_active=True,
        )

        response = self.client.post(
            reverse("coupon_validate"),
            {"code": "summer30", "plan_id": plan.id},
            format="json",
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["code"], "SUMMER30")
        self.assertEqual(response.data["discount_percent"], 30)
        self.assertEqual(float(response.data["discounted_price_usd"]), 70.00)
        self.assertEqual(float(response.data["savings_usd"]), 30.00)

        # Invalid coupon test
        invalid_res = self.client.post(
            reverse("coupon_validate"),
            {"code": "FAKECODE123", "plan_id": plan.id},
            format="json",
        )
        self.assertEqual(invalid_res.status_code, 400)

    def test_user_referral_system_and_bonus_days(self):
        from apps.subscriptions.services import activate_subscription_for_user
        from apps.subscriptions.models import DiscountCoupon, SubscriptionPlan

        # 1. Fetch referral link for User 1 (Referrer)
        ref_res = self.client.get(reverse("user_referral"))
        self.assertEqual(ref_res.status_code, 200)
        ref_code = ref_res.data["referral_code"]
        self.assertTrue(ref_code.startswith("REF-"))

        # User 1 has active subscription expiring in 10 days
        self.user.subscription_status = User.SubscriptionStatus.ACTIVE
        self.user.is_premium = True
        initial_end = timezone.now() + timezone.timedelta(days=10)
        self.user.subscription_end_date = initial_end
        self.user.save()

        # 2. User 2 (Friend) registers and redeems User 1's referral code
        friend = User.objects.create_user(
            email="friend@example.com",
            username="friend",
            password="friendpassword",
        )
        plan = SubscriptionPlan.objects.create(
            name="Friend Monthly",
            slug="friend-monthly",
            billing_interval="month",
            price_usd=10.00,
        )
        coupon = DiscountCoupon.objects.get(code=ref_code)

        # Activate friend's subscription with referral coupon
        activate_subscription_for_user(friend, plan=plan, coupon=coupon)

        friend.refresh_from_db()
        self.assertTrue(friend.is_premium)

        # Verify Referrer (User 1) received +7 bonus days!
        self.user.refresh_from_db()
        self.assertGreater(
            self.user.subscription_end_date,
            initial_end + timezone.timedelta(days=6),
        )

    def test_stripe_checkout_endpoint(self):
        from apps.subscriptions.models import SubscriptionPlan
        plan = SubscriptionPlan.objects.create(
            name="Monthly Staged",
            slug="monthly-staged",
            billing_interval="month",
            price_usd=9.99,
        )

        response = self.client.post(
            reverse("stripe_checkout"),
            {"plan_id": plan.id},
            format="json",
        )
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.data["tran_id"].startswith("sub_"))
        self.assertTrue("gateway_url" in response.data)

    def test_in_app_purchase_verification(self):
        response = self.client.post(
            reverse("iap_verify"),
            {
                "platform": "apple",
                "product_id": "com.blinkist.annual",
                "purchase_token": "mock_app_store_receipt_token_xyz",
            },
            format="json",
        )
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.data["success"])
        self.assertTrue(response.data["is_premium"])

        self.user.refresh_from_db()
        self.assertTrue(self.user.has_premium_access())
        self.assertEqual(self.user.subscription_status, User.SubscriptionStatus.ACTIVE)

    def test_admin_promo_code_generation(self):
        from django.contrib.admin.sites import AdminSite
        from apps.subscriptions.admin import DiscountCouponAdmin
        from apps.subscriptions.models import DiscountCoupon
        from unittest.mock import MagicMock

        admin_instance = DiscountCouponAdmin(DiscountCoupon, AdminSite())
        mock_request = MagicMock()
        mock_request.user = self.user

        count_before = DiscountCoupon.objects.count()
        admin_instance.generate_promo_codes_action(mock_request, DiscountCoupon.objects.none())
        count_after = DiscountCoupon.objects.count()

        self.assertEqual(count_after, count_before + 5)

