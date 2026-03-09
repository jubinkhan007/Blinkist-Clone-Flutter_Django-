from rest_framework import views, response, status, permissions
from django.shortcuts import get_object_or_404
from apps.catalog.models import Book
from apps.summaries.models import SummarySection
from .models import UserBookProgress, UserSectionProgress, UserAudioProgress, UserSummaryProgress
from .serializers import UserBookProgressSerializer, UserAudioProgressSerializer, UserSummaryProgressSerializer

class ReadProgressView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, book_id):
        # GET /api/v1/progress/books/<book_id>/
        book = get_object_or_404(Book, id=book_id)
        progress, _ = UserSummaryProgress.objects.get_or_create(user=request.user, book=book)
        serializer = UserSummaryProgressSerializer(progress)
        return response.Response(serializer.data)

class MarkSectionReadView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, book_id, section_id):
        # POST /api/v1/progress/books/<book_id>/section/<section_id>/
        book = get_object_or_404(Book, id=book_id)
        section = get_object_or_404(SummarySection, id=section_id, book=book)

        # Mark section complete
        UserSectionProgress.objects.update_or_create(
            user=request.user, 
            section=section,
            defaults={'is_completed': True}
        )

        # Update book progress
        summary_progress, _ = UserSummaryProgress.objects.get_or_create(user=request.user, book=book)
        summary_progress.current_section = section
        
        # Recalculate percentage
        total_sections = book.sections.count()
        completed_sections_count = UserSectionProgress.objects.filter(
            user=request.user, 
            section__book=book, 
            is_completed=True
        ).count()
        
        summary_progress.completed_sections_count = completed_sections_count
        summary_progress.save()

        return response.Response(UserSummaryProgressSerializer(summary_progress).data)


class AudioProgressView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, book_id):
        # GET /api/v1/progress/books/<book_id>/audio/
        book = get_object_or_404(Book, id=book_id)
        progress, _ = UserAudioProgress.objects.get_or_create(user=request.user, book=book)
        return response.Response(UserAudioProgressSerializer(progress).data)

    def post(self, request, book_id):
        # POST /api/v1/progress/books/<book_id>/audio/
        # Body: { section_id, position_seconds, is_finished }
        book = get_object_or_404(Book, id=book_id)
        section_id = request.data.get('section_id')
        position_seconds = request.data.get('position_seconds', 0.0)
        is_finished = request.data.get('is_finished', False)

        section = None
        if section_id:
            section = get_object_or_404(SummarySection, id=section_id, book=book)

        progress, _ = UserAudioProgress.objects.get_or_create(user=request.user, book=book)
        progress.current_section = section
        progress.current_position_seconds = position_seconds
        progress.is_finished = is_finished
        progress.save()

        return response.Response(UserAudioProgressSerializer(progress).data)
