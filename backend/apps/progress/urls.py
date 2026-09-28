from django.urls import path
from .views import (
    ReadProgressView,
    MarkSectionReadView,
    AudioProgressView,
    FullBookProgressView,
    UserReadingStatsView,
    RecordActivityView,
)

urlpatterns = [
    path('stats/', UserReadingStatsView.as_view(), name='reading_stats'),
    path('activity/', RecordActivityView.as_view(), name='record_activity'),
    path('books/<int:book_id>/', ReadProgressView.as_view(), name='book_progress'),
    path('books/<int:book_id>/section/<int:section_id>/', MarkSectionReadView.as_view(), name='mark_section_read'),
    path('books/<int:book_id>/audio/', AudioProgressView.as_view(), name='audio_progress'),
    path('books/<int:book_id>/full/', FullBookProgressView.as_view(), name='full_book_progress'),
]
