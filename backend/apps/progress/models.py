from __future__ import annotations

from django.db import models
from django.conf import settings
from apps.catalog.models import Book
from apps.summaries.models import SummarySection

class UserBookProgress(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='book_progress')
    book = models.ForeignKey(Book, on_delete=models.CASCADE, related_name='user_progress')
    
    current_section = models.ForeignKey(SummarySection, on_delete=models.SET_NULL, null=True, blank=True)
    percent_complete = models.IntegerField(default=0)
    
    last_read_at = models.DateTimeField(auto_now=True)
    is_completed = models.BooleanField(default=False)

    class Meta:
        unique_together = ('user', 'book')
        ordering = ['-last_read_at']

    def __str__(self):
        return f"{self.user.email} - {self.book.title} ({self.percent_complete}%)"


class UserSectionProgress(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='section_progress')
    section = models.ForeignKey(SummarySection, on_delete=models.CASCADE, related_name='user_progress')

    is_completed = models.BooleanField(default=False)
    read_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ('user', 'section')
        verbose_name_plural = "User Section Progresses"

    def __str__(self):
        return f"{self.user.email} - {self.section.title}"


class UserSummaryProgress(models.Model):
    """Tracks read-summary mode progress per book."""
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='summary_progress')
    book = models.ForeignKey(Book, on_delete=models.CASCADE, related_name='user_summary_progress')
    current_section = models.ForeignKey(SummarySection, on_delete=models.SET_NULL, null=True, blank=True)
    completed_sections_count = models.IntegerField(default=0)
    last_read_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ('user', 'book')

    def __str__(self):
        return f"{self.user.email} - {self.book.title} (summary)"


class UserAudioProgress(models.Model):
    """Tracks listen-summary mode progress per book."""
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='audio_progress')
    book = models.ForeignKey(Book, on_delete=models.CASCADE, related_name='user_audio_progress')
    current_section = models.ForeignKey(SummarySection, on_delete=models.SET_NULL, null=True, blank=True)
    current_position_seconds = models.FloatField(default=0.0)
    is_finished = models.BooleanField(default=False)
    last_listened_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ('user', 'book')

    def __str__(self):
        return f"{self.user.email} - {self.book.title} (audio)"


class UserFullBookProgress(models.Model):
    """Tracks full-book reading mode progress per book."""
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='full_book_progress')
    book = models.ForeignKey(Book, on_delete=models.CASCADE, related_name='user_full_book_progress')
    current_page = models.IntegerField(default=0)
    current_offset = models.FloatField(default=0.0)
    last_opened_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ('user', 'book')

    def __str__(self):
        return f"{self.user.email} - {self.book.title} (full book)"


class UserDailyActivity(models.Model):
    """Tracks which days a user was active reading/listening, for habit graphs and streak verification."""
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='daily_activities')
    date = models.DateField(db_index=True)
    reading_minutes = models.PositiveIntegerField(default=0)
    audio_minutes = models.PositiveIntegerField(default=0)
    sections_read = models.PositiveIntegerField(default=0)
    books_completed = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'date')
        ordering = ['-date']

    def __str__(self):
        return f"{self.user.email} - {self.date} (read: {self.reading_minutes}m, audio: {self.audio_minutes}m)"


class UserBadge(models.Model):
    """Tracks achievement milestone badges unlocked by a user."""
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='badges')
    badge_key = models.CharField(max_length=64, db_index=True)
    unlocked_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'badge_key')
        ordering = ['-unlocked_at']

    def __str__(self):
        return f"{self.user.email} - {self.badge_key}"


class ActionPlan(models.Model):
    """
    Action Plan & Micro-Habit Roadmap synthesized from a book's principles,
    incorporating the user's personal highlights and margin notes.
    """
    DURATION_CHOICES = (
        (7, '7-Day Sprint'),
        (14, '14-Day Micro-Habit'),
    )

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='action_plans')
    book = models.ForeignKey(Book, on_delete=models.CASCADE, related_name='action_plans')
    title = models.CharField(max_length=255)
    duration_days = models.PositiveSmallIntegerField(default=7, choices=DURATION_CHOICES)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    completed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.user.email} - {self.title} ({self.duration_days} days)"

    @property
    def total_items_count(self) -> int:
        return self.items.count()

    @property
    def completed_items_count(self) -> int:
        return self.items.filter(is_completed=True).count()

    @property
    def progress_percent(self) -> int:
        total = self.total_items_count
        if total == 0:
            return 0
        return int(round((self.completed_items_count / total) * 100))

    @property
    def is_completed(self) -> bool:
        if self.completed_at:
            return True
        total = self.total_items_count
        return total > 0 and self.completed_items_count >= total


class ActionPlanItem(models.Model):
    """
    Individual daily micro-habit or action step within an ActionPlan.
    """
    plan = models.ForeignKey(ActionPlan, on_delete=models.CASCADE, related_name='items')
    day_number = models.PositiveSmallIntegerField()
    title = models.CharField(max_length=255)
    description = models.TextField()
    suggested_habit = models.CharField(max_length=500)
    associated_quote = models.TextField(blank=True, default='')
    is_completed = models.BooleanField(default=False)
    completed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        unique_together = ('plan', 'day_number')
        ordering = ['day_number']

    def __str__(self):
        return f"Day {self.day_number}: {self.title} (Plan #{self.plan_id})"



