from django.utils import timezone
from datetime import timedelta
from django.db import models

from .models import (
    UserBadge,
    UserBookProgress,
    UserSummaryProgress,
    UserAudioProgress,
    UserDailyActivity,
)
from apps.summaries.models import UserHighlight

BADGE_DEFINITIONS = [
    # Habits & Streaks
    {
        'key': 'first_spark',
        'title': 'First Spark',
        'description': 'Active reading habit started.',
        'category': 'streaks',
        'icon': 'local_fire_department',
        'target': 1,
        'metric': 'longest_streak',
    },
    {
        'key': 'streak_3',
        'title': '3-Day Momentum',
        'description': 'Maintained a daily reading streak for 3 days.',
        'category': 'streaks',
        'icon': 'electric_bolt',
        'target': 3,
        'metric': 'longest_streak',
    },
    {
        'key': 'streak_7',
        'title': '7-Day Habit Master',
        'description': 'Built an unbreakable 7-day continuous reading habit.',
        'category': 'streaks',
        'icon': 'military_tech',
        'target': 7,
        'metric': 'longest_streak',
    },
    {
        'key': 'streak_14',
        'title': 'Unstoppable',
        'description': 'Achieved a stellar 14-day streak without missing a day.',
        'category': 'streaks',
        'icon': 'stars',
        'target': 14,
        'metric': 'longest_streak',
    },
    {
        'key': 'streak_30',
        'title': 'Legendary Consistency',
        'description': 'Monumental 30-day streak! You are in the top 1% of learners.',
        'category': 'streaks',
        'icon': 'workspace_premium',
        'target': 30,
        'metric': 'longest_streak',
    },
    # Books Completed
    {
        'key': 'first_blink',
        'title': 'First Blink',
        'description': 'Finished your very first book summary.',
        'category': 'books',
        'icon': 'menu_book',
        'target': 1,
        'metric': 'books_completed',
    },
    {
        'key': 'finisher_5',
        'title': 'Avid Learner',
        'description': 'Completed 5 book summaries.',
        'category': 'books',
        'icon': 'library_books',
        'target': 5,
        'metric': 'books_completed',
    },
    {
        'key': 'finisher_10',
        'title': 'Knowledge Seeker',
        'description': 'Completed 10 book summaries.',
        'category': 'books',
        'icon': 'auto_stories',
        'target': 10,
        'metric': 'books_completed',
    },
    {
        'key': 'finisher_25',
        'title': 'Master Mind',
        'description': 'Completed 25 book summaries and expanded your horizon.',
        'category': 'books',
        'icon': 'psychology',
        'target': 25,
        'metric': 'books_completed',
    },
    # Audio Mastery
    {
        'key': 'first_listen',
        'title': 'First Listen',
        'description': 'Listened to your first audio book summary.',
        'category': 'audio',
        'icon': 'headphones',
        'target': 1,
        'metric': 'audio_minutes',
    },
    {
        'key': 'audio_30m',
        'title': 'Audio Explorer',
        'description': 'Streamed at least 30 minutes of insightful audio summaries.',
        'category': 'audio',
        'icon': 'graphic_eq',
        'target': 30,
        'metric': 'audio_minutes',
    },
    {
        'key': 'audio_60m',
        'title': 'Audio Champion',
        'description': 'Listened to over 60 minutes of bite-sized knowledge.',
        'category': 'audio',
        'icon': 'volume_up',
        'target': 60,
        'metric': 'audio_minutes',
    },
    {
        'key': 'audio_prodigy',
        'title': 'Audio Prodigy',
        'description': 'Listened to over 180 minutes of audio insights on the go.',
        'category': 'audio',
        'icon': 'podcasts',
        'target': 180,
        'metric': 'audio_minutes',
    },
    # Curator & Highlights
    {
        'key': 'first_highlight',
        'title': 'First Highlight',
        'description': 'Saved your first memorable quote.',
        'category': 'highlights',
        'icon': 'edit_note',
        'target': 1,
        'metric': 'highlights_count',
    },
    {
        'key': 'deep_thinker',
        'title': 'Deep Thinker',
        'description': 'Saved 5 inspiring quotes in your personal notebook.',
        'category': 'highlights',
        'icon': 'format_quote',
        'target': 5,
        'metric': 'highlights_count',
    },
    {
        'key': 'wisdom_collector',
        'title': 'Wisdom Collector',
        'description': 'Saved 20 thought-provoking quotes.',
        'category': 'highlights',
        'icon': 'collections_bookmark',
        'target': 20,
        'metric': 'highlights_count',
    },
    # Special
    {
        'key': 'weekend_warrior',
        'title': 'Weekend Warrior',
        'description': 'Completed reading activity on both Saturday and Sunday.',
        'category': 'special',
        'icon': 'weekend',
        'target': 1,
        'metric': 'weekend_activity',
    },
]

