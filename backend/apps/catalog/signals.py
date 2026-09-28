from django.db.models.signals import post_save
from django.dispatch import receiver
from .models import ContentIngestionJob
from .tasks import process_book_file

@receiver(post_save, sender=ContentIngestionJob)
def trigger_ingestion_job(sender, instance, created, **kwargs):
    if created and instance.status == 'PENDING':
        process_book_file.delay(instance.id)
