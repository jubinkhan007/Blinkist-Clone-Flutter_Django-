from django.db.models import Count, Q
from rest_framework import permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Author, Book, Category, SearchQueryLog


def log_search_term(query_str: str):
    """Utility helper to record or increment a search term frequency."""
    normalized = query_str.strip()
    if len(normalized) < 2:
        return None
    # Truncate to max 255 chars
    normalized = normalized[:255]
    log_obj, created = SearchQueryLog.objects.get_or_create(
        query__iexact=normalized,
        defaults={'query': normalized, 'count': 1},
    )
    if not created:
        log_obj.count += 1
        log_obj.save(update_fields=['count', 'last_searched_at'])
    return log_obj


class SearchSuggestView(APIView):
    """
    Live query auto-complete endpoint.
    GET /api/v1/catalog/search/suggest/?q=<query>
    """
    permission_classes = (permissions.AllowAny,)

    def get(self, request):
        q = request.query_params.get('q', '').strip()
        if not q or len(q) < 1:
            return Response({'query': q, 'suggestions': []})

        suggestions = []

        # 1. Books (max 5)
        books = (
            Book.objects.filter(
                Q(title__icontains=q) |
                Q(subtitle__icontains=q) |
                Q(author__name__icontains=q)
            )
            .select_related('author')
            .order_by('-rating', 'title')[:5]
        )
        for book in books:
            cover_url = None
            if book.cover_image:
                try:
                    cover_url = request.build_absolute_uri(book.cover_image.url)
                except Exception:
                    cover_url = book.cover_image.url

            suggestions.append({
                'type': 'book',
                'id': book.id,
                'title': book.title,
                'subtitle': book.subtitle,
                'author': book.author.name if book.author else '',
                'slug': book.slug,
                'cover_image_url': cover_url,
                'rating': float(book.rating) if book.rating else 4.7,
            })

        # 2. Authors (max 3)
        authors = (
            Author.objects.filter(name__icontains=q)
            .annotate(book_count=Count('books'))
            .order_by('-book_count', 'name')[:3]
        )
        for author in authors:
            suggestions.append({
                'type': 'author',
                'id': author.id,
                'title': author.name,
                'slug': author.name,
                'book_count': author.book_count,
            })

        # 3. Categories (max 3)
        categories = Category.objects.filter(name__icontains=q).order_by('name')[:3]
        for cat in categories:
            suggestions.append({
                'type': 'category',
                'id': cat.id,
                'title': cat.name,
                'slug': cat.slug,
            })

        return Response({
            'query': q,
            'suggestions': suggestions,
        })


class SearchTrendingView(APIView):
    """
    Trending & popular search terms.
    GET /api/v1/catalog/search/trending/
    """
    permission_classes = (permissions.AllowAny,)

    # Curated fallback tags when logs are sparse
    DEFAULT_TRENDING = [
        {'query': 'Atomic Habits', 'type': 'book', 'badge': '🔥 Trending', 'slug': 'atomic-habits'},
        {'query': 'Productivity', 'type': 'category', 'badge': '⚡ Popular', 'slug': 'productivity'},
        {'query': 'Deep Work', 'type': 'book', 'badge': '🔥 Trending', 'slug': 'deep-work'},
        {'query': 'Psychology', 'type': 'category', 'badge': '🧠 Popular', 'slug': 'psychology'},
        {'query': 'Mindfulness', 'type': 'category', 'badge': '🌱 Popular', 'slug': 'mindfulness'},
        {'query': 'Leadership', 'type': 'category', 'badge': '🚀 Popular', 'slug': 'leadership'},
        {'query': 'Start With Why', 'type': 'book', 'badge': '🔥 Trending', 'slug': 'start-with-why'},
    ]

    def get(self, request):
        seen_queries = set()
        items = []

        # 1. Pull dynamic top searches from SearchQueryLog
        logged_queries = (
            SearchQueryLog.objects.order_by('-count', '-last_searched_at')[:8]
        )
        for log in logged_queries:
            q_norm = log.query.strip()
            if q_norm.lower() not in seen_queries:
                seen_queries.add(q_norm.lower())
                # Check if it matches a category
                cat = Category.objects.filter(name__iexact=q_norm).first()
                if cat:
                    items.append({
                        'query': cat.name,
                        'type': 'category',
                        'badge': '⚡ Popular',
                        'slug': cat.slug,
                    })
                    continue

                # Check if it matches a book
                book = Book.objects.filter(title__iexact=q_norm).first()
                if book:
                    items.append({
                        'query': book.title,
                        'type': 'book',
                        'badge': '🔥 Trending',
                        'slug': book.slug,
                    })
                    continue

                items.append({
                    'query': q_norm,
                    'type': 'query',
                    'badge': '🔥 Trending',
                    'slug': None,
                })

        # 2. Add top categories or popular books from actual catalog if space permits
        if len(items) < 8:
            popular_books = Book.objects.order_by('-rating', '-created_at')[:4]
            for b in popular_books:
                if b.title.lower() not in seen_queries and len(items) < 8:
                    seen_queries.add(b.title.lower())
                    items.append({
                        'query': b.title,
                        'type': 'book',
                        'badge': '🔥 Trending',
                        'slug': b.slug,
                    })

        # 3. Add default curated tags to ensure a rich list of 6-8 tags
        for default_item in self.DEFAULT_TRENDING:
            if len(items) >= 8:
                break
            if default_item['query'].lower() not in seen_queries:
                seen_queries.add(default_item['query'].lower())
                items.append(default_item)

        return Response(items)


class SearchLogQueryView(APIView):
    """
    Log search query execution.
    POST /api/v1/catalog/search/log/
    """
    permission_classes = (permissions.AllowAny,)

    def post(self, request):
        query = request.data.get('query', '')
        log_obj = log_search_term(query)
        if log_obj:
            return Response({
                'status': 'logged',
                'query': log_obj.query,
                'count': log_obj.count,
            }, status=status.HTTP_200_OK)
        return Response({'status': 'ignored'}, status=status.HTTP_200_OK)
