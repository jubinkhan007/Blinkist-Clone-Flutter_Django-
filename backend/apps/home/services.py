from collections import Counter

from django.core.cache import cache
from django.db.models import Count, QuerySet

from apps.catalog.models import Book
from apps.catalog.daily_pick import get_or_create_daily_pick
from apps.progress.models import UserAudioProgress, UserSummaryProgress
from apps.catalog.recommendation_service import query_similar_books, get_book_embedding

HOME_FEED_CACHE_TTL_SECONDS = 300


def build_continue_reading_for_user(user):
    if user is None or not getattr(user, 'is_authenticated', False):
        return []

    summary_progress = (
        UserSummaryProgress.objects.filter(user=user)
        .select_related('book', 'current_section', 'book__author')
        .prefetch_related('book__categories')
        .annotate(section_total=Count('book__sections'))
    )
    audio_progress = (
        UserAudioProgress.objects.filter(user=user)
        .select_related('book', 'current_section', 'book__author')
        .prefetch_related('book__categories')
        .annotate(section_total=Count('book__sections'))
    )

    items_by_book_id = {}

    for progress in summary_progress:
        total = progress.section_total or progress.book.sections.count() or 1
        percent_complete = min(
            100.0,
            (progress.completed_sections_count / total) * 100.0,
        )
        items_by_book_id[progress.book_id] = {
            'id': progress.book.id,
            'title': progress.book.title,
            'subtitle': progress.book.subtitle,
            'slug': progress.book.slug,
            'author': progress.book.author,
            'categories': progress.book.categories.all(),
            'cover_image': progress.book.cover_image,
            'estimated_read_time_minutes': progress.book.estimated_read_time_minutes,
            'is_premium': progress.book.is_premium,
            'percent_complete': round(percent_complete, 2),
            'last_read_at': progress.last_read_at,
            'current_section_title': getattr(progress.current_section, 'title', None),
            'last_mode': 'read',
            'is_saved': user.library_items.filter(book_id=progress.book_id).exists(),
        }

    for progress in audio_progress:
        total = progress.section_total or progress.book.sections.count() or 1
        current_order = getattr(progress.current_section, 'order', 0)
        percent_complete = (
            100.0
            if progress.is_finished
            else min(100.0, (current_order / total) * 100.0)
        )
        existing = items_by_book_id.get(progress.book_id)
        if existing and existing['last_read_at'] >= progress.last_listened_at:
            continue

        items_by_book_id[progress.book_id] = {
            'id': progress.book.id,
            'title': progress.book.title,
            'subtitle': progress.book.subtitle,
            'slug': progress.book.slug,
            'author': progress.book.author,
            'categories': progress.book.categories.all(),
            'cover_image': progress.book.cover_image,
            'estimated_read_time_minutes': progress.book.estimated_read_time_minutes,
            'is_premium': progress.book.is_premium,
            'percent_complete': round(percent_complete, 2),
            'last_read_at': progress.last_listened_at,
            'current_section_title': getattr(progress.current_section, 'title', None),
            'last_mode': 'listen',
            'is_saved': user.library_items.filter(book_id=progress.book_id).exists(),
        }

    items = sorted(
        items_by_book_id.values(),
        key=lambda item: item['last_read_at'],
        reverse=True,
    )
    return items[:5]


def get_home_feed_for_user(user):
    daily_pick_obj = get_or_create_daily_pick()
    daily_pick_book = daily_pick_obj.book if daily_pick_obj else None

    if user is None or not getattr(user, 'is_authenticated', False):
        return {
            'daily_pick': daily_pick_book,
            'featured': Book.objects.filter(is_premium=True).order_by('-created_at')[:5],
            'recently_added': Book.objects.order_by('-created_at')[:10],
            'recommended': Book.objects.order_by('-created_at')[:10],
            'continue_reading': [],
        }

    cache_key = f'home_feed_{user.id}'
    cached = cache.get(cache_key)
    if cached is not None:
        return cached

    continue_reading = build_continue_reading_for_user(user)
    continue_book_ids = [item['id'] for item in continue_reading]

    featured: QuerySet[Book] = (
        Book.objects.filter(is_premium=True)
        .exclude(id__in=continue_book_ids)
        .order_by('-created_at')[:5]
    )
    recently_added: QuerySet[Book] = Book.objects.order_by('-created_at')[:10]

    # --- AI Recommendation Logic ---
    recommended = []
    
    # Try to get the last book the user interacted with to find similar ones
    last_interaction = UserSummaryProgress.objects.filter(user=user).order_by('-last_read_at').first()
    if not last_interaction:
        last_interaction = UserAudioProgress.objects.filter(user=user).order_by('-last_listened_at').first()
    
    if last_interaction:
        book = last_interaction.book
        text_to_embed = f"{book.title} {book.subtitle} {book.description}"
        vector = get_book_embedding(text_to_embed)
        if vector:
            similar_ids = query_similar_books(vector, top_k=12)
            # Filter out already read books
            similar_ids = [bid for bid in similar_ids if bid not in continue_book_ids]
            recommended = Book.objects.filter(id__in=similar_ids[:10])
    
    # Fallback to reading history categories, onboarding interest categories, or latest
    if not recommended:
        category_counts = Counter(
            UserSummaryProgress.objects.filter(user=user)
            .values_list('book__categories__id', flat=True)
        )
        preferred_category_ids = [
            category_id
            for category_id, _ in category_counts.most_common()
            if category_id is not None
        ]

        if preferred_category_ids:
            recommended = (
                Book.objects.filter(categories__id__in=preferred_category_ids)
                .exclude(id__in=continue_book_ids)
                .distinct()
                .order_by('-created_at')[:10]
            )
        elif getattr(user, 'interest_categories', None) and user.interest_categories.exists():
            recommended = (
                Book.objects.filter(categories__in=user.interest_categories.all())
                .exclude(id__in=continue_book_ids)
                .distinct()
                .order_by('-created_at')[:10]
            )
        elif getattr(user, 'interest_topics', None) and user.interest_topics:
            recommended = (
                Book.objects.filter(categories__slug__in=user.interest_topics)
                .exclude(id__in=continue_book_ids)
                .distinct()
                .order_by('-created_at')[:10]
            )
        else:
            recommended = (
                Book.objects.exclude(id__in=continue_book_ids)
                .order_by('-created_at')[:10]
            )

    # Ensure recommended rail is populated if catalog allows
    if not recommended:
        recommended = Book.objects.order_by('-created_at')[:10]

    payload = {
        'daily_pick': daily_pick_book,
        'featured': featured,
        'recently_added': recently_added,
        'recommended': recommended,
        'continue_reading': continue_reading,
    }
    cache.set(cache_key, payload, HOME_FEED_CACHE_TTL_SECONDS)
    return payload
