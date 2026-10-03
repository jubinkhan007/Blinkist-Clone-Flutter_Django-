from django.db.models import Count
from rest_framework import filters, generics, permissions, status, views
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend
from apps.catalog.ai_service import ask_book_ai
from apps.catalog.models import Book, Category, UserLibraryItem, Collection, UserAudioQueueItem
from apps.catalog.serializers import (
    BookListSerializer,
    BookDetailSerializer,
    CategorySerializer,
    CollectionListSerializer,
    CollectionDetailSerializer,
    UserAudioQueueItemSerializer,
)

class CategoryListView(generics.ListAPIView):
    queryset = Category.objects.all().order_by('name')
    serializer_class = CategorySerializer
    permission_classes = (permissions.AllowAny,)
    pagination_class = None

class BookListView(generics.ListAPIView):
    serializer_class = BookListSerializer
    permission_classes = (permissions.AllowAny,)
    
    # Enable filtering and searching
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    
    # Define capabilities
    filterset_fields = ['categories__slug', 'is_premium', 'author__name']
    search_fields = ['title', 'subtitle', 'author__name', 'categories__name']
    ordering_fields = ['created_at', 'title', 'estimated_read_time_minutes', 'rating']

    def get_queryset(self):
        qs = Book.objects.all().prefetch_related('categories', 'author', 'sections')

        # 1. Format Filter: Audio vs Text
        book_format = (
            self.request.query_params.get('book_format') or
            self.request.query_params.get('content_format')
        )
        if book_format == 'audio' or self.request.query_params.get('has_audio') == 'true':
            qs = qs.filter(sections__audio_file__isnull=False).exclude(sections__audio_file='').distinct()
        elif book_format == 'text':
            pass

        # 2. Duration Filter (<10m, 10-20m, 20m+)
        duration = self.request.query_params.get('duration')
        if duration == 'short':
            qs = qs.filter(estimated_read_time_minutes__lt=10)
        elif duration == 'medium':
            qs = qs.filter(estimated_read_time_minutes__gte=10, estimated_read_time_minutes__lte=20)
        elif duration == 'long':
            qs = qs.filter(estimated_read_time_minutes__gt=20)

        # 3. Sorting: Popularity, Newest, Highest Rated
        sort_by = self.request.query_params.get('sort_by') or self.request.query_params.get('ordering')
        if sort_by in ('popularity', '-popularity'):
            qs = qs.annotate(
                popularity_score=Count('saved_by', distinct=True) + Count('user_progress', distinct=True)
            ).order_by('-popularity_score', '-created_at')
        elif sort_by in ('highest_rated', 'rating', '-rating'):
            qs = qs.order_by('-rating', '-created_at')
        elif sort_by in ('newest', '-newest', '-created_at'):
            qs = qs.order_by('-created_at')
        elif not sort_by:
            qs = qs.order_by('-created_at')

        return qs

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


class BookAskAiView(views.APIView):
    permission_classes = (permissions.AllowAny,)

    def post(self, request, slug):
        book = generics.get_object_or_404(
            Book.objects.prefetch_related('sections', 'author'),
            slug=slug,
        )
        question = request.data.get('question')
        if not question or not str(question).strip():
            return Response(
                {'error': 'Question is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        section_slug = request.data.get('section_slug')
        history = request.data.get('history')
        if not isinstance(history, list):
            history = None

        result = ask_book_ai(
            book=book,
            question=str(question).strip(),
            section_slug=section_slug,
            history=history,
        )
        return Response(result, status=status.HTTP_200_OK)


class UserAudioQueueView(generics.ListCreateAPIView):
    serializer_class = UserAudioQueueItemSerializer
    permission_classes = (permissions.IsAuthenticated,)
    pagination_class = None

    def get_queryset(self):
        return UserAudioQueueItem.objects.filter(
            user=self.request.user
        ).select_related('book', 'book__author').prefetch_related('book__categories').order_by('order', 'added_at')

    def create(self, request, *args, **kwargs):
        book_slug = request.data.get('book_slug')
        if not book_slug:
            return Response({'error': 'book_slug is required.'}, status=status.HTTP_400_BAD_REQUEST)

        book = generics.get_object_or_404(Book, slug=book_slug)
        existing = UserAudioQueueItem.objects.filter(user=request.user, book=book).first()
        if existing:
            serializer = self.get_serializer(existing)
            return Response(serializer.data, status=status.HTTP_200_OK)

        last_item = UserAudioQueueItem.objects.filter(user=request.user).order_by('-order').first()
        next_order = (last_item.order + 1) if last_item else 0

        queue_item = UserAudioQueueItem.objects.create(
            user=request.user,
            book=book,
            order=next_order,
        )
        serializer = self.get_serializer(queue_item)
        return Response(serializer.data, status=status.HTTP_201_CREATED)


class UserAudioQueueDeleteView(views.APIView):
    permission_classes = (permissions.IsAuthenticated,)

    def delete(self, request, book_slug):
        book = generics.get_object_or_404(Book, slug=book_slug)
        deleted_count, _ = UserAudioQueueItem.objects.filter(user=request.user, book=book).delete()
        return Response({'deleted': bool(deleted_count)}, status=status.HTTP_200_OK)


class UserAudioQueueClearView(views.APIView):
    permission_classes = (permissions.IsAuthenticated,)

    def post(self, request):
        UserAudioQueueItem.objects.filter(user=request.user).delete()
        return Response({'cleared': True}, status=status.HTTP_200_OK)


class UserAudioQueueReorderView(views.APIView):
    permission_classes = (permissions.IsAuthenticated,)

    def post(self, request):
        slugs = request.data.get('slugs', [])
        if not isinstance(slugs, list):
            return Response({'error': 'slugs must be a list.'}, status=status.HTTP_400_BAD_REQUEST)

        for index, slug in enumerate(slugs):
            UserAudioQueueItem.objects.filter(user=request.user, book__slug=slug).update(order=index)

        return Response({'reordered': True}, status=status.HTTP_200_OK)


