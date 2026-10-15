from __future__ import annotations

from datetime import timedelta
from django.conf import settings
from django.db.models import Sum
from django.utils import timezone

from apps.accounts.models import User
from apps.catalog.models import Book, ContentIngestionJob, DailyPick, SearchQueryLog, UserReadingList
from apps.media.models import DailyAudioDigest, UserDailyDigestProgress
from apps.progress.models import UserBadge, UserDailyActivity
from apps.summaries.models import BookFlashcard, SummarySection, UserFlashcardReview, UserHighlight


def dashboard_callback(request, context):
    """
    Supplies rich aggregated statistics, revenue metrics, and feeds to the Django Unfold admin dashboard.
    """
    today = timezone.localdate()

    # Catalog & Audio stats
    total_books = Book.objects.count()
    premium_books = Book.objects.filter(is_premium=True).count()
    total_sections = SummarySection.objects.count()
    audio_sections = SummarySection.objects.exclude(audio_file='').exclude(audio_file__isnull=True).count()
    audio_coverage_pct = round((audio_sections / total_sections * 100), 1) if total_sections else 0

    total_audio_seconds = SummarySection.objects.aggregate(total=Sum('duration_seconds'))['total'] or 0
    total_audio_hours = round(total_audio_seconds / 3600, 1)

    # User & Engagement stats
    total_users = User.objects.count()
    premium_users = User.objects.filter(is_premium=True).count()

    today_activities = UserDailyActivity.objects.filter(date=today)
    active_today_count = today_activities.values('user').distinct().count()
    today_read_mins = today_activities.aggregate(total=Sum('reading_minutes'))['total'] or 0
    today_audio_mins = today_activities.aggregate(total=Sum('audio_minutes'))['total'] or 0

    total_badges_unlocked = UserBadge.objects.count()

    # Subscription & Revenue stats
    active_subscribers = User.objects.filter(subscription_status='active', is_premium=True).count()
    trialing_subscribers = User.objects.filter(subscription_status='trialing').count()
    cancelled_subscribers = User.objects.filter(subscription_status='cancelled').count()
    sub_price = getattr(settings, 'SUBSCRIPTION_PRICE_BDT', 149.0)
    estimated_mrr_bdt = round(active_subscribers * sub_price, 2)

    # Ingestion pipeline health
    pending_jobs = ContentIngestionJob.objects.filter(status='PENDING').count()
    failed_jobs = ContentIngestionJob.objects.filter(status='FAILED').count()
    completed_jobs = ContentIngestionJob.objects.filter(status='COMPLETED').count()

    # Spaced Repetition & Flashcards
    total_flashcards = BookFlashcard.objects.count()
    total_reviews = UserFlashcardReview.objects.count()
    mastered_reviews = UserFlashcardReview.objects.filter(status='mastered').count()
    mastery_rate = round((mastered_reviews / total_reviews * 100), 1) if total_reviews else 0

    # User Reading Lists & Spaces
    total_reading_spaces = UserReadingList.objects.count()
    public_spaces = UserReadingList.objects.filter(is_public=True).count()

    # Daily Audio Digest status
    today_digest = DailyAudioDigest.objects.filter(date=today, user=None).first()
    digest_completions_today = UserDailyDigestProgress.objects.filter(digest__date=today, is_completed=True).count()

    # Highlights & Feeds
    today_pick = DailyPick.objects.filter(date=today).select_related('book', 'book__author').first()
    recent_activities = (
        UserDailyActivity.objects.select_related('user')
        .order_by('-date', '-created_at')[:6]
    )
    recent_highlights = (
        UserHighlight.objects.select_related('user', 'book')
        .order_by('-created_at')[:5]
    )
    trending_searches = SearchQueryLog.objects.order_by('-count', '-last_searched_at')[:8]

    context.update({
        'kpi': {
            'total_books': total_books,
            'premium_books': premium_books,
            'free_books': total_books - premium_books,
            'total_sections': total_sections,
            'audio_sections': audio_sections,
            'audio_coverage_pct': audio_coverage_pct,
            'total_audio_hours': total_audio_hours,
            'total_users': total_users,
            'premium_users': premium_users,
            'active_today_count': active_today_count,
            'today_learning_mins': today_read_mins + today_audio_mins,
            'today_read_mins': today_read_mins,
            'today_audio_mins': today_audio_mins,
            'total_badges_unlocked': total_badges_unlocked,
            'pending_jobs': pending_jobs,
            'failed_jobs': failed_jobs,
            'completed_jobs': completed_jobs,
            # Subscriptions & Revenue
            'active_subscribers': active_subscribers,
            'trialing_subscribers': trialing_subscribers,
            'cancelled_subscribers': cancelled_subscribers,
            'sub_price': sub_price,
            'estimated_mrr_bdt': estimated_mrr_bdt,
            # Flashcards & Retention
            'total_flashcards': total_flashcards,
            'total_reviews': total_reviews,
            'mastered_reviews': mastered_reviews,
            'mastery_rate': mastery_rate,
            # Spaces
            'total_reading_spaces': total_reading_spaces,
            'public_spaces': public_spaces,
            # Daily Digest
            'digest_completions_today': digest_completions_today,
        },
        'today_digest': today_digest,
        'today_pick': today_pick,
        'recent_activities': recent_activities,
        'recent_highlights': recent_highlights,
        'trending_searches': trending_searches,
    })
    return context
