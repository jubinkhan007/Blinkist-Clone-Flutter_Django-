import json
import os

from django import forms
from django.conf import settings
from django.contrib import admin, messages
from django.core.files import File
from django.db.models import Count
from django.shortcuts import redirect, render
from django.urls import path, reverse
from django.utils.html import format_html
from django.utils.safestring import mark_safe

from unfold.admin import ModelAdmin, StackedInline, TabularInline
from unfold.decorators import action, display

from apps.summaries.models import SummarySection

from .models import (
    Author,
    Book,
    Category,
    Collection,
    CollectionItem,
    ContentIngestionJob,
    DailyPick,
    SearchQueryLog,
    UserAudioQueueItem,
    UserLibraryItem,
    UserReadingList,
    UserReadingListItem,
)


class SummarySectionInline(StackedInline):
    model = SummarySection
    extra = 0
    fields = (
        'order',
        'title',
        'slug',
        'content',
        'plain_text',
        'audio_file',
        'duration_seconds',
        'estimated_read_minutes',
    )
    prepopulated_fields = {'slug': ('title',)}
    ordering = ('order',)
    show_change_link = True


class JsonImportForm(forms.Form):
    json_file = forms.FileField(
        label='Narration JSON file',
        help_text='Upload the <code>*_narration_with_audio.json</code> file. '
                  'Audio files are linked automatically if they already exist '
                  'inside <code>MEDIA_ROOT</code> at the path listed in the JSON.',
    )
    overwrite_sections = forms.BooleanField(
        required=False,
        initial=True,
        label='Replace existing sections',
        help_text='If the book already exists, delete all its sections and '
                  're-import them from the JSON. Uncheck to skip books that '
                  'already have sections.',
    )


@admin.register(ContentIngestionJob)
class ContentIngestionJobAdmin(ModelAdmin):
    list_display = ('id', 'book_title', 'status_badge', 'created_at')
    list_filter = ('status', 'created_at')
    search_fields = ('book__title',)
    readonly_fields = ('status', 'book', 'logs', 'created_at', 'updated_at')

    @display(description='Book')
    def book_title(self, obj):
        return obj.book.title if obj.book else '-'

    @display(
        description='Status',
        label={
            'PENDING': 'warning',
            'PROCESSING': 'info',
            'COMPLETED': 'success',
            'FAILED': 'danger',
        },
    )
    def status_badge(self, obj):
        return obj.status

    def save_model(self, request, obj, form, change):
        if not change:
            obj.status = 'PENDING'
        super().save_model(request, obj, form, change)


@admin.register(DailyPick)
class DailyPickAdmin(ModelAdmin):
    list_display = ('date', 'book_thumbnail', 'book', 'created_at')
    list_filter = ('date',)
    date_hierarchy = 'date'
    raw_id_fields = ('book',)
    search_fields = ('book__title', 'book__author__name')

    @display(description='Cover')
    def book_thumbnail(self, obj):
        if obj.book and obj.book.cover_image:
            return format_html(
                '<img src="{}" style="width: 32px; height: 44px; object-fit: cover; border-radius: 6px; box-shadow: 0 1px 3px rgba(0,0,0,0.15);" />',
                obj.book.cover_image.url,
            )
        return format_html('<span style="color: #9ca3af; font-size: 11px;">No cover</span>')


@admin.register(Category)
class CategoryAdmin(ModelAdmin):
    list_display = ('name', 'slug', 'books_count')
    prepopulated_fields = {'slug': ('name',)}
    search_fields = ('name',)

    @display(description='Books')
    def books_count(self, obj):
        count = obj.books.count()
        url = reverse('admin:catalog_book_changelist') + f'?categories__id__exact={obj.id}'
        return format_html(
            '<a href="{}" style="font-weight: 600; color: #00A86B;">{} books</a>',
            url,
            count,
        )


