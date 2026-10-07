from django.contrib import admin
from unfold.admin import ModelAdmin
from unfold.decorators import display

from .models import Notification, NotificationPreference


@admin.register(Notification)
class NotificationAdmin(ModelAdmin):
    list_display = ('user', 'title', 'type_badge', 'read_badge', 'created_at')
    list_filter = ('notification_type', 'is_read', 'created_at')
    search_fields = ('user__email', 'title', 'message')
    readonly_fields = ('created_at',)
    date_hierarchy = 'created_at'
    ordering = ('-created_at',)

    @display(
        description='Type',
        label={
            'daily_pick': 'info',
            'streak_reminder': 'warning',
            'badge_unlocked': 'success',
            'general': 'primary',
        },
    )
    def type_badge(self, obj):
        return obj.notification_type

    @display(description='Read', boolean=True)
    def read_badge(self, obj):
        return obj.is_read


@admin.register(NotificationPreference)
class NotificationPreferenceAdmin(ModelAdmin):
    list_display = (
        'user',
        'daily_pick_enabled',
        'streak_reminder_enabled',
        'reminder_time',
        'updated_at',
    )
    search_fields = ('user__email',)
    list_filter = ('daily_pick_enabled', 'streak_reminder_enabled')
    ordering = ('-updated_at',)
