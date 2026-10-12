from __future__ import annotations
import logging
from datetime import date
from typing import Optional
from django.db import transaction
from django.utils import timezone
from apps.catalog.models import Book
from apps.summaries.models import SummarySection
from .models import DailyAudioDigest, DailyAudioDigestItem, UserDailyDigestProgress

logger = logging.getLogger(__name__)

DAILY_THEMES = [
    {
        "theme": "Focus, Habits & Mental Agility",
        "subtitle": "3 transformative ideas to energize your morning",
        "prompts": [
            "Insight 1 • The Architecture of Daily Habits",
            "Insight 2 • De-biasing Your Critical Thinking",
            "Insight 3 • Unlocking Neuroplasticity & Growth",
        ],
    },
    {
        "theme": "High-Performance Leadership & Strategy",
        "subtitle": "Strategic frameworks from world-class leaders",
        "prompts": [
            "Insight 1 • Designing Systems Over Goals",
            "Insight 2 • Navigating High-Stakes Decisions",
            "Insight 3 • Fostering Psychological Safety",
        ],
    },
    {
        "theme": "Clarity of Thought & Deep Work",
        "subtitle": "Cut through noise and elevate cognitive focus",
        "prompts": [
            "Insight 1 • The Compound Effect of Small Wins",
            "Insight 2 • Fast Heuristics vs. Deliberate Logic",
            "Insight 3 • Reframing Failure into Growth",
        ],
    },
    {
        "theme": "Resilience, Health & Peak Energy",
        "subtitle": "Bio-behavioral practices for mental resilience",
        "prompts": [
            "Insight 1 • Behavioral Triggers and Rewards",
            "Insight 2 • Mitigating Overconfidence Biases",
            "Insight 3 • The Resilience of a Growth Mindset",
        ],
    },
    {
        "theme": "Mastering Communication & Influence",
        "subtitle": "Speak with impact and build lasting relationships",
        "prompts": [
            "Insight 1 • Active Listening & Empathetic Framing",
            "Insight 2 • The Psychology of Persuasion",
            "Insight 3 • Cultivating Constructive Feedback",
        ],
    },
]


def _pick_best_section(book: Book) -> SummarySection | None:
    """
    Picks the ideal section with audio for a book.
    Prefers key insight chapters (order >= 1) over introduction/overview (order 0).
    """
    audio_sections = book.sections.filter(
        audio_file__isnull=False
    ).exclude(audio_file='').order_by('order')

    if not audio_sections.exists():
        # Fallback to any section if audio hasn't been uploaded yet
        audio_sections = book.sections.all().order_by('order')

    if not audio_sections.exists():
        return None

    # Prefer non-zero order if available
    non_intro = audio_sections.filter(order__gte=1)
    if non_intro.exists():
        return non_intro.first()
    return audio_sections.first()


@transaction.atomic
def get_or_create_daily_digest(user=None, target_date=None) -> DailyAudioDigest | None:
    """
    Retrieves or generates a Daily Audio Digest for the given date.
    - If user is provided and has custom category interests, creates/returns a personalized digest.
    - Otherwise, creates/returns the universal daily digest.
    """
    if target_date is None:
        target_date = timezone.localdate()

    is_authenticated = bool(user and getattr(user, 'is_authenticated', False))
    has_custom_interests = False

    if is_authenticated:
        try:
            has_custom_interests = user.interest_categories.exists()
        except Exception:
            has_custom_interests = False

        # If user has custom interests, check for personalized digest first
        if has_custom_interests:
            existing = DailyAudioDigest.objects.filter(date=target_date, user=user).first()
            if existing and existing.items.count() > 0:
                return existing

    # Check universal digest for date
    universal = DailyAudioDigest.objects.filter(date=target_date, user=None).first()
    if universal and universal.items.count() > 0 and not has_custom_interests:
        return universal

    # Otherwise we compile a new digest:
    # If user has custom interests, compile personalized; otherwise compile universal.
    digest_user = user if (is_authenticated and has_custom_interests) else None

    # Query candidate books with audio
    audio_books_qs = Book.objects.filter(
        sections__audio_file__isnull=False
    ).exclude(sections__audio_file='').distinct()

    if not audio_books_qs.exists():
        # Fallback to any books with sections
        audio_books_qs = Book.objects.filter(sections__isnull=False).distinct()

    candidates = list(audio_books_qs)
    if not candidates:
        logger.warning("No books available to generate Daily Audio Digest.")
        return None

    # Filter by user interests if personalized
    if digest_user and has_custom_interests:
        interest_cats = digest_user.interest_categories.all()
        pref_books = [b for b in candidates if any(c in interest_cats for c in b.categories.all())]
        if len(pref_books) >= 3:
            candidates = pref_books

    # Deterministic rotation based on date ordinal
    day_num = target_date.toordinal()
    offset = day_num % len(candidates)
    rotated = candidates[offset:] + candidates[:offset]

    # Select up to 3 distinct books
    selected_books = rotated[:3]
    if len(selected_books) < 3 and len(candidates) >= 3:
        selected_books = candidates[:3]

    theme_data = DAILY_THEMES[day_num % len(DAILY_THEMES)]

    digest = DailyAudioDigest.objects.create(
        date=target_date,
        user=digest_user,
        title="Daily Blink • Morning Digest",
        subtitle=theme_data["subtitle"],
        theme=theme_data["theme"],
        total_duration_seconds=0,
    )

    total_duration = 0
    items_created = 0

    for idx, book in enumerate(selected_books):
        section = _pick_best_section(book)
        if not section:
            continue

        prompt = theme_data["prompts"][idx] if idx < len(theme_data["prompts"]) else f"Insight {idx + 1}"
        DailyAudioDigestItem.objects.create(
            digest=digest,
            book=book,
            section=section,
            order=idx + 1,
            insight_prompt=prompt,
        )
        total_duration += section.duration_seconds or 180
        items_created += 1

    digest.total_duration_seconds = total_duration
    digest.save(update_fields=['total_duration_seconds'])

    return digest
