import os
import json
import logging
import uuid
import fitz  # PyMuPDF
from celery import shared_task
from django.conf import settings
from django.core.files.base import ContentFile
from django.utils.text import slugify
import google.generativeai as genai
from .models import ContentIngestionJob, Book, Author, Category
from apps.summaries.models import SummarySection
from .recommendation_service import get_book_embedding, upsert_book_vector, configure_gemini

logger = logging.getLogger(__name__)

def extract_text_from_pdf(file_path):
    doc = fitz.open(file_path)
    text = ""
    for page in doc:
        text += page.get_text()
    return text

def extract_cover_from_pdf(file_path):
    try:
        doc = fitz.open(file_path)
        if len(doc) > 0:
            page = doc[0]
            pix = page.get_pixmap(dpi=150)
            return pix.tobytes("png")
    except Exception as e:
        logger.error(f"Failed to extract cover from PDF {file_path}: {e}")
    return None

@shared_task
def process_book_file(job_id):
    job = ContentIngestionJob.objects.get(id=job_id)
    job.status = 'PROCESSING'
    job.logs += "Starting extraction with Gemini...\n"
    job.save()

    try:
        if not configure_gemini():
            raise RuntimeError("Gemini API key not configured.")
            
        file_path = job.file.path
        text = extract_text_from_pdf(file_path)
        job.logs += f"Extracted {len(text)} characters.\n"
        job.save()

        # Simple chunking (Gemini has 1M+ context, but we chunk to extract specific concepts)
        chunks = [text[i:i+60000] for i in range(0, len(text), 60000)]
        
        model = genai.GenerativeModel('gemini-1.5-flash')
        
        all_concepts = []
        for i, chunk in enumerate(chunks[:3]):  # Limit for MVP
            job.logs += f"Processing chunk {i+1}/{len(chunks)}...\n"
            job.save()
            
            response = model.generate_content(
                f"Extract key concepts and main ideas from this book segment. Be concise:\n\n{chunk}"
            )
            all_concepts.append(response.text)

        # Synthesis with JSON mode
        job.logs += "Synthesizing summary...\n"
        job.save()
        
        synthesis_prompt = (
            f"Based on these key concepts: {' '.join(all_concepts)}, generate a book summary. "
            "Output MUST be in valid JSON format with the following keys: "
            "title, subtitle, description, what_you_will_learn (list of strings), "
            "sections (list of objects with 'title' and 'content' keys). "
            "Each section content should be approximately 300 words."
        )
        
        # Use Gemini's JSON response capability
        response = model.generate_content(
            synthesis_prompt,
            generation_config={"response_mime_type": "application/json"}
        )
        
        data = json.loads(response.text)
        
        # Database Population
        author, _ = Author.objects.get_or_create(name="AI Ingestion", defaults={'bio': 'Automatically generated content.'})
        
        # Handle Slug Collision
        base_slug = slugify(data.get('title', 'unknown-title'))
        final_slug = base_slug
        if Book.objects.filter(slug=final_slug).exists():
            final_slug = f"{base_slug}-{uuid.uuid4().hex[:6]}"

        book = Book.objects.create(
            title=data.get('title', 'Unknown Title'),
            subtitle=data.get('subtitle', ''),
            slug=final_slug,
            author=author,
            description=data.get('description', ''),
            what_you_will_learn="\n".join(data.get('what_you_will_learn', [])),
            full_book_pdf=job.file
        )

        # Extract and save cover image from first page of PDF
        try:
            cover_bytes = extract_cover_from_pdf(file_path)
            if cover_bytes:
                book.cover_image.save(f"{book.slug}_cover.png", ContentFile(cover_bytes), save=True)
                job.logs += "Extracted and saved cover image from PDF.\n"
                job.save()
        except Exception as e:
            logger.warning(f"Could not extract cover image for book {book.id}: {e}")
        
        for i, section_data in enumerate(data.get('sections', [])):
            SummarySection.objects.create(
                book=book,
                title=section_data.get('title', f'Section {i+1}'),
                slug=slugify(section_data.get('title', f'section-{i+1}')),
                order=i,
                content=section_data.get('content', ''),
                plain_text=section_data.get('content', '')
            )
        
        job.book = book
        job.status = 'COMPLETED'
        job.logs += "Successfully created book and sections using Gemini.\n"
        job.save()
        
        # Trigger TTS (Phase 2)
        from apps.summaries.tasks import generate_audio_for_book
        generate_audio_for_book.delay(book.id)
        
        # Trigger Vectorization (Phase 3)
        vectorize_book.delay(book.id)

    except Exception as e:
        job.status = 'FAILED'
        job.logs += f"Error: {str(e)}\n"
        job.save()
        logger.error(f"Ingestion failed: {e}", exc_info=True)

@shared_task
def vectorize_book(book_id):
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
