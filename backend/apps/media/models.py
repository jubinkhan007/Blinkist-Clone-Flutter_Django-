import uuid
from django.db import models
from django.utils import timezone
from apps.accounts.models import User
from apps.catalog.models import Book
from apps.summaries.models import SummarySection


class DailyAudioDigest(models.Model):
    """
    A curated daily 3-insight audio brief stitched from 3 different books.
    Can be generated for a specific date as a universal default or personalized for a user.
    """
    date = models.DateField(db_index=True, default=timezone.now)
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='daily_digests',
        help_text="Null for universal daily default, set for personalized user digests.",
    )
    title = models.CharField(max_length=200, default="Daily Blink • Morning Digest")
    subtitle = models.CharField(
        max_length=255,
        default="3 key insights to power your morning",
    )
    theme = models.CharField(
        max_length=150,
        default="Focus, Habits & Mental Agility",
    )
    total_duration_seconds = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-date', '-created_at']
        indexes = [
            models.Index(fields=['date', 'user']),
        ]

    def __str__(self):
        user_str = f" ({self.user.email})" if self.user else " (Universal)"
        return f"{self.date} - {self.title}{user_str}"

    @property
    def formatted_duration(self) -> str:
        mins = self.total_duration_seconds // 60
        secs = self.total_duration_seconds % 60
        if secs > 0:
            return f"{mins}m {secs}s"
        return f"{mins} min"


class DailyAudioDigestItem(models.Model):
    """
    An individual track insight inside a daily audio digest.
    """
    digest = models.ForeignKey(
        DailyAudioDigest,
        on_delete=models.CASCADE,
        related_name='items',
    )
    book = models.ForeignKey(
        Book,
        on_delete=models.CASCADE,
        related_name='in_daily_digests',
    )
    section = models.ForeignKey(
        SummarySection,
        on_delete=models.CASCADE,
        related_name='in_daily_digest_items',
    )
    order = models.PositiveIntegerField(default=1)
    insight_prompt = models.CharField(
        max_length=255,
        default="Key Insight",
        help_text="Short headline connecting this insight to the daily theme.",
    )

    class Meta:
        ordering = ['order']
        unique_together = ('digest', 'order')

    def __str__(self):
        return f"{self.digest.date} Item #{self.order}: {self.book.title} ({self.section.title})"


class UserDailyDigestProgress(models.Model):
    """
    Tracks a user's listening status on a daily audio digest.
    """
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='daily_digest_progress',
    )
    digest = models.ForeignKey(
        DailyAudioDigest,
        on_delete=models.CASCADE,
        related_name='user_progress',
    )
    is_completed = models.BooleanField(default=False)
    current_item_index = models.PositiveIntegerField(default=0)
    current_position_seconds = models.PositiveIntegerField(default=0)
    completed_at = models.DateTimeField(null=True, blank=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-updated_at']
        unique_together = ('user', 'digest')

    def __str__(self):
        status = "Completed" if self.is_completed else f"Track {self.current_item_index + 1}"
        return f"{self.user.email} - {self.digest.date}: {status}"
