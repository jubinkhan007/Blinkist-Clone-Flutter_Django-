from __future__ import annotations

from datetime import timedelta
from django.contrib import admin, messages
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.utils import timezone
from django.utils.html import format_html
from unfold.admin import ModelAdmin
from unfold.decorators import action, display

from .models import User


@admin.register(User)
class CustomUserAdmin(BaseUserAdmin, ModelAdmin):
    model = User
    list_display = (
        'avatar_preview',
        'email',
        'username',
        'subscription_badge',
        'streak_badge',
        'onboarding_badge',
        'format_badge',
        'badges_count',
        'is_staff',
        'date_joined',
    )
    list_filter = (
        'is_premium',
        'subscription_status',
        'has_completed_onboarding',
        'preferred_format',
        'is_staff',
        'is_superuser',
        'is_active',
        'date_joined',
    )
    search_fields = ('email', 'username', 'sslcommerz_tran_id', 'reading_goal')
    ordering = ('-date_joined',)
    actions = [
        'grant_30_day_subscription',
        'cancel_subscription_action',
        'grant_premium',
        'revoke_premium',
        'reset_streak_action',
    ]

    fieldsets = (
        (None, {'fields': ('username', 'password')}),
        ('Personal Info', {'fields': ('first_name', 'last_name', 'email', 'bio', 'avatar_url')}),
        ('Subscription & Membership', {
            'fields': (
                'is_premium',
                'subscription_status',
                'trial_started_at',
                'subscription_end_date',
                'sslcommerz_tran_id',
            ),
        }),
        ('Habit & Streak Progress', {
            'fields': (
                'current_streak',
                'longest_streak',
                'last_active_date',
            ),
        }),
        ('Onboarding & Preferences', {
            'fields': (
                'has_completed_onboarding',
                'reading_goal',
                'preferred_format',
                'interest_topics',
                'interest_categories',
            ),
        }),
        ('Permissions & Staff Access', {
            'fields': (
                'is_active',
                'is_staff',
                'is_superuser',
                'groups',
                'user_permissions',
            ),
        }),
        ('Important dates', {'fields': ('last_login', 'date_joined')}),
    )
    filter_horizontal = ('groups', 'user_permissions', 'interest_categories')

    @display(description='Avatar')
    def avatar_preview(self, obj):
        if obj.avatar_url:
            return format_html(
                '<img src="{}" style="width: 28px; height: 28px; border-radius: 50%; object-fit: cover;" />',
                obj.avatar_url,
            )
        initial = (obj.username or obj.email or '?')[:1].upper()
        return format_html(
            '<div style="width: 28px; height: 28px; border-radius: 50%; background: #10b981; color: white; display: flex; align-items: center; justify-content: center; font-weight: bold; font-size: 11px;">{}</div>',
            initial,
        )

    @display(description='Subscription')
    def subscription_badge(self, obj):
        status = obj.subscription_status
        if obj.is_premium and status == User.SubscriptionStatus.ACTIVE:
            return format_html(
                '<span style="padding: 2px 8px; border-radius: 9999px; background: #ecfdf5; color: #065f46; font-weight: 600; font-size: 11px;">🟢 Active Pro</span>'
            )
        elif status == User.SubscriptionStatus.TRIALING:
            return format_html(
                '<span style="padding: 2px 8px; border-radius: 9999px; background: #fef3c7; color: #92400e; font-weight: 600; font-size: 11px;">🟡 Trialing</span>'
            )
        elif status == User.SubscriptionStatus.CANCELLED:
            return format_html(
                '<span style="padding: 2px 8px; border-radius: 9999px; background: #f1f5f9; color: #475569; font-weight: 600; font-size: 11px;">⚪ Cancelled</span>'
            )
        elif status == User.SubscriptionStatus.EXPIRED:
            return format_html(
                '<span style="padding: 2px 8px; border-radius: 9999px; background: #ffe4e6; color: #9f1239; font-weight: 600; font-size: 11px;">🔴 Expired</span>'
            )
        return format_html(
            '<span style="padding: 2px 8px; border-radius: 9999px; background: #f3f4f6; color: #6b7280; font-weight: 500; font-size: 11px;">Standard</span>'
        )

    @display(description='Streak', ordering='current_streak')
    def streak_badge(self, obj):
        if obj.current_streak > 0:
            return format_html(
                '<span style="font-weight: 600; color: #ea580c; font-size: 12px;">🔥 {} <span style="font-size: 10px; color: #9a3412;">(max {})</span></span>',
                obj.current_streak,
                obj.longest_streak,
            )
        return format_html('<span style="color: #9ca3af; font-size: 11px;">0 d</span>')

    @display(description='Onboarding', boolean=True)
    def onboarding_badge(self, obj):
        return obj.has_completed_onboarding

    @display(description='Format')
    def format_badge(self, obj):
        fmt = (obj.preferred_format or 'both').lower()
        if fmt == 'audio':
            return format_html('<span style="color: #7c3aed; font-size: 11px;">🎧 Audio</span>')
        elif fmt == 'text':
            return format_html('<span style="color: #2563eb; font-size: 11px;">📖 Text</span>')
        return format_html('<span style="color: #059669; font-size: 11px;">⚡ Both</span>')

    @display(description='Badges')
    def badges_count(self, obj):
        count = obj.badges.count()
        return format_html(
            '<span style="font-weight: 600; color: #f59e0b;">🏆 {}</span>',
            count,
        )

    def grant_30_day_subscription(self, request, queryset):
        now = timezone.now()
        updated = queryset.update(
            is_premium=True,
            subscription_status=User.SubscriptionStatus.ACTIVE,
            subscription_end_date=now + timedelta(days=30),
        )
        self.message_user(request, f'{updated} user(s) granted 30-Day Premium subscription.', messages.SUCCESS)
    grant_30_day_subscription.short_description = '⚡ Grant 30-Day Premium Subscription'

    def cancel_subscription_action(self, request, queryset):
        updated = queryset.update(
            is_premium=False,
            subscription_status=User.SubscriptionStatus.CANCELLED,
        )
        self.message_user(request, f'{updated} user(s) subscription cancelled.', messages.SUCCESS)
    cancel_subscription_action.short_description = '❌ Cancel subscription for selected users'

    def grant_premium(self, request, queryset):
        updated = queryset.update(is_premium=True, subscription_status=User.SubscriptionStatus.ACTIVE)
        self.message_user(request, f'{updated} user(s) granted Premium membership.', messages.SUCCESS)
    grant_premium.short_description = 'Grant Premium access to selected users'

    def revoke_premium(self, request, queryset):
        updated = queryset.update(is_premium=False, subscription_status=User.SubscriptionStatus.EXPIRED)
        self.message_user(request, f'{updated} user(s) set to Standard membership.', messages.SUCCESS)
    revoke_premium.short_description = 'Revoke Premium access for selected users'

    def reset_streak_action(self, request, queryset):
        updated = queryset.update(current_streak=0)
        self.message_user(request, f'{updated} user(s) streak counter reset to 0.', messages.SUCCESS)
    reset_streak_action.short_description = '🔄 Reset streak counter to 0'
