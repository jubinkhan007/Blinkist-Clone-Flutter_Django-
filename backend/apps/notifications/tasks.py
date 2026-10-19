from celery import shared_task
from django.utils import timezone
from django.contrib.auth import get_user_model
from datetime import timedelta

from .models import Notification, NotificationPreference
from .push_service import send_push_notification

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

    users = User.objects.filter(is_active=True).exclude(
        notification_preferences__daily_pick_enabled=False
    )

    created_count = 0
    for user in users:
        already_sent = Notification.objects.filter(
            user=user,
            notification_type=Notification.NotificationType.DAILY_PICK,
            created_at__gte=today_start,
        ).exists()

        if not already_sent:
            author_text = f" by {book.author.name}" if book.author else ""
            title = f"🌟 Free Blink of the Day: {book.title}"
            message = f"Today's free 15-minute insight for '{book.title}'{author_text} is unlocked! Read or listen now."
            action_url = f"/books/{book.slug}/read"

            Notification.objects.create(
                user=user,
                title=title,
                message=message,
                notification_type=Notification.NotificationType.DAILY_PICK,
                action_url=action_url,
            )
            created_count += 1

            pref = getattr(user, 'notification_preferences', None)
            if pref and pref.fcm_token:
                send_push_notification(
                    fcm_token=pref.fcm_token,
                    title=title,
                    body=message,
                    action_url=action_url,
                    notification_type='daily_pick',
                )

    return created_count


@shared_task
def dispatch_daily_digest_notifications():
    """
    Scheduled morning alert: dispatches in-app and push notification when today's Daily Digest drops.
    """
    from apps.media.models import DailyAudioDigest

    today = timezone.localdate()
    today_start = timezone.now().replace(hour=0, minute=0, second=0, microsecond=0)

    # 1. Look up today's universal DailyAudioDigest
    digest = DailyAudioDigest.objects.filter(date=today, user__isnull=True).first()
    if not digest:
        # Fallback to the latest available universal digest
        digest = DailyAudioDigest.objects.filter(user__isnull=True).order_by('-date').first()

    if not digest:
        return 0

    users = User.objects.filter(is_active=True).exclude(
        notification_preferences__daily_pick_enabled=False
    )

    created_count = 0
    theme_label = digest.theme if digest.theme else "Morning Insights"
    duration_str = digest.formatted_duration if hasattr(digest, 'formatted_duration') else "15 min"

    for user in users:
        already_sent = Notification.objects.filter(
            user=user,
            notification_type=Notification.NotificationType.DAILY_DIGEST,
            created_at__gte=today_start,
        ).exists()

        if not already_sent:
            title = f"☕ Your Daily Blink is ready: {theme_label}"
            message = f"Power your morning with 3 curated audio insights ({duration_str}). Tap to listen now!"
            action_url = "/daily-blink?autoplay=true"

            Notification.objects.create(
                user=user,
                title=title,
                message=message,
                notification_type=Notification.NotificationType.DAILY_DIGEST,
                action_url=action_url,
            )
            created_count += 1

            # Dispatch FCM / APNs Push if token exists
            pref = getattr(user, 'notification_preferences', None)
            if pref and pref.fcm_token:
                send_push_notification(
                    fcm_token=pref.fcm_token,
                    title=title,
                    body=message,
                    action_url=action_url,
                    notification_type='daily_digest',
                )

    return created_count