@admin.register(Author)
class AuthorAdmin(ModelAdmin):
    list_display = ('name', 'books_count')
    search_fields = ('name',)

    @display(description='Books')
    def books_count(self, obj):
        count = obj.books.count()
        url = reverse('admin:catalog_book_changelist') + f'?author__id__exact={obj.id}'
        return format_html(
            '<a href="{}" style="font-weight: 600; color: #00A86B;">{} books</a>',
            url,
            count,
        )


@admin.register(Book)
class BookAdmin(ModelAdmin):
    list_display = (
        'cover_thumbnail',
        'title',
        'author',
        'categories_list',
        'section_count',
        'audio_status',
        'access_badge',
        'created_at',
    )
    list_filter = ('is_premium', 'categories', 'created_at')
    search_fields = ('title', 'subtitle', 'author__name')
    prepopulated_fields = {'slug': ('title',)}
    filter_horizontal = ('categories',)
    inlines = [SummarySectionInline]
    actions = ['make_premium', 'make_free']
    actions_list = ['import_json_action']

    fieldsets = (
        (None, {
            'fields': (
                'title',
                'subtitle',
                'slug',
                'author',
                'categories',
                'cover_image',
                'is_premium',
            )
        }),
        ('Content & Metadata', {
            'fields': (
                'description',
                'what_you_will_learn',
                'estimated_read_time_minutes',
            )
        }),
        ('Full Book Source', {
            'fields': ('full_book_pdf', 'full_text'),
            'classes': ('collapse',),
            'description': 'Upload a PDF for the best reading experience, or paste full text as fallback.',
        }),
    )

    # ── Display Methods ───────────────────────────────────────────────────────

    @display(description='Cover')
    def cover_thumbnail(self, obj):
        if obj.cover_image:
            return format_html(
                '<img src="{}" style="width: 36px; height: 50px; object-fit: cover; border-radius: 6px; box-shadow: 0 2px 4px rgba(0,0,0,0.12);" />',
                obj.cover_image.url,
            )
        return format_html(
            '<div style="width: 36px; height: 50px; border-radius: 6px; background: #f3f4f6; display: flex; align-items: center; justify-content: center; font-size: 10px; color: #9ca3af;">N/A</div>'
        )

    @display(description='Categories')
    def categories_list(self, obj):
        cats = [c.name for c in obj.categories.all()[:2]]
        if not cats:
            return '-'
        return ', '.join(cats)

    @display(description='Sections')
    def section_count(self, obj):
        return obj.sections.count()

    @display(
        description='Audio',
        label={
            'Complete': 'success',
            'Partial': 'warning',
            'None': 'danger',
        },
    )
    def audio_status(self, obj):
        total = obj.sections.count()
        if total == 0:
            return 'None'
        audio_count = obj.sections.exclude(audio_file='').exclude(audio_file__isnull=True).count()
        if audio_count == total:
            return 'Complete'
        elif audio_count > 0:
            return 'Partial'
        return 'None'

    @display(
        description='Access',
        label={
            'PRO': 'warning',
            'FREE': 'success',
        },
    )
    def access_badge(self, obj):
        return 'PRO' if obj.is_premium else 'FREE'

    # ── Actions ───────────────────────────────────────────────────────────────

    @action(description='Import from JSON', url_path='import-json', icon='upload_file')
    def import_json_action(self, request):
        return redirect('admin:catalog_book_import_json')

    def make_premium(self, request, queryset):
        updated = queryset.update(is_premium=True)
        self.message_user(request, f'{updated} books marked as Premium.', messages.SUCCESS)
    make_premium.short_description = 'Mark selected books as Premium'

    def make_free(self, request, queryset):
        updated = queryset.update(is_premium=False)
        self.message_user(request, f'{updated} books marked as Free.', messages.SUCCESS)
    make_free.short_description = 'Mark selected books as Free'

    # ── Custom URLs ───────────────────────────────────────────────────────────

    def get_urls(self):
        custom = [
            path(
                'import-json/',
                self.admin_site.admin_view(self.import_json_view),
                name='catalog_book_import_json',
            ),
        ]
        return custom + super().get_urls()

    # ── Import view & logic ───────────────────────────────────────────────────

    def import_json_view(self, request):
        if request.method == 'POST':
            form = JsonImportForm(request.POST, request.FILES)
            if form.is_valid():
                try:
                    result = self._process_import(
                        request.FILES['json_file'],
                        overwrite=form.cleaned_data['overwrite_sections'],
                    )
                    messages.success(request, result)
                    return redirect('admin:catalog_book_changelist')
                except Exception as exc:
                    messages.error(request, f'Import failed: {exc}')
        else:
            form = JsonImportForm()

        context = {
            **self.admin_site.each_context(request),
            'title': 'Import book from JSON',
            'form': form,
            'opts': self.model._meta,
        }
        return render(request, 'admin/catalog/book/import_json.html', context)

    def _process_import(self, json_file, overwrite: bool) -> str:
        data = json.loads(json_file.read().decode('utf-8'))

        book_data = data['book']
        overview = data.get('overview')
        chapters = data.get('chapters', [])

        author, _ = Author.objects.get_or_create(
            name=book_data['author'],
            defaults={'bio': ''},
        )

        book, created = Book.objects.update_or_create(
            slug=book_data['slug'],
            defaults={
                'title': book_data['title'],
                'subtitle': book_data.get('subtitle', ''),
                'author': author,
                'description': book_data.get('description', ''),
                'is_premium': book_data.get('is_premium', False),
            },
        )

        existing_sections = book.sections.count()
        if existing_sections and not overwrite:
            return (
                f'Skipped "{book.title}" — already has {existing_sections} sections. '
                'Enable "Replace existing sections" to re-import.'
            )

        if overwrite:
            book.sections.all().delete()

        sections_to_create = []
        if overview:
            sections_to_create.append({
                'order': 0,
                'slug': 'overview',
                'title': overview.get('title', 'Overview'),
                'text': overview.get('text', ''),
                'audio_asset': overview.get('audio_asset', ''),
            })
        for ch in chapters:
            sections_to_create.append({
                'order': ch['order'],
                'slug': ch['slug'],
                'title': ch['title'],
                'text': ch.get('text', ''),
                'audio_asset': ch.get('audio_asset', ''),
            })

        created_count = 0
        audio_linked = 0
        for sec in sections_to_create:
            section = SummarySection(
                book=book,
                order=sec['order'],
                slug=sec['slug'],
                title=sec['title'],
                content=sec['text'],
                plain_text=sec['text'],
            )

            audio_path = sec['audio_asset']
            if audio_path:
                abs_path = os.path.join(settings.MEDIA_ROOT, audio_path)
                if os.path.isfile(abs_path):
                    with open(abs_path, 'rb') as f:
                        section.audio_file.save(
                            os.path.basename(abs_path),
                            File(f),
                            save=False,
                        )
                    audio_linked += 1

            section.save()
            created_count += 1

        verb = 'Created' if created else 'Updated'
        return (
            f'{verb} "{book.title}" with {created_count} sections '
            f'({audio_linked} audio files linked).'
        )


