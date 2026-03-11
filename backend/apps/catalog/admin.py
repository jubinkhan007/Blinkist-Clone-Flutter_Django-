import json
import os

from django import forms
from django.conf import settings
from django.contrib import admin, messages
from django.core.files import File
from django.shortcuts import redirect, render
from django.urls import path

from apps.summaries.models import SummarySection

from .models import Author, Book, Category


class SummarySectionInline(admin.StackedInline):
    model = SummarySection
    extra = 1
    fields = ('order', 'title', 'slug', 'content', 'plain_text',
              'audio_file', 'duration_seconds', 'estimated_read_minutes')
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
    change_list_template = 'admin/catalog/book/change_list.html'
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

    # ── Custom URLs ───────────────────────────────────────────────────────────

    def get_urls(self):
        custom = [
            path('import-json/', self.admin_site.admin_view(self.import_json_view),
                 name='catalog_book_import_json'),
        ]
        return custom + super().get_urls()

    # ── Import view ───────────────────────────────────────────────────────────

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

    # ── Import logic ──────────────────────────────────────────────────────────

    def _process_import(self, json_file, overwrite: bool) -> str:
        data = json.loads(json_file.read().decode('utf-8'))

        book_data = data['book']
        overview = data.get('overview')
        chapters = data.get('chapters', [])

        # Author
        author, _ = Author.objects.get_or_create(
            name=book_data['author'],
            defaults={'bio': ''},
        )

        # Book (create or update)
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

        # Build section list: overview first, then chapters
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

            # Link audio file if it already exists in MEDIA_ROOT
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

    @admin.display(description='Sections')
    def section_count(self, obj):
        return obj.sections.count()
