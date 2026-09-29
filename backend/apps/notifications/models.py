from django.db import models
from django.conf import settings
import datetime


class Notification(models.Model):
    class NotificationType(models.TextChoices):
        DAILY_PICK = 'daily_pick', 'Daily Pick'
        STREAK_REMINDER = 'streak_reminder', 'Streak Reminder'
        NEW_BOOK = 'new_book', 'New Content'
        SUBSCRIPTION = 'subscription', 'Subscription'
        SYSTEM = 'system', 'System'

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='notifications',
    )
    title = models.CharField(max_length=255)
    message = models.TextField()
    notification_type = models.CharField(
        max_length=32,
        choices=NotificationType.choices,
        default=NotificationType.SYSTEM,
    )
    action_url = models.CharField(max_length=255, blank=True, default='')
    is_read = models.BooleanField(default=False, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.user.email} - [{self.notification_type}] {self.title}"


class NotificationPreference(models.Model):
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='notification_preferences',
    )
    daily_pick_enabled = models.BooleanField(default=True)
    streak_reminder_enabled = models.BooleanField(default=True)
    reminder_time = models.TimeField(default=datetime.time(8, 30))
    fcm_token = models.CharField(max_length=255, blank=True, default='')
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Preferences for {self.user.email}"
