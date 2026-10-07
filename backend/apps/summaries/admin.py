from django.contrib import admin
from django.utils.html import format_html
from unfold.admin import ModelAdmin
from unfold.decorators import display

from .models import SummarySection, UserAudioBookmark, UserHighlight


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
