from rest_framework import filters, generics, permissions, views
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend
from apps.catalog.models import Book, Category, UserLibraryItem, Collection
from apps.catalog.serializers import (
    BookListSerializer,
    BookDetailSerializer,
    CategorySerializer,
    CollectionListSerializer,
    CollectionDetailSerializer,
)

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

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context['request'] = self.request
        return context

class BookDetailView(generics.RetrieveAPIView):
    queryset = Book.objects.all()
    serializer_class = BookDetailSerializer
    lookup_field = 'slug'
    permission_classes = (permissions.AllowAny,)

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context['request'] = self.request
        return context


class UserLibraryListView(generics.ListAPIView):
    serializer_class = BookListSerializer
    permission_classes = (permissions.IsAuthenticated,)
    pagination_class = None

    def get_queryset(self):
        return Book.objects.filter(saved_by__user=self.request.user).prefetch_related(
            'categories',
            'author',
        ).order_by('-saved_by__saved_at')

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context['request'] = self.request
        return context


class UserLibraryToggleView(views.APIView):
    permission_classes = (permissions.IsAuthenticated,)

    def post(self, request, book_slug):
        book = generics.get_object_or_404(Book, slug=book_slug)
        library_item, created = UserLibraryItem.objects.get_or_create(
            user=request.user,
            book=book,
        )
        if created:
            return Response({'saved': True})

        library_item.delete()
        return Response({'saved': False})


class CollectionListView(generics.ListAPIView):
    queryset = Collection.objects.filter(is_featured=True).prefetch_related(
        'items__book__author',
        'items__book__categories',
    ).order_by('order', '-created_at')
    serializer_class = CollectionListSerializer
    permission_classes = (permissions.AllowAny,)
    pagination_class = None

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context['request'] = self.request
        return context


class CollectionDetailView(generics.RetrieveAPIView):
    queryset = Collection.objects.all().prefetch_related(
        'items__book__author',
        'items__book__categories',
    )
    serializer_class = CollectionDetailSerializer
    lookup_field = 'slug'
    permission_classes = (permissions.AllowAny,)

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context['request'] = self.request
        return context

