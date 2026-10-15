from __future__ import annotations

import logging
import sys
from django.conf import settings
from django.db.models.signals import post_save
from django.dispatch import receiver
from .models import ContentIngestionJob

logger = logging.getLogger(__name__)


@receiver(post_save, sender=ContentIngestionJob)
def trigger_ingestion_job(sender, instance, created, **kwargs):
    if created and instance.status == 'PENDING':
        if 'test' in sys.argv or getattr(settings, 'IS_TESTING', False):
            # Do not automatically dispatch background Celery during test runs
            return
        try:
            from .tasks import process_book_file
            process_book_file.delay(instance.id)
        except Exception as e:
            logger.warning(
                f"Could not dispatch Celery task for IngestionJob #{instance.id} (Redis/Celery worker may be offline): {e}"
            )
