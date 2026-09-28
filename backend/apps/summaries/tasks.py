import os
import tempfile
import logging
from celery import shared_task
from django.core.files import File
from django.conf import settings
from apps.catalog.models import Book
from .models import SummarySection
from .tts_service import generate_audio
from mutagen.mp3 import MP3

logger = logging.getLogger(__name__)

@shared_task
def generate_audio_for_book(book_id):
    try:
        book = Book.objects.get(id=book_id)
        sections = book.sections.all().order_by('order')
        
        for section in sections:
            if section.audio_file:
                continue  # Skip if already has audio
            
            # Use plain_text if available, otherwise content (Markdown/HTML)
            text_to_speak = section.plain_text or section.content
            if not text_to_speak:
                continue
            
            # Create a temporary file to hold the MP3
            with tempfile.NamedTemporaryFile(suffix='.mp3', delete=False) as tmp_file:
                tmp_path = tmp_file.name
            
            try:
                # Generate audio
                generate_audio(text_to_speak, tmp_path)
                
                # Calculate duration
                audio = MP3(tmp_path)
                section.duration_seconds = int(audio.info.length)
                
                # Save to model
                with open(tmp_path, 'rb') as f:
                    section.audio_file.save(
                        f"book_{book.id}_section_{section.order}.mp3",
                        File(f),
                        save=True
                    )
                
                logger.info(f"Generated audio for section {section.id}")
                
            finally:
                # Cleanup temp file
                if os.path.exists(tmp_path):
                    os.remove(tmp_path)
                    
    except Book.DoesNotExist:
        logger.error(f"Book {book_id} not found for TTS.")
    except Exception as e:
        logger.error(f"TTS generation failed: {e}", exc_info=True)