@shared_task
def dispatch_evening_streak_saver_notifications():
    """
    Evening streak-saver reminders with personalized book recommendations based on finished categories.
    """
    from apps.catalog.models import Book, Category
    from apps.progress.models import UserBookProgress

    today = timezone.localdate()
    today_start = timezone.now().replace(hour=0, minute=0, second=0, microsecond=0)

    # Eligible users: active streak (> 0), haven't read today, reminders enabled
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
            if streak <= 0:
                continue

            # Query user's finished or active categories
            read_progresses = UserBookProgress.objects.filter(
                user=user,
                percent_complete__gt=0,
            ).select_related('book')

            finished_category_ids = []
            for prog in read_progresses:
                finished_category_ids.extend(prog.book.categories.values_list('id', flat=True))

            rec_book = None
            category_name = ""

            if finished_category_ids:
                # Find an unread book in these user-favored categories
                rec_book = Book.objects.filter(
                    categories__id__in=finished_category_ids
                ).exclude(
                    user_progress__user=user,
                    user_progress__is_completed=True
                ).order_by('-rating', '-created_at').first()

                if rec_book:
                    matched_cat = rec_book.categories.filter(id__in=finished_category_ids).first()
                    if matched_cat:
                        category_name = f" in {matched_cat.name}"

            if not rec_book:
                # Fallback to top rated unread book in catalog
                rec_book = Book.objects.exclude(
                    user_progress__user=user,
                    user_progress__is_completed=True
                ).order_by('-rating', '-created_at').first()

            if rec_book:
                title = f"🔥 Protect your {streak}-day streak!"
                message = f"Only a few hours left today! Keep your habit strong with 15 mins of '{rec_book.title}'{category_name}."
                action_url = f"/books/{rec_book.slug}/read"
            else:
                title = f"🔥 Protect your {streak}-day streak!"
                message = f"You have an active {streak}-day habit! Take 5 minutes to read or listen today to keep the flame alive."
                action_url = "/explore"

            Notification.objects.create(
                user=user,
                title=title,
                message=message,
                notification_type=Notification.NotificationType.STREAK_REMINDER,
                action_url=action_url,
            )
            created_count += 1

            pref = getattr(user, 'notification_preferences', None)
            if pref and pref.fcm_token:
                send_push_notification(
                    fcm_token=pref.fcm_token,
                    title=title,
                    body=message,
                    action_url=action_url,
                    notification_type='streak_reminder',
                )

    return created_count


@shared_task
def dispatch_streak_reminder_notifications():
    """Reminds users who have an active streak but haven't read yet today (delegates to evening streak saver)."""
    return dispatch_evening_streak_saver_notifications()


@shared_task
def dispatch_new_book_notifications(book_id):
    """Notifies users when a new book summary is added or featured."""
    from apps.catalog.models import Book
    try:
        book = Book.objects.get(id=book_id)
    except Book.DoesNotExist:
        return 0

    author_name = book.author.name if book.author else "Featured Author"
    users = User.objects.filter(is_active=True)
    created_count = 0

    for user in users:
        # Avoid duplicate notification for same book
        already_sent = Notification.objects.filter(
            user=user,
            notification_type=Notification.NotificationType.NEW_BOOK,
            action_url=f"/books/{book.slug}",
        ).exists()

        if not already_sent:
            Notification.objects.create(
                user=user,
                title=f"📚 New Arrival: {book.title}",
                message=f"Explore key takeaways from '{book.title}' by {author_name}. Read or listen in 15 minutes!",
                notification_type=Notification.NotificationType.NEW_BOOK,
                action_url=f"/books/{book.slug}",
            )
            created_count += 1

    return created_count


@shared_task
def dispatch_collection_notifications(collection_id):
    """Notifies users when a new curated bundle / collection is published."""
    from apps.catalog.models import Collection
    try:
        collection = Collection.objects.get(id=collection_id)
    except Collection.DoesNotExist:
        return 0

    users = User.objects.filter(is_active=True)
    created_count = 0
    desc_snippet = (collection.description[:80] + "...") if len(collection.description) > 80 else collection.description

    for user in users:
        already_sent = Notification.objects.filter(
            user=user,
            notification_type=Notification.NotificationType.SYSTEM,
            action_url=f"/collections/{collection.slug}",
        ).exists()

        if not already_sent:
            Notification.objects.create(
                user=user,
                title=f"✨ Featured Bundle: {collection.title}",
                message=f"{desc_snippet} Start this curated learning journey now.",
                notification_type=Notification.NotificationType.SYSTEM,
                action_url=f"/collections/{collection.slug}",
            )
            created_count += 1

    return created_count

