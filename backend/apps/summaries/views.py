from django.shortcuts import get_object_or_404
from rest_framework import generics, permissions

from apps.catalog.models import Book
from apps.summaries.models import SummarySection
from apps.summaries.serializers import SummarySectionSerializer


class SummarySectionListView(generics.ListAPIView):
    serializer_class = SummarySectionSerializer
    permission_classes = (permissions.AllowAny,)
    pagination_class = None

    def get_queryset(self):
        return SummarySection.objects.filter(
            book__slug=self.kwargs['book_slug']
        ).select_related('book').order_by('order')

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context['request'] = self.request
        return context

    def list(self, request, *args, **kwargs):
        get_object_or_404(Book, slug=kwargs['book_slug'])
        return super().list(request, *args, **kwargs)


class SummarySectionDetailView(generics.RetrieveAPIView):
    serializer_class = SummarySectionSerializer
    permission_classes = (permissions.AllowAny,)
    lookup_field = 'slug'

    def get_queryset(self):
        return SummarySection.objects.filter(
            book__slug=self.kwargs['book_slug']
        ).select_related('book')

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context['request'] = self.request
        return context
