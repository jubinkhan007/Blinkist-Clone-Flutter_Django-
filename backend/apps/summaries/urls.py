from django.urls import path

from .views import SummarySectionDetailView, SummarySectionListView
from apps.catalog.views import BookAskAiView
from .flashcard_views import (
    BookFlashcardListView,
    FlashcardReviewView,
    DailyReviewDeckView,
)

urlpatterns = [
    # Book AI Q&A Endpoint
    path('<slug:slug>/ask/', BookAskAiView.as_view(), name='summary_ask_ai'),

    # Flashcard & Active Recall Endpoints
    path('flashcards/daily-review/', DailyReviewDeckView.as_view(), name='daily_review_deck'),
    path('flashcards/<int:pk>/review/', FlashcardReviewView.as_view(), name='flashcard_review'),
    path('books/<slug:book_slug>/flashcards/', BookFlashcardListView.as_view(), name='book_flashcard_list'),

    # Summary Sections
    path('<slug:book_slug>/', SummarySectionListView.as_view(), name='summary_section_list'),
    path('<slug:book_slug>/<slug:slug>/', SummarySectionDetailView.as_view(), name='summary_section_detail'),
]
