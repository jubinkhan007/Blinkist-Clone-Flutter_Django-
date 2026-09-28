from django.urls import path
from .views import (
    BookDetailView,
    BookListView,
    CategoryListView,
    UserLibraryListView,
    UserLibraryToggleView,
)

urlpatterns = [
    path('categories/', CategoryListView.as_view(), name='category_list'),
    path('books/', BookListView.as_view(), name='book_list'),
    path('books/<slug:slug>/', BookDetailView.as_view(), name='book_detail'),
    path('library/', UserLibraryListView.as_view(), name='user_library'),
    path('library/<slug:book_slug>/', UserLibraryToggleView.as_view(), name='user_library_toggle'),
]
