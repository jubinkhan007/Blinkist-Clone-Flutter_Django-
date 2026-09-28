from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand
from django.utils import timezone
from django.utils.text import slugify

from apps.catalog.models import Author, Book, Category
from apps.summaries.models import SummarySection

User = get_user_model()


AUTHOR_FIXTURES = [
    ('James Clear', 'Writes about habits, behavior change, and sustained improvement.'),
    ('Brené Brown', 'Researcher and storyteller focused on courage, trust, and leadership.'),
    ('Adam Grant', 'Organizational psychologist writing about work, motivation, and creativity.'),
]

CATEGORY_FIXTURES = [
    'Productivity',
    'Psychology',
    'Science',
    'Business',
    'Health',
]

BOOK_FIXTURES = [
    ('Atomic Habits', 'Small habits, remarkable results.', 'James Clear', ['Productivity', 'Health'], True),
    ('Deep Work', 'Focused success in a distracted world.', 'Cal Newport', ['Productivity', 'Business'], True),
    ('Thinking, Fast and Slow', 'Two systems drive the way we think.', 'Daniel Kahneman', ['Psychology', 'Science'], True),
    ('The Power of Habit', 'Why habits exist and how to change them.', 'Charles Duhigg', ['Productivity', 'Psychology'], False),
    ('Essentialism', 'Do less, but better.', 'Greg McKeown', ['Productivity', 'Business'], False),
    ('Why We Sleep', 'Sleep science for better living.', 'Matthew Walker', ['Health', 'Science'], True),
    ('Mindset', 'The new psychology of success.', 'Carol S. Dweck', ['Psychology', 'Business'], False),
    ('Sapiens', 'A brief history of humankind.', 'Yuval Noah Harari', ['Science', 'Health'], True),
    ('The Lean Startup', 'Build products with continuous learning.', 'Eric Ries', ['Business', 'Productivity'], False),
    ('The Courage to Be Disliked', 'A practical philosophy of freedom.', 'Ichiro Kishimi', ['Psychology', 'Health'], False),
]


def _placeholder_section_text(title, index):
    return (
        f'{title} section {index} explores a practical takeaway, a memorable example, '
        'and a short reflection prompt. The content is intentionally demo-friendly so '
        'the app can be browsed, searched, and read end to end without manual setup. '
        'Each section summarizes the core idea, shows how it applies in daily life, '
        'and closes with one concrete action the reader can try immediately.'
    )


class Command(BaseCommand):
    help = 'Seeds the database with a complete demo dataset.'

    def handle(self, *args, **kwargs):
        categories = {}
        for category_name in CATEGORY_FIXTURES:
            category, _ = Category.objects.get_or_create(
                slug=slugify(category_name),
                defaults={'name': category_name, 'description': f'{category_name} books'},
            )
            categories[category_name] = category

        authors = {}
        for name, bio in AUTHOR_FIXTURES:
            author, _ = Author.objects.get_or_create(name=name, defaults={'bio': bio})
            authors[name] = author

        created_books = 0
        for title, subtitle, author_name, category_names, is_premium in BOOK_FIXTURES:
            author = authors.get(author_name)
            if author is None:
                author, _ = Author.objects.get_or_create(name=author_name, defaults={'bio': f'Author of {title}.'})
                authors[author_name] = author

            book, created = Book.objects.get_or_create(
                slug=slugify(title),
                defaults={
                    'title': title,
                    'subtitle': subtitle,
                    'author': author,
                    'description': f'{title} explains the key ideas behind {subtitle.lower()}',
                    'what_you_will_learn': f'You will learn the most important ideas from {title}.',
                    'estimated_read_time_minutes': 15,
                    'is_premium': is_premium,
                },
            )
            book.author = author
            book.subtitle = subtitle
            book.description = book.description or f'{title} demo description.'
            book.what_you_will_learn = book.what_you_will_learn or f'Key ideas from {title}.'
            book.estimated_read_time_minutes = book.estimated_read_time_minutes or 15
            book.is_premium = is_premium
            book.save()
            book.categories.set([categories[name] for name in category_names])

            for index in range(1, 5):
                SummarySection.objects.get_or_create(
                    book=book,
                    slug=f'section-{index}',
                    defaults={
                        'order': index,
                        'title': f'Key idea {index}',
                        'content': _placeholder_section_text(title, index),
                        'plain_text': _placeholder_section_text(title, index),
                        'estimated_read_minutes': 2 + index % 2,
                    },
                )
            created_books += int(created)

        demo_user, _ = User.objects.get_or_create(
            email='demo@blinkist.com',
            defaults={
                'username': 'demo',
                'first_name': 'Demo',
                'last_name': 'User',
                'is_premium': True,
                'subscription_status': User.SubscriptionStatus.ACTIVE,
                'subscription_end_date': timezone.now() + timezone.timedelta(days=365),
            },
        )
        demo_user.username = demo_user.username or 'demo'
        demo_user.first_name = demo_user.first_name or 'Demo'
        demo_user.last_name = demo_user.last_name or 'User'
        demo_user.is_premium = True
        demo_user.subscription_status = User.SubscriptionStatus.ACTIVE
        demo_user.subscription_end_date = timezone.now() + timezone.timedelta(days=365)
        demo_user.set_password('DemoPass123!')
        demo_user.save()

        self.stdout.write(
            self.style.SUCCESS(
                f'Seeded demo data with {len(CATEGORY_FIXTURES)} categories, '
                f'{len(authors)} authors, {len(BOOK_FIXTURES)} books, and demo user {demo_user.email}.'
            )
        )
