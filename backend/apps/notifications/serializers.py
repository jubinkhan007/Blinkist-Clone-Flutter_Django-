from rest_framework import serializers
from .models import Notification, NotificationPreference


class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = (
            'id',
            'title',
            'message',
            'notification_type',
            'action_url',
            'is_read',
            'created_at',
        )
        read_only_fields = (
            'id',
            'title',
            'message',
            'notification_type',
            'action_url',
            'created_at',
        )


class NotificationPreferenceSerializer(serializers.ModelSerializer):
    class Meta:
        model = NotificationPreference
        fields = (
            'daily_pick_enabled',
            'streak_reminder_enabled',
            'reminder_time',
            'fcm_token',
        )
