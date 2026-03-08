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
