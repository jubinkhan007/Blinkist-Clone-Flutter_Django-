from django.contrib.auth.models import AbstractUser
from django.db import models
from django.utils import timezone
from datetime import timedelta
import math

class User(AbstractUser):
    """
    Custom User model for Blinkist-style app.
    Uses email as the primary identifier instead of username.
    """
    email = models.EmailField(unique=True)
    is_premium = models.BooleanField(default=False)

    class SubscriptionStatus(models.TextChoices):
        TRIALING = "trialing", "Trialing"
        ACTIVE = "active", "Active"
        EXPIRED = "expired", "Expired"
        CANCELLED = "cancelled", "Cancelled"

    trial_started_at = models.DateTimeField(blank=True, null=True)
    subscription_status = models.CharField(
        max_length=20,
        choices=SubscriptionStatus.choices,
        default=SubscriptionStatus.TRIALING,
    )
    subscription_end_date = models.DateTimeField(blank=True, null=True)
    sslcommerz_tran_id = models.CharField(max_length=128, blank=True, null=True)
    
    # Optional fields for profile
    bio = models.TextField(blank=True, null=True)
    avatar_url = models.URLField(blank=True, null=True)

    # Streak & Gamification fields
    current_streak = models.PositiveIntegerField(default=0)
    longest_streak = models.PositiveIntegerField(default=0)
    last_active_date = models.DateField(blank=True, null=True)

    # Onboarding & Personalization fields
    has_completed_onboarding = models.BooleanField(default=False)
    reading_goal = models.CharField(max_length=50, blank=True, default='')
    preferred_format = models.CharField(max_length=20, blank=True, default='both')
    interest_topics = models.JSONField(default=list, blank=True)
    interest_categories = models.ManyToManyField('catalog.Category', blank=True, related_name='interested_users')

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['username']

    def has_premium_access(self) -> bool:
        """
        Premium access is granted if:
        - User is manually premium (is_premium=True), OR
        - subscription_status is active and not expired, OR
        - subscription_status is trialing and trial is within 7 days.
        """
        if self.is_premium:
            return True

        now = timezone.now()

        if self.subscription_status == self.SubscriptionStatus.ACTIVE:
            if self.subscription_end_date is None:
                return True
            return now < self.subscription_end_date

        if (
            self.subscription_status == self.SubscriptionStatus.TRIALING
            and self.trial_started_at is not None
        ):
            return now < self.trial_started_at + timedelta(days=7)

        return False

    def trial_days_remaining(self) -> int:
        if self.trial_started_at is None:
            return 0

        trial_end = self.trial_started_at + timedelta(days=7)
        seconds = (trial_end - timezone.now()).total_seconds()
        if seconds <= 0:
            return 0
        return int(math.ceil(seconds / 86400))

    def get_current_streak(self, today=None) -> int:
        """
        Calculates the active streak.
        If user missed reading yesterday and has not yet read today, streak is 0.
        """
        if today is None:
            today = timezone.localdate()

        if not self.last_active_date:
            return 0

        if self.last_active_date < today - timedelta(days=1):
            return 0

        return self.current_streak

    def record_reading_activity(self, today=None) -> bool:
        """
        Records reading activity for the user.
        Updates current_streak and longest_streak idempotently for today.
        Returns True if a new day's activity was recorded, False if already recorded today.
        """
        if today is None:
            today = timezone.localdate()

        if self.last_active_date == today:
            return False

        if self.last_active_date == today - timedelta(days=1):
            self.current_streak += 1
        else:
            self.current_streak = 1

        if self.current_streak > self.longest_streak:
            self.longest_streak = self.current_streak

        self.last_active_date = today
        self.save(update_fields=['current_streak', 'longest_streak', 'last_active_date'])
        return True

    def __str__(self):
        return self.email
