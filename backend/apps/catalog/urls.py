from django.urls import path
from .views import BookListView, BookDetailView, CategoryListView

urlpatterns = [
    path('categories/', CategoryListView.as_view(), name='category_list'),
    path('books/', BookListView.as_view(), name='book_list'),
    path('books/<slug:slug>/', BookDetailView.as_view(), name='book_detail'),
]
