import logging
from datetime import date as dt_date
from django.utils import timezone
from apps.catalog.models import Book, DailyPick

logger = logging.getLogger(__name__)


def get_or_create_daily_pick(target_date: dt_date = None) -> DailyPick:
    """
    Returns the DailyPick for the specified date (defaults to today in UTC).
    If an administrator hasn't explicitly selected one, deterministically
    assigns a book so all users see the identical daily pick.
    """
    if target_date is None:
        target_date = timezone.now().date()

    existing = (
        DailyPick.objects.filter(date=target_date)
        .select_related('book', 'book__author')
        .prefetch_related('book__categories')
        .first()
    )
    if existing:
        return existing

    # Prefer premium books for the daily free pick (core Blinkist model)
    books = list(Book.objects.filter(is_premium=True).order_by('id'))
    if not books:
        books = list(Book.objects.all().order_by('id'))

    if not books:
        logger.warning("No books in catalog to assign as DailyPick.")
        return None

    # Deterministic rotation based on day number
    index = target_date.toordinal() % len(books)
    selected_book = books[index]

    daily_pick, _ = DailyPick.objects.get_or_create(
        date=target_date,
        defaults={'book': selected_book},
    )
    return daily_pick
