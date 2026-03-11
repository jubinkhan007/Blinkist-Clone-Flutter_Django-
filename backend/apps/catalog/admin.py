from django.contrib import admin
from .models import Category, Author, Book
from apps.summaries.models import SummarySection


class SummarySectionInline(admin.StackedInline):
    model = SummarySection
    extra = 1
    fields = ('order', 'title', 'slug', 'content', 'plain_text',
              'audio_file', 'duration_seconds', 'estimated_read_minutes')
    prepopulated_fields = {'slug': ('title',)}
    ordering = ('order',)
    show_change_link = True


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
    list_display = ('title', 'author', 'section_count', 'is_premium', 'created_at')
    list_filter = ('is_premium', 'categories')
    search_fields = ('title', 'subtitle', 'author__name')
    prepopulated_fields = {'slug': ('title',)}
    filter_horizontal = ('categories',)
    inlines = [SummarySectionInline]
    fieldsets = (
        (None, {
            'fields': ('title', 'subtitle', 'slug', 'author', 'categories',
                       'cover_image', 'is_premium')
        }),
        ('Content', {
            'fields': ('description', 'what_you_will_learn',
                       'estimated_read_time_minutes')
        }),
        ('Full Book', {
            'fields': ('full_book_pdf', 'full_text'),
            'classes': ('collapse',),
            'description': 'Upload a PDF for the best reading experience. '
                           'Paste plain text as a fallback if no PDF is available.',
        }),
    )

    @admin.display(description='Sections')
    def section_count(self, obj):
        return obj.sections.count()

