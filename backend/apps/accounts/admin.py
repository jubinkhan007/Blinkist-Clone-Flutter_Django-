from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import User

class CustomUserAdmin(UserAdmin):
    model = User
    list_display = ['email', 'username', 'is_premium', 'is_staff', 'is_active']
    fieldsets = UserAdmin.fieldsets + (
        ('Custom Profile Info', {'fields': ('is_premium', 'bio', 'avatar_url')}),
    )

admin.site.register(User, CustomUserAdmin)
