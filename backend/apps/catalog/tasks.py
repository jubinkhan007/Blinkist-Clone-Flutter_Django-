from __future__ import annotations

import logging
from celery import shared_task
from apps.catalog.models import Book
from .recommendation_service import get_book_embedding, upsert_book_vector

logger = logging.getLogger(__name__)


def extract_text_from_pdf(file_path: str) -> str:
    from apps.catalog.ingestion_service import extract_text_and_cover_from_pdf
    text, _ = extract_text_and_cover_from_pdf(file_path)
    return text


def extract_cover_from_pdf(file_path: str):
    from apps.catalog.ingestion_service import extract_text_and_cover_from_pdf
    _, cover_bytes = extract_text_and_cover_from_pdf(file_path)
    return cover_bytes


@shared_task
def process_book_file(job_id: int):
    """
    Celery task that delegates to the comprehensive ingestion service.
    """
    from apps.catalog.ingestion_service import run_ingestion_job
    try:
        book = run_ingestion_job(job_id)
        logger.info(f"Successfully processed ingestion job {job_id} -> Book {book.id}")
        return book.id
    except Exception as e:
        logger.error(f"process_book_file failed for job {job_id}: {e}", exc_info=True)
        raise


@shared_task
def vectorize_book(book_id: int):
    """
    Generate and store vector embedding for a book using Gemini.
    """
    try:
        book = Book.objects.get(id=book_id)
        text_to_embed = f"{book.title} {book.subtitle} {book.description} {book.what_you_will_learn}"
        
        vector = get_book_embedding(text_to_embed)
        if vector:
            upsert_book_vector(book.id, vector)
            logger.info(f"Vectorized book {book.id} with Gemini")
            
    except Book.DoesNotExist:
        logger.error(f"Book {book_id} not found for vectorization.")
    except Exception as e:
        logger.error(f"Vectorization failed: {e}", exc_info=True)