BADGES = {b['key']: b for b in BADGE_DEFINITIONS}


def evaluate_and_award_badges(user):
    """
    Evaluates all badges against user activity metrics, unlocks newly achieved
    badges idempotently in UserBadge, and returns formatted badge items.
    """
    if not user or not user.is_authenticated:
        return []

    # 1. Gather User Metrics
    longest_streak = max(user.longest_streak, user.get_current_streak())

    # Books completed
    completed_book_ids = set(
        UserBookProgress.objects.filter(user=user, is_completed=True).values_list('book_id', flat=True)
    )
    for sp in UserSummaryProgress.objects.filter(user=user).select_related('book'):
        total_secs = sp.book.sections.count()
        if total_secs > 0 and sp.completed_sections_count >= total_secs:
            completed_book_ids.add(sp.book_id)
    books_completed = len(completed_book_ids)

    # Audio minutes
    audio_secs = UserAudioProgress.objects.filter(user=user).aggregate(
        total=models.Sum('current_position_seconds')
    )['total'] or 0.0
    audio_minutes = int(round(audio_secs / 60.0))

    # Highlights
    highlights_count = UserHighlight.objects.filter(user=user).count()

    # Weekend activity: check if user read on both Saturday and Sunday of any recent week
    recent_dates = list(
        UserDailyActivity.objects.filter(user=user).values_list('date', flat=True)
    )
    has_weekend_activity = False
    # Check if there is any weekend (Saturday and Sunday) where both are present
    weekend_saturdays = {d for d in recent_dates if d.weekday() == 5}
    for sat in weekend_saturdays:
        sun = sat + timedelta(days=1)
        if sun in recent_dates:
            has_weekend_activity = True
            break

    metrics_map = {
        'longest_streak': longest_streak,
        'books_completed': books_completed,
        'audio_minutes': audio_minutes,
        'highlights_count': highlights_count,
        'weekend_activity': 1 if has_weekend_activity else 0,
    }

    # 2. Existing unlocked badges
    unlocked_badges = dict(
        UserBadge.objects.filter(user=user).values_list('badge_key', 'unlocked_at')
    )

    result_badges = []
    badges_to_create = []

    for badge in BADGE_DEFINITIONS:
        key = badge['key']
        target = badge['target']
        current_val = metrics_map.get(badge['metric'], 0)
        is_unlocked = key in unlocked_badges or current_val >= target

        unlocked_at = unlocked_badges.get(key)
        if is_unlocked and key not in unlocked_badges:
            badges_to_create.append(UserBadge(user=user, badge_key=key))
            unlocked_at = timezone.now()

        progress_percent = min(1.0, current_val / float(target)) if target > 0 else 1.0

        result_badges.append({
            'key': key,
            'title': badge['title'],
            'description': badge['description'],
            'category': badge['category'],
            'icon': badge['icon'],
            'is_unlocked': is_unlocked,
            'unlocked_at': unlocked_at.isoformat() if unlocked_at else None,
            'current_progress': min(current_val, target),
            'target_progress': target,
            'progress_percent': round(progress_percent, 2),
        })

    if badges_to_create:
        UserBadge.objects.bulk_create(badges_to_create, ignore_conflicts=True)

    return result_badges
