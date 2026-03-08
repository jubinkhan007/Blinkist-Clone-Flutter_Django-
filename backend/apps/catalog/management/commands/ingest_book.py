import json
import os
import shutil
from django.core.management.base import BaseCommand
from django.conf import settings
from django.utils.text import slugify
from apps.catalog.models import Book, Category, Author
from apps.summaries.models import SummarySection

class Command(BaseCommand):
    help = 'Ingest a book from a structured JSON file and its associated audio files.'

    def add_arguments(self, parser):
        parser.add_argument('json_path', type=str, help='Path to the book JSON file')

    def handle(self, *args, **options):
        json_path = options['json_path']
        
        if not os.path.exists(json_path):
            self.stdout.write(self.style.ERROR(f'File not found: {json_path}'))
            return

        base_dir = os.path.dirname(json_path)

        with open(json_path, 'r', encoding='utf-8') as f:
            data = json.load(f)

        book_data = data.get('book', {})
        overview_data = data.get('overview', {})
        chapters_data = data.get('chapters', [])

        # 1. Author
        author_name = book_data.get('author', 'Unknown Author')
        author, _ = Author.objects.get_or_create(name=author_name)

        # 2. Category (Defaulting since JSON doesn't specify)
        category, _ = Category.objects.get_or_create(
            name='Self-Help', 
            defaults={'slug': 'self-help'}
        )

        # 3. Book
        title = book_data.get('title', 'Untitled')
        slug = book_data.get('slug', slugify(title))
        
        book, created = Book.objects.update_or_create(
            slug=slug,
            defaults={
                'title': title,
                'subtitle': book_data.get('subtitle', ''),
                'author': author,
                'description': book_data.get('description', ''),
                'is_premium': book_data.get('is_premium', True),
                'estimated_read_time_minutes': 3 * len(chapters_data), # Rough estimate
            }
        )
        book.categories.add(category)

        # Ensure media directory for this book exists
        media_book_dir = os.path.join(settings.MEDIA_ROOT, 'books', slug)
        os.makedirs(os.path.join(media_book_dir, 'audio'), exist_ok=True)
        
        # Helper to copy audio and get local URL
        def process_audio(audio_asset_path):
            if not audio_asset_path: return None
            
            # The JSON uses paths like "books/atomic-habits/audio/...". We just need the filename.
            filename = os.path.basename(audio_asset_path)
            
            # Look for the file in the 'audio' subdirectory next to the JSON
            source_audio_path = os.path.join(base_dir, 'audio', filename)
            
            if os.path.exists(source_audio_path):
                dest_path = os.path.join(media_book_dir, 'audio', filename)
                shutil.copy2(source_audio_path, dest_path)
                # Return the relative URL from MEDIA_URL
                return f"{settings.MEDIA_URL}books/{slug}/audio/{filename}"
            else:
                self.stdout.write(self.style.WARNING(f'Audio file missing: {source_audio_path}'))
                return None

        # Helper to process cover image
        def process_cover(cover_asset_path):
            if not cover_asset_path: return None
            filename = os.path.basename(cover_asset_path)
            source_cover_path = os.path.join(base_dir, filename)
            if os.path.exists(source_cover_path):
                dest_path = os.path.join(media_book_dir, filename)
                shutil.copy2(source_cover_path, dest_path)
                return f"{settings.MEDIA_URL}books/{slug}/{filename}"
            return None

        # 3.5 Copy Cover Image
        cover_image_url = process_cover(book_data.get('cover_asset'))
        if cover_image_url:
            book.cover_image_url = cover_image_url
            book.save()


        # 4. Overview Section
        if overview_data:
            audio_url = process_audio(overview_data.get('audio_asset'))
            SummarySection.objects.update_or_create(
                book=book,
                order=0,
                defaults={
                    'slug': 'overview',
                    'title': overview_data.get('title', 'Overview'),
                    'content': overview_data.get('text', ''),
                    'plain_text': overview_data.get('text', ''),
                    'audio_url': audio_url,
                }
            )

        # 5. Chapters
        for i, chapter in enumerate(chapters_data, start=1):
            audio_url = process_audio(chapter.get('audio_asset'))
            SummarySection.objects.update_or_create(
                book=book,
                order=chapter.get('order', i),
                defaults={
                    'slug': chapter.get('slug', slugify(chapter.get('title', f'Chapter {i}'))),
                    'title': chapter.get('title', f'Chapter {i}'),
                    'content': chapter.get('text', ''),
                    'plain_text': chapter.get('text', ''),
                    'audio_url': audio_url,
                }
            )

        self.stdout.write(self.style.SUCCESS(f'Successfully ingested "{title}" with {len(chapters_data)} chapters.'))