class CollectionItemInline(TabularInline):
    model = CollectionItem
    extra = 1
    raw_id_fields = ('book',)
    fields = ('order', 'book', 'note')
    ordering = ('order',)


@admin.register(Collection)
class CollectionAdmin(ModelAdmin):
    list_display = (
        'title',
        'slug',
        'books_count_display',
        'target_duration_days',
        'featured_badge',
        'order',
        'created_at',
    )
    list_filter = ('is_featured', 'created_at')
    search_fields = ('title', 'subtitle', 'description')
    prepopulated_fields = {'slug': ('title',)}
    inlines = [CollectionItemInline]

    @display(description='Books')
    def books_count_display(self, obj):
        return f'{obj.books_count} books'

    @display(
        description='Featured',
        label={
            'Featured': 'success',
            'Standard': 'info',
        },
    )
    def featured_badge(self, obj):
        return 'Featured' if obj.is_featured else 'Standard'


@admin.register(UserLibraryItem)
class UserLibraryItemAdmin(ModelAdmin):
    list_display = ('user', 'book', 'saved_at')
    list_filter = ('saved_at',)
    search_fields = ('user__email', 'book__title')
    raw_id_fields = ('user', 'book')
    ordering = ('-saved_at',)


@admin.register(UserAudioQueueItem)
class UserAudioQueueItemAdmin(ModelAdmin):
    list_display = ('user', 'book', 'order', 'added_at')
    list_filter = ('added_at',)
    search_fields = ('user__email', 'book__title')
    raw_id_fields = ('user', 'book')
    ordering = ('user', 'order')


