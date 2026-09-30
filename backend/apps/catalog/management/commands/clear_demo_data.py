from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand
from django.utils.text import slugify

from apps.catalog.models import Author, Book, Category, Collection

User = get_user_model()


DEMO_EMAIL = 'demo@blinkist.com'
DEMO_CATEGORY_SLUGS = {
    slugify(name)
    for name in ['Productivity', 'Psychology', 'Science', 'Business', 'Health']
}
DEMO_BOOK_SLUGS = {
    slugify(title)
    for title in [
        'Atomic Habits',
        'Deep Work',
        'Thinking, Fast and Slow',
        'The Power of Habit',
        'Essentialism',
        'Why We Sleep',
        'Mindset',
        'Sapiens',
        'The Lean Startup',
        'The Courage to Be Disliked',
    ]
}


class Command(BaseCommand):
    help = 'Removes demo content without deleting unrelated user data.'

    def handle(self, *args, **kwargs):
        deleted_books, _ = Book.objects.filter(slug__in=DEMO_BOOK_SLUGS).delete()
        deleted_categories, _ = Category.objects.filter(slug__in=DEMO_CATEGORY_SLUGS).delete()
        Collection.objects.filter(slug__in=['7-days-to-peak-productivity', 'mental-models-for-leaders']).delete()
        User.objects.filter(email=DEMO_EMAIL).delete()
        Author.objects.filter(books__isnull=True).delete()

        self.stdout.write(
            self.style.SUCCESS(
                f'Cleared demo data. Deleted {deleted_books} book rows and {deleted_categories} category rows.'
            )
        )
