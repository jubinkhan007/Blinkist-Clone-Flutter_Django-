from django.db.models import QuerySet
from rest_framework import permissions
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.catalog.serializers import BookListSerializer, CollectionListSerializer
from apps.home.serializers import ContinueReadingSerializer
from apps.home.services import get_home_feed_for_user

class HomeMerchandisingView(APIView):
    permission_classes = (permissions.AllowAny,)

    def get(self, request, *args, **kwargs):
        # In a real app, these querysets would be driven by a CMS or recommendation engine.
        # For MVP, we use simple static rules.

        feed = get_home_feed_for_user(request.user)
        featured_qs: QuerySet = feed['featured']
        recently_added_qs: QuerySet = feed['recently_added']
        recommended_qs: QuerySet = feed['recommended']
        continue_reading_data = feed['continue_reading']
        collections_data = feed.get('collections', [])

        daily_pick_book = feed.get('daily_pick')
        daily_pick_data = (
            BookListSerializer(daily_pick_book, context={'request': request}).data
            if daily_pick_book
            else None
        )

        return Response({
            'daily_pick': daily_pick_data,
            'featured': BookListSerializer(featured_qs, many=True, context={'request': request}).data,
            'recently_added': BookListSerializer(recently_added_qs, many=True, context={'request': request}).data,
            'recommended': BookListSerializer(recommended_qs, many=True, context={'request': request}).data,
            'continue_reading': ContinueReadingSerializer(continue_reading_data, many=True, context={'request': request}).data,
            'collections': CollectionListSerializer(collections_data, many=True, context={'request': request}).data,
        })