@admin.register(SearchQueryLog)
class SearchQueryLogAdmin(ModelAdmin):
    list_display = ('query', 'search_count', 'last_searched_at')
    search_fields = ('query',)
    ordering = ('-count', '-last_searched_at')

    @display(description='Queries', ordering='count')
    def search_count(self, obj):
        return format_html(
            '<span style="display: inline-block; padding: 2px 8px; border-radius: 12px; background: #ecfdf5; color: #047857; font-weight: 600; font-size: 11px;">{} searches</span>',
            obj.count,
        )


class UserReadingListItemInline(TabularInline):
    model = UserReadingListItem
    extra = 0
    raw_id_fields = ('book',)
    fields = ('order', 'book', 'note', 'added_at')
    readonly_fields = ('added_at',)
    ordering = ('order',)


@admin.register(UserReadingList)
class UserReadingListAdmin(ModelAdmin):
    list_display = (
        'emoji_title',
        'user',
        'color_badge',
        'books_count',
        'is_public_badge',
        'created_at',
        'updated_at',
    )
    list_filter = ('is_public', 'created_at', 'updated_at')
    search_fields = ('title', 'description', 'user__email', 'user__username')
    raw_id_fields = ('user',)
    inlines = [UserReadingListItemInline]
    readonly_fields = ('share_token', 'created_at', 'updated_at')

    @display(description='Space Title')
    def emoji_title(self, obj):
        return f"{obj.emoji} {obj.title}"

    @display(description='Accent')
    def color_badge(self, obj):
        return format_html(
            '<span style="display: inline-block; width: 14px; height: 14px; border-radius: 50%; background-color: {}; vertical-align: middle; margin-right: 4px;"></span> {}',
            obj.color_hex,
            obj.color_hex,
        )

    @display(description='Books')
    def books_count(self, obj):
        count = obj.items.count()
        return format_html(
            '<span style="display: inline-block; padding: 2px 8px; border-radius: 12px; background: #eff6ff; color: #1d4ed8; font-weight: 600; font-size: 11px;">📚 {} books</span>',
            count,
        )

    @display(description='Access')
    def is_public_badge(self, obj):
        if obj.is_public:
            return format_html(
                '<span style="display: inline-block; padding: 2px 8px; border-radius: 12px; background: #ecfdf5; color: #047857; font-weight: 600; font-size: 11px;">🌐 Public</span>'
            )
        return format_html(
            '<span style="display: inline-block; padding: 2px 8px; border-radius: 12px; background: #f3f4f6; color: #4b5563; font-weight: 600; font-size: 11px;">🔒 Private</span>'
        )


@admin.register(UserReadingListItem)
class UserReadingListItemAdmin(ModelAdmin):
    list_display = ('reading_list', 'order', 'book', 'note', 'added_at')
    list_filter = ('added_at',)
    search_fields = ('reading_list__title', 'book__title', 'note')
    raw_id_fields = ('reading_list', 'book')
    ordering = ('reading_list', 'order')
