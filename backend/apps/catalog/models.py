from django.db import models
from django.utils import timezone
from apps.accounts.models import User

class Category(models.Model):
    name = models.CharField(max_length=100, unique=True)
    slug = models.SlugField(max_length=100, unique=True)
    description = models.TextField(blank=True)

    class Meta:
        verbose_name_plural = "Categories"

    def __str__(self):
        return self.name


class Author(models.Model):
    name = models.CharField(max_length=255)
    bio = models.TextField(blank=True)
    avatar_url = models.URLField(blank=True, null=True)

    def __str__(self):
        return self.name

class Book(models.Model):
    title = models.CharField(max_length=255)
    subtitle = models.CharField(max_length=255, blank=True)
    slug = models.SlugField(max_length=255, unique=True)
    author = models.ForeignKey(Author, on_delete=models.CASCADE, related_name='books')
    categories = models.ManyToManyField(Category, related_name='books')
    
    cover_image = models.ImageField(upload_to='books/covers/', blank=True, null=True)
    description = models.TextField()
    what_you_will_learn = models.TextField(blank=True)
    full_text = models.TextField(blank=True, help_text="Complete book text for the Full Book reader (fallback if no PDF)")
    full_book_pdf = models.FileField(upload_to='books/pdf/', blank=True, null=True, help_text="Upload the full book as a PDF")
    
    estimated_read_time_minutes = models.PositiveIntegerField(default=15)
    is_premium = models.BooleanField(default=False)
    rating = models.DecimalField(max_digits=3, decimal_places=1, default=4.7)
    rating_count = models.PositiveIntegerField(default=120)
    
    # Metadata
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    def __str__(self):
        return self.title

    @property
    def is_daily_free(self) -> bool:
        today = timezone.now().date()
        return self.daily_picks.filter(date=today).exists()


class ContentIngestionJob(models.Model):
    STATUS_CHOICES = [
        ('PENDING', 'Pending'),
        ('PROCESSING', 'Processing'),
        ('COMPLETED', 'Completed'),
        ('FAILED', 'Failed')
    ]
    
    file = models.FileField(upload_to='raw_books/')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='PENDING')
    book = models.OneToOneField(Book, on_delete=models.SET_NULL, null=True, blank=True)
    logs = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Job {self.id} - {self.status}"


class UserLibraryItem(models.Model):
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='library_items',
    )
    book = models.ForeignKey(
        Book,
        on_delete=models.CASCADE,
        related_name='saved_by',
    )
    saved_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'book')
        ordering = ['-saved_at']

    def __str__(self):
        return f"{self.user.email} saved {self.book.title}"


class UserAudioQueueItem(models.Model):
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='audio_queue',
    )
    book = models.ForeignKey(
        Book,
        on_delete=models.CASCADE,
        related_name='audio_queued_by',
    )
    order = models.PositiveIntegerField(default=0)
    added_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['order', 'added_at']
        unique_together = ('user', 'book')

    def __str__(self):
        return f"{self.user.email} queued {self.book.title} (order: {self.order})"


class DailyPick(models.Model):
    book = models.ForeignKey(
        Book,
        on_delete=models.CASCADE,
        related_name='daily_picks',
    )
    date = models.DateField(unique=True, default=timezone.now)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-date']

    def __str__(self):
        return f"{self.date}: {self.book.title}"


class Collection(models.Model):
    title = models.CharField(max_length=255)
    subtitle = models.CharField(max_length=255, blank=True)
    slug = models.SlugField(max_length=255, unique=True)
    description = models.TextField(blank=True)
    banner_image = models.ImageField(upload_to='collections/banners/', blank=True, null=True)
    icon = models.CharField(max_length=50, blank=True, default='auto_stories')
    color_hex = models.CharField(max_length=7, blank=True, default='#1E3A8A')
    target_duration_days = models.PositiveIntegerField(default=7, help_text="e.g. 7 for a 7-day challenge")
    is_featured = models.BooleanField(default=True)
    order = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['order', '-created_at']

    def __str__(self):
        return self.title

    @property
    def books_count(self) -> int:
        return self.items.count()

    @property
    def total_estimated_minutes(self) -> int:
        return sum(item.book.estimated_read_time_minutes for item in self.items.select_related('book'))


class CollectionItem(models.Model):
    collection = models.ForeignKey(Collection, on_delete=models.CASCADE, related_name='items')
    book = models.ForeignKey(Book, on_delete=models.CASCADE, related_name='collection_items')
    order = models.PositiveIntegerField(default=0)
    note = models.CharField(max_length=255, blank=True, help_text="e.g. 'Day 1: Build the mindset'")

    class Meta:
        unique_together = ('collection', 'book')
        ordering = ['order', 'id']

    def __str__(self):
        return f"{self.collection.title} - #{self.order}: {self.book.title}"


class SearchQueryLog(models.Model):
    query = models.CharField(max_length=255, unique=True, db_index=True)
    count = models.PositiveIntegerField(default=1)
    last_searched_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-count', '-last_searched_at']

    def __str__(self):
        return f"{self.query} ({self.count})"


