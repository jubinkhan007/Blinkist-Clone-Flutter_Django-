from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand
from django.utils import timezone
from django.utils.text import slugify

from apps.catalog.models import Author, Book, Category, Collection, CollectionItem
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
    'Leadership',
    'Technology',
]

BOOK_FIXTURES = [
    ('Atomic Habits', 'Small habits, remarkable results.', 'James Clear', ['Productivity', 'Health'], True, 15, 4.9, 1420),
    ('Deep Work', 'Focused success in a distracted world.', 'Cal Newport', ['Productivity', 'Business'], True, 18, 4.8, 980),
    ('Thinking, Fast and Slow', 'Two systems drive the way we think.', 'Daniel Kahneman', ['Psychology', 'Science'], True, 22, 4.7, 1250),
    ('The Power of Habit', 'Why habits exist and how to change them.', 'Charles Duhigg', ['Productivity', 'Psychology'], False, 16, 4.6, 810),
    ('Essentialism', 'Do less, but better.', 'Greg McKeown', ['Productivity', 'Business'], False, 12, 4.8, 730),
    ('Why We Sleep', 'Sleep science for better living.', 'Matthew Walker', ['Health', 'Science'], True, 24, 4.8, 640),
    ('Mindset', 'The new psychology of success.', 'Carol S. Dweck', ['Psychology', 'Business', 'Leadership'], False, 14, 4.7, 590),
    ('Sapiens', 'A brief history of humankind.', 'Yuval Noah Harari', ['Science', 'Health'], True, 25, 4.9, 1850),
    ('The Lean Startup', 'Build products with continuous learning.', 'Eric Ries', ['Business', 'Productivity', 'Technology'], False, 17, 4.6, 920),
    ('The Courage to Be Disliked', 'A practical philosophy of freedom.', 'Ichiro Kishimi', ['Psychology', 'Health'], False, 8, 4.5, 430),
    ('Start with Why', 'How great leaders inspire everyone to take action.', 'Simon Sinek', ['Leadership', 'Business'], True, 9, 4.8, 1100),
    ('Clean Code', 'A handbook of agile software craftsmanship.', 'Robert C. Martin', ['Technology', 'Productivity'], True, 19, 4.7, 670),
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
        for title, subtitle, author_name, category_names, is_premium, duration, rating, rating_count in BOOK_FIXTURES:
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
                    'estimated_read_time_minutes': duration,
                    'is_premium': is_premium,
                    'rating': rating,
                    'rating_count': rating_count,
                },
            )
            book.author = author
            book.subtitle = subtitle
            book.description = book.description or f'{title} demo description.'
            book.what_you_will_learn = book.what_you_will_learn or f'Key ideas from {title}.'
            book.estimated_read_time_minutes = duration
            book.is_premium = is_premium
            book.rating = rating
            book.rating_count = rating_count
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

        # Seed Curated Collections
        col1, _ = Collection.objects.get_or_create(
            slug='7-days-to-peak-productivity',
            defaults={
                'title': '7 Days to Peak Productivity',
                'subtitle': 'Build unbreakable habits, eliminate distraction, and focus deeply.',
                'description': 'A masterclass curriculum designed to transform your daily output. Tackle one high-impact summary per day for one week.',
                'icon': 'bolt',
                'color_hex': '#0284C7',
                'target_duration_days': 7,
                'is_featured': True,
                'order': 1,
            },
        )
        col1_books = [
            ('Atomic Habits', 'Day 1: Design tiny systems that compound into massive results.'),
            ('Deep Work', 'Day 2: Protect 90 minutes of distraction-free focus every morning.'),
            ('Essentialism', 'Day 3: Ruthlessly eliminate non-essential commitments.'),
            ('The Power of Habit', 'Day 4: Decode your daily cues, routines, and reward loops.'),
        ]
        for idx, (title, note) in enumerate(col1_books, start=1):
            b = Book.objects.filter(title=title).first()
            if b:
                CollectionItem.objects.get_or_create(
                    collection=col1,
                    book=b,
                    defaults={'order': idx, 'note': note},
                )

        col2, _ = Collection.objects.get_or_create(
            slug='mental-models-for-leaders',
            defaults={
                'title': 'Mental Models for Leaders',
                'subtitle': 'Sharpen your decision-making and cognitive frameworks.',
                'description': 'How world-class thinkers and founders navigate uncertainty, cognitive biases, and rapid change.',
                'icon': 'psychology',
                'color_hex': '#7C3AED',
                'target_duration_days': 5,
                'is_featured': True,
                'order': 2,
            },
        )
        col2_books = [
            ('Thinking, Fast and Slow', 'Day 1: Recognize System 1 biases and slow down critical decisions.'),
            ('Mindset', 'Day 2: Cultivate growth-oriented persistence across your team.'),
            ('The Lean Startup', 'Day 3: Validate hypotheses through rapid build-measure-learn cycles.'),
        ]
        for idx, (title, note) in enumerate(col2_books, start=1):
            b = Book.objects.filter(title=title).first()
            if b:
                CollectionItem.objects.get_or_create(
                    collection=col2,
                    book=b,
                    defaults={'order': idx, 'note': note},
                )

        self.stdout.write(
            self.style.SUCCESS(
                f'Seeded demo data with {len(CATEGORY_FIXTURES)} categories, '
                f'{len(authors)} authors, {len(BOOK_FIXTURES)} books, 2 curated collections, and demo user {demo_user.email}.'
            )
        )

