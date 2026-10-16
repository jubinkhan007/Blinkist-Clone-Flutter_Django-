from __future__ import annotations

import uuid
from django.contrib import admin, messages
from django.utils.html import format_html
from unfold.admin import ModelAdmin
from unfold.decorators import action, display

from .models import (
    CouponRedemption,
    DiscountCoupon,
    PaymentTransaction,
    SubscriptionPlan,
    UserReferralProfile,
)
from .services import activate_subscription_for_user


@admin.register(SubscriptionPlan)
class SubscriptionPlanAdmin(ModelAdmin):
    list_display = (
        'name',
        'interval_badge',
        'price_usd_display',
        'trial_days',
        'badge_text',
        'is_featured',
        'is_active',
        'order',
    )
    list_filter = ('billing_interval', 'is_active', 'is_featured')
    search_fields = ('name', 'slug', 'stripe_price_id', 'apple_product_id', 'google_product_id')
    prepopulated_fields = {'slug': ('name',)}

    @display(
        description='Interval',
        label={
            'month': 'info',
            'year': 'success',
            'lifetime': 'warning',
        },
    )
    def interval_badge(self, obj):
        return obj.billing_interval

    @display(description='Price (USD)')
    def price_usd_display(self, obj):
        return f"${obj.price_usd}"


@admin.register(DiscountCoupon)
class DiscountCouponAdmin(ModelAdmin):
    list_display = (
        'code',
        'discount_badge',
        'is_referral',
        'referred_by_email',
        'times_used',
        'max_uses_display',
        'valid_until',
        'is_active',
    )
    list_filter = ('is_referral', 'is_active', 'discount_percent')
    search_fields = ('code', 'referred_by__email')
    actions = ['generate_promo_codes_action', 'toggle_active_action']

    @display(
        description='Discount',
        label='success',
    )
    def discount_badge(self, obj):
        return f"{obj.discount_percent}% OFF"

    @display(description='Referred By')
    def referred_by_email(self, obj):
        return obj.referred_by.email if obj.referred_by else '-'

    @display(description='Max Uses')
    def max_uses_display(self, obj):
        return str(obj.max_uses) if obj.max_uses is not None else '∞ Unlimited'

    @action(description='🎁 Generate 5 Unique 30% Promo Codes')
    def generate_promo_codes_action(self, request, queryset):
        created_codes = []
        for _ in range(5):
            code = f"BLINK-{uuid.uuid4().hex[:6].upper()}"
            DiscountCoupon.objects.create(
                code=code,
                discount_percent=30,
                is_active=True,
            )
            created_codes.append(code)
        self.message_user(
            request,
            f"Created 5 promo codes: {', '.join(created_codes)}",
            level=messages.SUCCESS,
        )

    @action(description='Toggle Active Status')
    def toggle_active_action(self, request, queryset):
        for coupon in queryset:
            coupon.is_active = not coupon.is_active
            coupon.save(update_fields=['is_active'])
        self.message_user(request, "Updated coupon active statuses.", level=messages.INFO)


@admin.register(PaymentTransaction)
class PaymentTransactionAdmin(ModelAdmin):
    list_display = (
        'transaction_id',
        'user_email',
        'plan_name',
        'amount_display',
        'gateway_badge',
        'status_badge',
        'created_at',
    )
    list_filter = ('gateway', 'status', 'currency', 'created_at')
    search_fields = ('transaction_id', 'user__email', 'gateway_session_id')
    readonly_fields = ('created_at', 'updated_at')
    actions = ['complete_and_activate_action']

    @display(description='User')
    def user_email(self, obj):
        return obj.user.email if obj.user else '-'

    @display(description='Plan')
    def plan_name(self, obj):
        return obj.plan.name if obj.plan else '-'

    @display(description='Amount')
    def amount_display(self, obj):
        return f"${obj.amount} {obj.currency}"

    @display(
        description='Gateway',
        label={
            'STRIPE': 'info',
            'APPLE_IAP': 'primary',
            'GOOGLE_PLAY': 'success',
            'SSLCOMMERZ': 'warning',
            'MOCK': 'secondary',
        },
    )
    def gateway_badge(self, obj):
        return obj.gateway

    @display(
        description='Status',
        label={
            'PENDING': 'warning',
            'COMPLETED': 'success',
            'FAILED': 'danger',
            'REFUNDED': 'info',
        },
    )
    def status_badge(self, obj):
        return obj.status

    @action(description='✅ Mark Completed & Activate User Premium')
    def complete_and_activate_action(self, request, queryset):
        count = 0
        for tx in queryset:
            tx.status = 'COMPLETED'
            tx.save(update_fields=['status'])
            activate_subscription_for_user(tx.user, plan=tx.plan, coupon=tx.discount_coupon)
            count += 1
        self.message_user(request, f"Activated premium for {count} transaction(s).", level=messages.SUCCESS)


@admin.register(UserReferralProfile)
class UserReferralProfileAdmin(ModelAdmin):
    list_display = (
        'user_email',
        'referral_code',
        'successful_referrals_count',
        'bonus_days_earned',
        'created_at',
    )
    search_fields = ('user__email', 'referral_code')
    readonly_fields = ('created_at',)

    @display(description='User')
    def user_email(self, obj):
        return obj.user.email if obj.user else '-'


@admin.register(CouponRedemption)
class CouponRedemptionAdmin(ModelAdmin):
    list_display = ('coupon_code', 'user_email', 'discount_applied_display', 'redeemed_at')
    search_fields = ('coupon__code', 'user__email')
    readonly_fields = ('redeemed_at',)

    @display(description='Coupon')
    def coupon_code(self, obj):
        return obj.coupon.code if obj.coupon else '-'

    @display(description='User')
    def user_email(self, obj):
        return obj.user.email if obj.user else '-'

    @display(description='Discount Applied')
    def discount_applied_display(self, obj):
        return f"${obj.discount_applied_usd}"
