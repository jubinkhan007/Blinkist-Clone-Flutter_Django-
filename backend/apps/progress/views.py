from rest_framework import views, response, status, permissions
from django.shortcuts import get_object_or_404
from apps.catalog.models import Book
from apps.summaries.models import SummarySection
from .models import UserBookProgress, UserSectionProgress, UserAudioProgress
from .serializers import UserBookProgressSerializer, UserAudioProgressSerializer

class ReadProgressView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, book_id):
        # GET /api/v1/progress/books/<book_id>/
        book = get_object_or_404(Book, id=book_id)
        progress, _ = UserBookProgress.objects.get_or_create(user=request.user, book=book)
        serializer = UserBookProgressSerializer(progress)
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
        book_progress, _ = UserBookProgress.objects.get_or_create(user=request.user, book=book)
        book_progress.current_section = section
        
        # Recalculate percentage
        total_sections = book.sections.count()
        completed_sections_count = UserSectionProgress.objects.filter(
            user=request.user, 
            section__book=book, 
            is_completed=True
        ).count()
        
        if total_sections > 0:
            book_progress.percent_complete = int((completed_sections_count / total_sections) * 100)
            if book_progress.percent_complete == 100:
                book_progress.is_completed = True
                
        book_progress.save()

        return response.Response(UserBookProgressSerializer(book_progress).data)


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
