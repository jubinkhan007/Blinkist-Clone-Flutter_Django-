from django.contrib.auth.models import AbstractUser
from django.db import models

class User(AbstractUser):
    """
    Custom User model for Blinkist-style app.
    Uses email as the primary identifier instead of username.
    """
    email = models.EmailField(unique=True)
    is_premium = models.BooleanField(default=False)
    
    # Optional fields for profile
    bio = models.TextField(blank=True, null=True)
    avatar_url = models.URLField(blank=True, null=True)

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['username']

    def __str__(self):
        return self.email
