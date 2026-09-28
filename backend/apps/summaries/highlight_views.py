from rest_framework import generics, permissions, status
from rest_framework.response import Response
from apps.summaries.models import UserHighlight
from apps.summaries.highlight_serializers import (
    UserHighlightSerializer,
    UserHighlightCreateSerializer,
)


class UserHighlightListCreateView(generics.ListCreateAPIView):
    permission_classes = [permissions.IsAuthenticated]

    def get_serializer_class(self):
        if self.request.method == 'POST':
            return UserHighlightCreateSerializer
        return UserHighlightSerializer

    def get_queryset(self):
        queryset = UserHighlight.objects.filter(
            user=self.request.user
        ).select_related('book', 'book__author', 'section')

        book_slug = self.request.query_params.get('book_slug')
        if book_slug:
            queryset = queryset.filter(book__slug=book_slug)
        return queryset

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        highlight = serializer.save()
        output_serializer = UserHighlightSerializer(highlight, context={'request': request})
        return Response(output_serializer.data, status=status.HTTP_201_CREATED)


class UserHighlightDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = UserHighlightSerializer

    def get_queryset(self):
        return UserHighlight.objects.filter(
            user=self.request.user
        ).select_related('book', 'book__author', 'section')
