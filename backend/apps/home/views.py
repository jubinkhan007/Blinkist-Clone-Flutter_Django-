from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import permissions
from django.db.models import QuerySet
from apps.catalog.models import Book
from apps.catalog.serializers import BookListSerializer

class HomeMerchandisingView(APIView):
    permission_classes = (permissions.AllowAny,)

    def get(self, request, *args, **kwargs):
        # In a real app, these querysets would be driven by a CMS or recommendation engine.
        # For MVP, we use simple static rules.

        featured_qs: QuerySet[Book] = Book.objects.filter(is_premium=True).order_by('?')[:5]
        recently_added_qs: QuerySet[Book] = Book.objects.all().order_by('-created_at')[:10]
        recommended_qs: QuerySet[Book] = Book.objects.all().order_by('?')[:10]

        # In a future pass after progress logic is ready, we integrate 'continue_reading'
        continue_reading_data = []

        return Response({
            'featured': BookListSerializer(featured_qs, many=True).data,
            'recently_added': BookListSerializer(recently_added_qs, many=True).data,
            'recommended': BookListSerializer(recommended_qs, many=True).data,
            'continue_reading': continue_reading_data,
        })
