from django.db import models
from apps.accounts.models import User
from apps.catalog.models import Book

class SummarySection(models.Model):
    book = models.ForeignKey(Book, on_delete=models.CASCADE, related_name='sections')
    slug = models.SlugField(max_length=255)
    order = models.PositiveIntegerField()
    title = models.CharField(max_length=255)
    
    content = models.TextField(help_text="Markdown or HTML content")
    plain_text = models.TextField(help_text="Plain text for search, indexing, and TTS fallback", blank=True)
    
    audio_file = models.FileField(upload_to='books/audio/', blank=True, null=True)
    duration_seconds = models.PositiveIntegerField(default=0)
    estimated_read_minutes = models.PositiveIntegerField(default=2)

    class Meta:
        ordering = ['order']
        unique_together = ('book', 'slug')

    def __str__(self):
        return f"{self.book.title} - {self.order}. {self.title}"


class UserHighlight(models.Model):
    COLOR_CHOICES = [
        ('yellow', 'Yellow'),
        ('green', 'Green'),
        ('blue', 'Blue'),
        ('pink', 'Pink'),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='highlights')
    book = models.ForeignKey(Book, on_delete=models.CASCADE, related_name='highlights')
    section = models.ForeignKey(SummarySection, on_delete=models.CASCADE, related_name='highlights', null=True, blank=True)
    selected_text = models.TextField()
    note = models.TextField(blank=True, default='')
    color = models.CharField(max_length=20, choices=COLOR_CHOICES, default='yellow')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.user.email} - {self.book.title}: {self.selected_text[:30]}"
