from __future__ import annotations

import logging
from django.shortcuts import get_object_or_404
from rest_framework import permissions, status
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.catalog.models import Category, ContentIngestionJob
from apps.catalog.ingestion_serializers import (
    ContentIngestionJobCreateSerializer,
    ContentIngestionJobDetailSerializer,
)
from apps.catalog.ingestion_service import run_ingestion_job

logger = logging.getLogger(__name__)


class ContentIngestionJobListView(APIView):
    """
    POST: Ingest a new book via PDF, EPUB, or Metadata query.
    GET: List recent ingestion jobs.
    """
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def get(self, request):
        status_filter = request.query_params.get('status')
        queryset = ContentIngestionJob.objects.select_related('book', 'target_category', 'created_by').all()
        if status_filter:
            queryset = queryset.filter(status=status_filter.upper())
        serializer = ContentIngestionJobDetailSerializer(queryset[:50], many=True, context={'request': request})
        return Response(serializer.data, status=status.HTTP_200_OK)

    def post(self, request):
        serializer = ContentIngestionJobCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        target_cat = None
        if data.get('target_category_id'):
            target_cat = Category.objects.filter(id=data['target_category_id']).first()

        job = ContentIngestionJob.objects.create(
            file=data.get('file'),
            source_type=data.get('source_type', 'PDF'),
            input_query=data.get('input_query', ''),
            target_category=target_cat,
            voice_name=data.get('voice_name', 'en-US-ChristopherNeural'),
            generate_audio=data.get('generate_audio', True),
            generate_flashcards=data.get('generate_flashcards', True),
            generate_action_plan=data.get('generate_action_plan', True),
            created_by=request.user if request.user.is_authenticated else None,
            status='PENDING',
        )

        run_sync = data.get('run_synchronously', False)
        if run_sync:
            try:
                run_ingestion_job(job.id)
                job.refresh_from_db()
            except Exception as e:
                logger.error(f"Synchronous ingestion failed for job {job.id}: {e}", exc_info=True)
                job.refresh_from_db()

        out_serializer = ContentIngestionJobDetailSerializer(job, context={'request': request})
        return Response(out_serializer.data, status=status.HTTP_201_CREATED)


class ContentIngestionJobDetailView(APIView):
    """
    GET: Retrieve real-time progress, logs, and linked book status.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, pk: int):
        job = get_object_or_404(
            ContentIngestionJob.objects.select_related('book', 'target_category', 'created_by'),
            pk=pk,
        )
        serializer = ContentIngestionJobDetailSerializer(job, context={'request': request})
        return Response(serializer.data, status=status.HTTP_200_OK)


class ContentIngestionJobRetryView(APIView):
    """
    POST: Retry a failed or pending ingestion job.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk: int):
        job = get_object_or_404(ContentIngestionJob, pk=pk)
        run_sync = request.data.get('run_synchronously', False) or (request.query_params.get('sync') == 'true')

        job.status = 'PENDING'
        job.progress_percent = 0
        job.current_step = 'Queued for retry...'
        job.logs += f"\n--- RETRY TRIGGERED BY {request.user.email} ---\n"
        job.save()

        if run_sync:
            try:
                run_ingestion_job(job.id)
                job.refresh_from_db()
            except Exception as e:
                logger.error(f"Synchronous retry failed for job {job.id}: {e}", exc_info=True)
                job.refresh_from_db()
        else:
            from apps.catalog.tasks import process_book_file
            try:
                process_book_file.delay(job.id)
            except Exception as e:
                logger.warning(f"Could not dispatch Celery task on retry: {e}")

        serializer = ContentIngestionJobDetailSerializer(job, context={'request': request})
        return Response(serializer.data, status=status.HTTP_200_OK)
