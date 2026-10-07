from django.contrib import admin, messages
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
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
        'tier_badge',
        'badges_count',
        'is_staff',
        'is_active',
        'date_joined',
    )
    list_filter = ('is_premium', 'is_staff', 'is_superuser', 'is_active', 'date_joined')
    search_fields = ('email', 'username')
    ordering = ('-date_joined',)
    actions = ['grant_premium', 'revoke_premium']

    fieldsets = BaseUserAdmin.fieldsets + (
        ('Blinkist Profile Info', {
            'fields': ('is_premium', 'bio', 'avatar_url'),
        }),
    )

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

    @display(
        description='Membership',
        label={
            'PREMIUM': 'warning',
            'STANDARD': 'info',
        },
    )
    def tier_badge(self, obj):
        return 'PREMIUM' if obj.is_premium else 'STANDARD'

    @display(description='Badges')
    def badges_count(self, obj):
        count = obj.badges.count()
        return format_html(
            '<span style="font-weight: 600; color: #f59e0b;">🏆 {}</span>',
            count,
        )

    def grant_premium(self, request, queryset):
        updated = queryset.update(is_premium=True)
        self.message_user(request, f'{updated} user(s) granted Premium membership.', messages.SUCCESS)
    grant_premium.short_description = 'Grant Premium access to selected users'

    def revoke_premium(self, request, queryset):
        updated = queryset.update(is_premium=False)
        self.message_user(request, f'{updated} user(s) set to Standard membership.', messages.SUCCESS)
    revoke_premium.short_description = 'Revoke Premium access for selected users'
