from django.urls import path
from .search_views import (
    SearchLogQueryView,
    SearchSuggestView,
    SearchTrendingView,
)
from .views import (
    BookAskAiView,
    BookDetailView,
    BookListView,
    CategoryListView,
    CollectionDetailView,
    CollectionListView,
    UserAudioQueueClearView,
    UserAudioQueueDeleteView,
    UserAudioQueueReorderView,
    UserAudioQueueView,
    UserLibraryListView,
    UserLibraryToggleView,
)

urlpatterns = [
    path('search/suggest/', SearchSuggestView.as_view(), name='search_suggest'),
    path('search/trending/', SearchTrendingView.as_view(), name='search_trending'),
    path('search/log/', SearchLogQueryView.as_view(), name='search_log'),
    path('categories/', CategoryListView.as_view(), name='category_list'),
    path('collections/', CollectionListView.as_view(), name='collection_list'),
    path('collections/<slug:slug>/', CollectionDetailView.as_view(), name='collection_detail'),
    path('books/', BookListView.as_view(), name='book_list'),
    path('books/<slug:slug>/ask/', BookAskAiView.as_view(), name='book_ask_ai'),
    path('books/<slug:slug>/', BookDetailView.as_view(), name='book_detail'),
    path('library/', UserLibraryListView.as_view(), name='user_library'),
    path('library/<slug:book_slug>/', UserLibraryToggleView.as_view(), name='user_library_toggle'),
    path('queue/', UserAudioQueueView.as_view(), name='user_audio_queue'),
    path('queue/clear/', UserAudioQueueClearView.as_view(), name='user_audio_queue_clear'),
    path('queue/reorder/', UserAudioQueueReorderView.as_view(), name='user_audio_queue_reorder'),
    path('queue/<slug:book_slug>/', UserAudioQueueDeleteView.as_view(), name='user_audio_queue_delete'),
]

