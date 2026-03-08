from django.contrib import admin
from .models import Category, Author, Book

@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = ('name', 'slug')
    prepopulated_fields = {'slug': ('name',)}
    search_fields = ('name',)

@admin.register(Author)
class AuthorAdmin(admin.ModelAdmin):
    list_display = ('name',)
    search_fields = ('name',)

@admin.register(Book)
class BookAdmin(admin.ModelAdmin):
    list_display = ('title', 'author', 'is_premium', 'created_at')
    list_filter = ('is_premium', 'categories')
    search_fields = ('title', 'subtitle', 'author__name')
    prepopulated_fields = {'slug': ('title',)}
    filter_horizontal = ('categories',)

