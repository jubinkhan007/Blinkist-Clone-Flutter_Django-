from django.urls import path
from .views import (
    BookAskAiView,
    BookDetailView,
    BookListView,
    CategoryListView,
    CollectionDetailView,
    CollectionListView,
    UserLibraryListView,
    UserLibraryToggleView,
)

urlpatterns = [
    path('categories/', CategoryListView.as_view(), name='category_list'),
    path('collections/', CollectionListView.as_view(), name='collection_list'),
    path('collections/<slug:slug>/', CollectionDetailView.as_view(), name='collection_detail'),
    path('books/', BookListView.as_view(), name='book_list'),
    path('books/<slug:slug>/ask/', BookAskAiView.as_view(), name='book_ask_ai'),
    path('books/<slug:slug>/', BookDetailView.as_view(), name='book_detail'),
    path('library/', UserLibraryListView.as_view(), name='user_library'),
    path('library/<slug:book_slug>/', UserLibraryToggleView.as_view(), name='user_library_toggle'),
]

