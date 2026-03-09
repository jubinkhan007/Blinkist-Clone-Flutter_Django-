from django.db import models
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
    full_text = models.TextField(blank=True, help_text="Complete book text for the Full Book reader")
    
    estimated_read_time_minutes = models.PositiveIntegerField(default=15)
    is_premium = models.BooleanField(default=False)
    
    # Metadata
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    def __str__(self):
        return self.title
