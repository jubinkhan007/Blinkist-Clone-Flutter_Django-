from __future__ import annotations

import decimal
from typing import Any, Dict
from rest_framework import serializers

from apps.accounts.models import User
from apps.subscriptions.models import (
    DiscountCoupon,
    PaymentTransaction,
    SubscriptionPlan,
    UserReferralProfile,
)


class SubscriptionPlanSerializer(serializers.ModelSerializer):
    class Meta:
        model = SubscriptionPlan
        fields = (
            'id',
            'name',
            'slug',
            'billing_interval',
            'price_usd',
            'price_bdt',
            'trial_days',
            'features',
            'badge_text',
            'is_featured',
            'apple_product_id',
            'google_product_id',
        )


class CouponValidateRequestSerializer(serializers.Serializer):
    code = serializers.CharField(max_length=32)
    plan_id = serializers.IntegerField(required=False, allow_null=True)


class CouponValidateResponseSerializer(serializers.Serializer):
    code = serializers.CharField()
    discount_percent = serializers.IntegerField()
    original_price_usd = serializers.DecimalField(max_digits=6, decimal_places=2)
    discounted_price_usd = serializers.DecimalField(max_digits=6, decimal_places=2)
    savings_usd = serializers.DecimalField(max_digits=6, decimal_places=2)
    is_referral = serializers.BooleanField()


class StripeCheckoutRequestSerializer(serializers.Serializer):
    plan_id = serializers.IntegerField()
    coupon_code = serializers.CharField(required=False, allow_blank=True, default='')
    success_url = serializers.CharField(required=False, allow_blank=True, default='')
    cancel_url = serializers.CharField(required=False, allow_blank=True, default='')


class InAppPurchaseVerifySerializer(serializers.Serializer):
    platform = serializers.ChoiceField(choices=['apple', 'google', 'android'])
    product_id = serializers.CharField(max_length=120)
    purchase_token = serializers.CharField()


class UserReferralStatsSerializer(serializers.ModelSerializer):
    shareable_link = serializers.SerializerMethodField()
    discount_percent = serializers.SerializerMethodField()

    class Meta:
        model = UserReferralProfile
        fields = (
            'referral_code',
            'shareable_link',
            'successful_referrals_count',
            'bonus_days_earned',
            'discount_percent',
        )

    def get_shareable_link(self, obj: UserReferralProfile) -> str:
        return f"https://blinkist.app/join?ref={obj.referral_code}"

    def get_discount_percent(self, obj: UserReferralProfile) -> int:
        coupon = DiscountCoupon.objects.filter(code=obj.referral_code).first()
        return coupon.discount_percent if coupon else 30


class SubscriptionStatusResponseSerializer(serializers.Serializer):
    is_premium = serializers.BooleanField()
    subscription_status = serializers.CharField()
    subscription_end_date = serializers.DateTimeField(allow_null=True)
    trial_started_at = serializers.DateTimeField(allow_null=True)
    trial_days_remaining = serializers.IntegerField()
    can_start_trial = serializers.BooleanField()
    active_plan = serializers.CharField(allow_null=True)
