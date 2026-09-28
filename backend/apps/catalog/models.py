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
