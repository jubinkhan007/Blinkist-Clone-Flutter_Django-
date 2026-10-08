from django.contrib import admin
from django.utils.html import format_html
from unfold.admin import ModelAdmin
from unfold.decorators import display

from .models import (
    BookFlashcard,
    SummarySection,
    UserAudioBookmark,
    UserFlashcardReview,
    UserHighlight,
)


@admin.register(SummarySection)
class SummarySectionAdmin(ModelAdmin):
    list_display = (
        'book',
        'order',
        'title',
        'audio_player',
        'duration_display',
        'read_time_display',
    )
    list_filter = ('book',)
    search_fields = ('title', 'book__title', 'content')
    prepopulated_fields = {'slug': ('title',)}
    ordering = ('book', 'order')
    list_select_related = ('book',)

    @display(description='Listen In-Browser')
    def audio_player(self, obj):
        if obj.audio_file:
            return format_html(
                '<audio controls preload="none" style="height: 30px; width: 190px; outline: none; border-radius: 20px;">'
                '<source src="{}" type="audio/mpeg">'
                'Your browser does not support the audio element.'
                '</audio>',
                obj.audio_file.url,
            )
        return format_html('<span style="color: #9ca3af; font-size: 11px;">No audio asset</span>')

    @display(description='Duration')
    def duration_display(self, obj):
        if not obj.duration_seconds:
            return '-'
        m, s = divmod(obj.duration_seconds, 60)
        return f'{m:02d}:{s:02d}'

    @display(description='Read Time')
    def read_time_display(self, obj):
        return f'{obj.estimated_read_minutes} min' if obj.estimated_read_minutes else '-'


@admin.register(UserHighlight)
class UserHighlightAdmin(ModelAdmin):
    list_display = (
        'user',
        'book',
        'quote_card',
        'color_badge',
        'has_note',
        'created_at',
    )
    list_filter = ('color', 'created_at')
    search_fields = ('user__email', 'book__title', 'selected_text', 'note')
    raw_id_fields = ('user', 'book', 'section')
    ordering = ('-created_at',)

    @display(description='Quote Preview')
    def quote_card(self, obj):
        color_styles = {
            'yellow': ('#fef9c3', '#ca8a04', '#713f12'),
            'green': ('#dcfce7', '#16a34a', '#14532d'),
            'blue': ('#dbeafe', '#2563eb', '#1e3a8a'),
            'pink': ('#fce7f3', '#db2777', '#831843'),
        }
        bg, border, text = color_styles.get(obj.color, ('#f3f4f6', '#9ca3af', '#1f2937'))
        snippet = obj.selected_text[:75] + ('...' if len(obj.selected_text) > 75 else '')
        return format_html(
            '<div style="background: {}; border-left: 3px solid {}; color: {}; padding: 4px 8px; border-radius: 4px; font-size: 11px; max-width: 320px; font-style: italic;">"{}"</div>',
            bg,
            border,
            text,
            snippet,
        )

    @display(
        description='Color',
        label={
            'yellow': 'warning',
            'green': 'success',
            'blue': 'info',
            'pink': 'danger',
        },
    )
    def color_badge(self, obj):
        return obj.color

    @display(description='Note', boolean=True)
    def has_note(self, obj):
        return bool(obj.note and obj.note.strip())


@admin.register(UserAudioBookmark)
class UserAudioBookmarkAdmin(ModelAdmin):
    list_display = (
        'user',
        'book',
        'section_title',
        'timestamp_display',
        'title',
        'has_note',
        'created_at',
    )
    list_filter = ('created_at',)
    search_fields = ('user__email', 'book__title', 'title', 'note')
    raw_id_fields = ('user', 'book', 'section')
    ordering = ('-created_at',)

    @display(description='Section')
    def section_title(self, obj):
        return obj.section.title if obj.section else '-'

    @display(description='Timestamp')
    def timestamp_display(self, obj):
        m, s = divmod(obj.timestamp_seconds, 60)
        return format_html(
            '<span style="display: inline-block; padding: 2px 8px; border-radius: 12px; background: #ede9fe; color: #6d28d9; font-weight: 600; font-size: 11px;">⏱️ {:02d}:{:02d}</span>',
            m,
            s,
        )

    @display(description='Note', boolean=True)
    def has_note(self, obj):
        return bool(obj.note and obj.note.strip())


@admin.register(BookFlashcard)
class BookFlashcardAdmin(ModelAdmin):
    list_display = (
        'book',
        'order',
        'prompt_preview',
        'has_quote',
        'options_count',
        'is_generated',
        'created_at',
    )
    list_filter = ('is_generated', 'book')
    search_fields = ('book__title', 'front_prompt', 'back_answer', 'key_quote')
    raw_id_fields = ('book', 'section')
    ordering = ('book', 'order')

    @display(description='Prompt')
    def prompt_preview(self, obj):
        prompt = obj.front_prompt
        return prompt[:60] + '...' if len(prompt) > 60 else prompt

    @display(description='Quote', boolean=True)
    def has_quote(self, obj):
        return bool(obj.key_quote and obj.key_quote.strip())

    @display(description='Quiz Options')
    def options_count(self, obj):
        count = len(obj.quiz_options) if isinstance(obj.quiz_options, list) else 0
        return format_html(
            '<span style="padding: 2px 8px; border-radius: 12px; background: #e0f2fe; color: #0284c7; font-weight: 600; font-size: 11px;">📝 {} options</span>',
            count,
        )


@admin.register(UserFlashcardReview)
class UserFlashcardReviewAdmin(ModelAdmin):
    list_display = (
        'user',
        'flashcard_preview',
        'status_badge',
        'times_reviewed',
        'last_reviewed_at',
        'next_review_at',
    )
    list_filter = ('status', 'last_reviewed_at')
    search_fields = ('user__email', 'flashcard__book__title', 'flashcard__front_prompt')
    raw_id_fields = ('user', 'flashcard')
    ordering = ('-last_reviewed_at',)

    @display(description='Flashcard')
    def flashcard_preview(self, obj):
        title = obj.flashcard.book.title
        prompt = obj.flashcard.front_prompt
        return f"{title}: {prompt[:40]}..."

    @display(description='Status')
    def status_badge(self, obj):
        if obj.status == 'mastered':
            return format_html(
                '<span style="padding: 2px 8px; border-radius: 12px; background: #dcfce7; color: #15803d; font-weight: 600; font-size: 11px;">🟢 Mastered</span>'
            )
        return format_html(
            '<span style="padding: 2px 8px; border-radius: 12px; background: #ffedd5; color: #c2410c; font-weight: 600; font-size: 11px;">🟠 Review Later</span>'
        )
