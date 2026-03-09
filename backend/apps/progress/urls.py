from django.urls import path
from .views import ReadProgressView, MarkSectionReadView, AudioProgressView

urlpatterns = [
    path('books/<int:book_id>/', ReadProgressView.as_view(), name='book_progress'),
    path('books/<int:book_id>/section/<int:section_id>/', MarkSectionReadView.as_view(), name='mark_section_read'),
    path('books/<int:book_id>/audio/', AudioProgressView.as_view(), name='audio_progress'),
]
