from __future__ import annotations

import json
from django.contrib import admin
from django.contrib.admin.models import ADDITION, CHANGE, DELETION, LogEntry
from django.utils.html import format_html
from unfold.admin import ModelAdmin
from unfold.decorators import display


@admin.register(LogEntry)
class LogEntryAdmin(ModelAdmin):
    list_display = (
        'action_time',
        'user',
        'action_badge',
        'content_type',
        'object_repr',
        'formatted_change_message',
    )
    list_filter = ('action_flag', 'content_type', 'action_time')
    search_fields = ('object_repr', 'change_message', 'user__email', 'user__username')
    date_hierarchy = 'action_time'
    ordering = ('-action_time',)

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False

    @display(
        description='Action',
        label={
            'Added': 'success',
            'Changed': 'info',
            'Deleted': 'danger',
        },
    )
    def action_badge(self, obj):
        if obj.action_flag == ADDITION:
            return 'Added'
        elif obj.action_flag == CHANGE:
            return 'Changed'
        elif obj.action_flag == DELETION:
            return 'Deleted'
        return 'Unknown'

    @display(description='Changes')
    def formatted_change_message(self, obj):
        msg = obj.get_change_message()
        if not msg:
            return '-'
        try:
            parsed = json.loads(msg)
            if isinstance(parsed, list):
                parts = []
                for entry in parsed:
                    if 'added' in entry:
                        parts.append('Added object')
                    elif 'changed' in entry:
                        fields = ', '.join(entry['changed'].get('fields', []))
                        parts.append(f"Changed: {fields}" if fields else "Modified")
                    elif 'deleted' in entry:
                        parts.append('Deleted object')
                if parts:
                    return '; '.join(parts)
        except Exception:
            pass
        return msg[:80] + ('...' if len(msg) > 80 else '')
