from rest_framework import generics, filters, permissions
from django_filters.rest_framework import DjangoFilterBackend
from apps.catalog.models import Book, Category
from apps.catalog.serializers import BookListSerializer, BookDetailSerializer, CategorySerializer

class CategoryListView(generics.ListAPIView):
    queryset = Category.objects.all().order_by('name')
    serializer_class = CategorySerializer
    permission_classes = (permissions.AllowAny,)
    pagination_class = None

class BookListView(generics.ListAPIView):
    queryset = Book.objects.all().order_by('-created_at')
    serializer_class = BookListSerializer
    permission_classes = (permissions.AllowAny,)
    
    # Enable filtering and searching
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    
    # Define capabilities
    filterset_fields = ['categories__slug', 'is_premium', 'author__name']
    search_fields = ['title', 'subtitle', 'author__name', 'categories__name']  # Uses PostgreSQL icontains
    ordering_fields = ['created_at', 'title', 'estimated_read_time_minutes']

class BookDetailView(generics.RetrieveAPIView):
    queryset = Book.objects.all()
    serializer_class = BookDetailSerializer
    lookup_field = 'slug'
    permission_classes = (permissions.AllowAny,)
