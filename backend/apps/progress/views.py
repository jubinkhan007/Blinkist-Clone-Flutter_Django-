from rest_framework import views, response, status, permissions
from django.shortcuts import get_object_or_404
from apps.catalog.models import Book
from apps.summaries.models import SummarySection
from .models import UserBookProgress, UserSectionProgress
from .serializers import UserBookProgressSerializer

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
