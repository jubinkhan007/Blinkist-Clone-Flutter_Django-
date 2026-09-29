from celery import shared_task
from django.utils import timezone
from django.contrib.auth import get_user_model
from datetime import timedelta

from .models import Notification, NotificationPreference

User = get_user_model()


@shared_task
def dispatch_daily_pick_notifications():
    """Dispatches in-app and push notifications for today's Daily Pick to subscribed users."""
    from apps.catalog.daily_pick import get_or_create_daily_pick
    daily_pick = get_or_create_daily_pick()
    if not daily_pick or not daily_pick.book:
        return 0

    book = daily_pick.book
    today = timezone.localdate()
    today_start = timezone.now().replace(hour=0, minute=0, second=0, microsecond=0)

    # Eligible users: active users whose preferences permit daily pick reminders
    users = User.objects.filter(is_active=True).exclude(
        notification_preferences__daily_pick_enabled=False
    )

    created_count = 0
    for user in users:
        # Avoid duplicate notification for same day's pick
        already_sent = Notification.objects.filter(
            user=user,
            notification_type=Notification.NotificationType.DAILY_PICK,
            created_at__gte=today_start,
        ).exists()

        if not already_sent:
            author_text = f" by {book.author.name}" if book.author else ""
            Notification.objects.create(
                user=user,
                title=f"🌟 Free Blink of the Day: {book.title}",
                message=f"Today's free 15-minute insight for '{book.title}'{author_text} is unlocked! Read or listen now.",
                notification_type=Notification.NotificationType.DAILY_PICK,
                action_url=f"/books/{book.slug}/read",
            )
            created_count += 1

    return created_count


@shared_task
def dispatch_streak_reminder_notifications():
    """Reminds users who have an active streak but haven't read yet today."""
    today = timezone.localdate()
    today_start = timezone.now().replace(hour=0, minute=0, second=0, microsecond=0)

    # Users with active streak (> 0) who have not read today yet
    users = User.objects.filter(
        is_active=True,
        current_streak__gt=0,
    ).exclude(
        last_active_date=today
    ).exclude(
        notification_preferences__streak_reminder_enabled=False
    )

    created_count = 0
    for user in users:
        already_sent = Notification.objects.filter(
            user=user,
            notification_type=Notification.NotificationType.STREAK_REMINDER,
            created_at__gte=today_start,
        ).exists()

        if not already_sent:
            streak = user.get_current_streak(today=today)
            if streak > 0:
                Notification.objects.create(
                    user=user,
                    title=f"🔥 Don't lose your {streak}-day streak!",
                    message=f"You have an active {streak}-day habit! Take 5 minutes to read or listen today to keep the flame alive.",
                    notification_type=Notification.NotificationType.STREAK_REMINDER,
                    action_url="/explore",
                )
                created_count += 1

    return created_count
