from django.urls import path
from .search_views import (
    SearchLogQueryView,
    SearchSuggestView,
    SearchTrendingView,
)
from .reading_list_views import (
    SharedReadingListCloneView,
    SharedReadingListDetailView,
    UserReadingListAddBookView,
    UserReadingListDetailView,
    UserReadingListListView,
    UserReadingListMembershipView,
    UserReadingListRemoveBookView,
    UserReadingListReorderView,
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

    # User Reading Lists & Spaces
    path('spaces/', UserReadingListListView.as_view(), name='user_reading_lists'),
    path('spaces/membership/', UserReadingListMembershipView.as_view(), name='user_reading_list_membership'),
    path('spaces/<int:pk>/', UserReadingListDetailView.as_view(), name='user_reading_list_detail'),
    path('spaces/<int:pk>/books/', UserReadingListAddBookView.as_view(), name='user_reading_list_add_book'),
    path('spaces/<int:pk>/books/<slug:book_slug>/', UserReadingListRemoveBookView.as_view(), name='user_reading_list_remove_book'),
    path('spaces/<int:pk>/reorder/', UserReadingListReorderView.as_view(), name='user_reading_list_reorder'),
    path('spaces/share/<uuid:token>/', SharedReadingListDetailView.as_view(), name='shared_reading_list_detail'),
    path('spaces/share/<uuid:token>/clone/', SharedReadingListCloneView.as_view(), name='shared_reading_list_clone'),
]

