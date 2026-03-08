import random
from django.core.management.base import BaseCommand
from django.utils.text import slugify
from apps.catalog.models import Category, Author, Book

class Command(BaseCommand):
    help = 'Seeds the database with initial dummy catalog data'

    def handle(self, *args, **kwargs):
        self.stdout.write('Seeding data...')
        
        # 1. Categories
        categories = ['Business', 'Personal Development', 'Psychology', 'Science', 'History']
        cat_objs = []
        for cat in categories:
            obj, _ = Category.objects.get_or_create(name=cat, slug=slugify(cat))
            cat_objs.append(obj)
            
        # 2. Authors
        authors = ['James Clear', 'Daniel Kahneman', 'Yuval Noah Harari', 'Brené Brown', 'Walter Isaacson']
        author_objs = []
        for name in authors:
            obj, _ = Author.objects.get_or_create(name=name, bio=f"Bestselling author {name}.")
            author_objs.append(obj)
            
        # 3. Books
        books = [
            ("Atomic Habits", "An Easy & Proven Way to Build Good Habits & Break Bad Ones"),
            ("Thinking, Fast and Slow", "The groundbreaking tour of the mind"),
            ("Sapiens", "A Brief History of Humankind"),
            ("Dare to Lead", "Brave Work. Tough Conversations. Whole Hearts."),
            ("Steve Jobs", "The exclusive biography")
        ]
        
        for i, (title, subtitle) in enumerate(books):
            book, created = Book.objects.get_or_create(
                slug=slugify(title),
                defaults={
                    'title': title,
                    'subtitle': subtitle,
                    'author': author_objs[i],
                    'description': f"This is a placeholder description for {title}.",
                    'cover_image_url': f"https://picsum.photos/seed/{slugify(title)}/400/600",
                    'is_premium': random.choice([True, False])
                }
            )
            if created:
                book.categories.add(cat_objs[i])
                
        self.stdout.write(self.style.SUCCESS('Successfully seeded catalog data'))
