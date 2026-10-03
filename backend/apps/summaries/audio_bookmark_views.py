from rest_framework import generics, permissions, status
from rest_framework.response import Response
from apps.summaries.models import UserAudioBookmark
from apps.summaries.audio_bookmark_serializers import (
    UserAudioBookmarkSerializer,
    UserAudioBookmarkCreateSerializer,
)


class UserAudioBookmarkListCreateView(generics.ListCreateAPIView):
    permission_classes = [permissions.IsAuthenticated]

    def get_serializer_class(self):
        if self.request.method == 'POST':
            return UserAudioBookmarkCreateSerializer
        return UserAudioBookmarkSerializer

    def get_queryset(self):
        queryset = UserAudioBookmark.objects.filter(
            user=self.request.user
        ).select_related('book', 'book__author', 'section')

        book_slug = self.request.query_params.get('book_slug')
        if book_slug:
            queryset = queryset.filter(book__slug=book_slug)
        return queryset

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        bookmark = serializer.save()
        from apps.progress.views import record_activity
        record_activity(request.user)
        output_serializer = UserAudioBookmarkSerializer(bookmark, context={'request': request})
        return Response(output_serializer.data, status=status.HTTP_201_CREATED)


class UserAudioBookmarkDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = UserAudioBookmarkSerializer

    def get_queryset(self):
        return UserAudioBookmark.objects.filter(
            user=self.request.user
        ).select_related('book', 'book__author', 'section')
