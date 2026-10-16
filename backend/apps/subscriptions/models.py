from __future__ import annotations

import decimal
from typing import Any
from django.conf import settings
from django.db import models
from django.utils import timezone

from apps.accounts.models import User


class SubscriptionPlan(models.Model):
    INTERVAL_CHOICES = [
        ('month', 'Monthly'),
        ('year', 'Yearly'),
        ('lifetime', 'Lifetime Access'),
    ]

    name = models.CharField(max_length=100)
    slug = models.SlugField(max_length=50, unique=True)
    billing_interval = models.CharField(max_length=20, choices=INTERVAL_CHOICES, default='month')
    price_usd = models.DecimalField(max_digits=6, decimal_places=2, default=decimal.Decimal('9.99'))
    price_bdt = models.DecimalField(max_digits=8, decimal_places=2, default=decimal.Decimal('999.00'))
    stripe_price_id = models.CharField(max_length=120, blank=True, default='')
    apple_product_id = models.CharField(max_length=120, blank=True, default='')
    google_product_id = models.CharField(max_length=120, blank=True, default='')
    trial_days = models.PositiveIntegerField(default=7)
    features = models.JSONField(default=list, blank=True)
    badge_text = models.CharField(max_length=50, blank=True, default='', help_text="e.g. 'BEST VALUE', 'MOST POPULAR'")
    is_active = models.BooleanField(default=True)
    is_featured = models.BooleanField(default=False)
    order = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['order', 'price_usd']

    def __str__(self):
        return f"{self.name} (${self.price_usd} / {self.billing_interval})"


class DiscountCoupon(models.Model):
    code = models.CharField(max_length=32, unique=True, db_index=True)
    discount_percent = models.PositiveIntegerField(default=20, help_text="Percentage off (1-100)")
    is_referral = models.BooleanField(default=False)
    referred_by = models.ForeignKey(
        User,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='referral_coupons',
    )
    max_uses = models.PositiveIntegerField(null=True, blank=True, help_text="Leave blank for unlimited uses")
    times_used = models.PositiveIntegerField(default=0)
    valid_from = models.DateTimeField(default=timezone.now)
    valid_until = models.DateTimeField(null=True, blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.code} ({self.discount_percent}% off)"

    @property
    def is_valid(self) -> bool:
        if not self.is_active:
            return False
        now = timezone.now()
        if now < self.valid_from:
            return False
        if self.valid_until and now > self.valid_until:
            return False
        if self.max_uses is not None and self.times_used >= self.max_uses:
            return False
        return True

    def calculate_discounted_price(self, original_price: Any) -> decimal.Decimal:
        price = decimal.Decimal(str(original_price))
        factor = decimal.Decimal(100 - self.discount_percent) / decimal.Decimal(100)
        discounted = (price * factor).quantize(decimal.Decimal('.01'), rounding=decimal.ROUND_HALF_UP)
        return max(decimal.Decimal('0.00'), discounted)


class CouponRedemption(models.Model):
    coupon = models.ForeignKey(DiscountCoupon, on_delete=models.CASCADE, related_name='redemptions')
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='coupon_redemptions')
    discount_applied_usd = models.DecimalField(max_digits=6, decimal_places=2, default=decimal.Decimal('0.00'))
    redeemed_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-redeemed_at']

    def __str__(self):
        return f"{self.user.email} redeemed {self.coupon.code}"


class PaymentTransaction(models.Model):
    GATEWAY_CHOICES = [
        ('STRIPE', 'Stripe Checkout'),
        ('APPLE_IAP', 'Apple In-App Purchase'),
        ('GOOGLE_PLAY', 'Google Play Billing'),
        ('SSLCOMMERZ', 'SSLCommerz'),
        ('MOCK', 'Mock Gateway'),
    ]
    STATUS_CHOICES = [
        ('PENDING', 'Pending'),
        ('COMPLETED', 'Completed'),
        ('FAILED', 'Failed'),
        ('REFUNDED', 'Refunded'),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='payment_transactions')
    plan = models.ForeignKey(SubscriptionPlan, on_delete=models.SET_NULL, null=True, blank=True, related_name='transactions')
    gateway = models.CharField(max_length=32, choices=GATEWAY_CHOICES, default='STRIPE')
    transaction_id = models.CharField(max_length=120, unique=True, db_index=True)
    gateway_session_id = models.CharField(max_length=255, blank=True, default='')
    amount = models.DecimalField(max_digits=8, decimal_places=2)
    currency = models.CharField(max_length=10, default='USD')
    discount_coupon = models.ForeignKey(DiscountCoupon, on_delete=models.SET_NULL, null=True, blank=True, related_name='transactions')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='PENDING')
    metadata = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"[{self.gateway}] {self.transaction_id} - ${self.amount} ({self.status})"


class UserReferralProfile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='referral_profile')
    referral_code = models.CharField(max_length=32, unique=True, db_index=True)
    successful_referrals_count = models.PositiveIntegerField(default=0)
    bonus_days_earned = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user.email} - Code: {self.referral_code} ({self.successful_referrals_count} refs)"
