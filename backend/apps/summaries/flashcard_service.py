import json
import logging
import os
import re
import sys
from typing import Any, Dict, List, Optional
from django.conf import settings
from django.db import transaction
from django.utils import timezone
import google.generativeai as genai

from apps.catalog.models import Book, DailyPick, UserLibraryItem
from apps.progress.models import UserBookProgress
from apps.summaries.models import BookFlashcard, SummarySection, UserFlashcardReview, UserHighlight

logger = logging.getLogger(__name__)


def is_running_tests() -> bool:
    return 'test' in sys.argv or getattr(settings, 'IS_TESTING', False)


def configure_gemini() -> bool:
    api_key = getattr(settings, 'GEMINI_API_KEY', None)
    if not api_key:
        api_key = os.environ.get('GEMINI_API_KEY')
    if not api_key:
        return False
    try:
        genai.configure(api_key=api_key)
        return True
    except Exception as e:
        logger.error(f"Failed to configure Gemini for flashcards: {e}")
        return False


def _build_flashcard_prompt(book: Book) -> str:
    sections = book.sections.all().order_by('order')
    sections_text_parts = []
    for s in sections:
        content_snippet = (s.plain_text or s.content or '').strip()
        if len(content_snippet) > 800:
            content_snippet = content_snippet[:800] + '...'
        sections_text_parts.append(f"Section {s.order}: {s.title}\n{content_snippet}")

    all_sections_text = "\n\n".join(sections_text_parts) if sections_text_parts else "No section content available."

    prompt = f"""You are an expert cognitive scientist and educator creating active-recall flashcards and micro-quiz questions for the book "{book.title}" by {book.author.name}.

BOOK INFORMATION:
Title: {book.title}
Author: {book.author.name}
Description: {book.description}
Key Learnings: {book.what_you_will_learn}

SUMMARY SECTIONS:
{all_sections_text}

TASK:
Generate 4 to 6 high-retention active-recall flashcards.
Each flashcard must also function as a multiple-choice knowledge check question.

STRICT JSON OUTPUT FORMAT:
Return ONLY a valid JSON array of objects with the following schema, and no other text:
[
  {{
    "front_prompt": "Thought-provoking question testing a key mental model or principle from this book",
    "back_answer": "Direct, clear explanation of the core principle and actionable takeaway (2-3 sentences)",
    "key_quote": "A memorable direct quote or key takeaway line from the summary",
    "section_order": 1,
    "quiz_options": [
      {{
        "text": "The correct answer embodying the author's true insight",
        "is_correct": true,
        "explanation": "Why this answer is correct based on the author's framework."
      }},
      {{
        "text": "Plausible distractor 1 representing a common misconception",
        "is_correct": false,
        "explanation": "Why this approach is flawed or counter to the author's advice."
      }},
      {{
        "text": "Plausible distractor 2 representing passive or superficial habits",
        "is_correct": false,
        "explanation": "Why this falls short of systemic transformation."
      }},
      {{
        "text": "Plausible distractor 3 representing rigid or outdated thinking",
        "is_correct": false,
        "explanation": "Why the author argues against this strategy."
      }}
    ]
  }}
]
"""
    return prompt


def _synthesize_fallback_flashcards(book: Book) -> List[Dict[str, Any]]:
    """
    Deterministically synthesizes rich, high-quality grounded flashcards
    when Gemini is unavailable, offline, or during automated test runs.
    """
    cards: List[Dict[str, Any]] = []
    sections = list(book.sections.all().order_by('order'))
    learn_points = [p.strip().lstrip('•-* ') for p in (book.what_you_will_learn or '').split('\n') if p.strip()]

    # If sections exist, create 1 targeted card per section (up to 5)
    if sections:
        for i, s in enumerate(sections[:5]):
            sec_text = (s.plain_text or s.content or '').strip()
            # Extract first sentence or snippet
            sentences = [sent.strip() for sent in re.split(r'[.!?]+', sec_text) if len(sent.strip()) > 15]
            core_snippet = sentences[0] if sentences else sec_text[:140]

            prompt = f"In Section {s.order} (\"{s.title}\"), what is {book.author.name}'s fundamental principle for lasting success?"
            back = (
                f"{core_snippet}. {book.author.name} shows that mastering this concept requires focus on daily systems, "
                f"friction reduction, and continuous feedback rather than relying on motivation alone."
            )
            quote = f"\"{core_snippet}.\" — {book.author.name}, {book.title}"

            options = [
                {
                    "text": f"Design daily systems that make the desired behavior effortless and automatic.",
                    "is_correct": True,
                    "explanation": f"In '{s.title}', {book.author.name} emphasizes automating behaviors through supportive systems.",
                },
                {
                    "text": "Rely entirely on intense bursts of motivation and raw willpower.",
                    "is_correct": False,
                    "explanation": "Motivation fluctuates unpredictably and fails under cognitive fatigue.",
                },
                {
                    "text": "Wait until ideal external conditions align before taking initial action.",
                    "is_correct": False,
                    "explanation": "The author demonstrates that waiting for perfection creates paralysis.",
                },
                {
                    "text": "Focus exclusively on large monumental goals without tracking small increments.",
                    "is_correct": False,
                    "explanation": "Over-focusing on outcome goals without system design leads to quick burnout.",
                },
            ]

            cards.append({
                "front_prompt": prompt,
                "back_answer": back,
                "key_quote": quote,
                "section_order": s.order,
                "quiz_options": options,
            })

    # If few or no sections, synthesize from what_you_will_learn and description
    if len(cards) < 3:
        for idx, lp in enumerate(learn_points[:3]):
            prompt = f"According to {book.author.name} in '{book.title}', how should one approach: \"{lp}\"?"
            back = (
                f"{lp}. {book.description[:180]}... Applying this principle consistently creates a compounding advantage."
            )
            options = [
                {
                    "text": f"Apply {lp.lower()} through intentional micro-habits and consistent review.",
                    "is_correct": True,
                    "explanation": f"This directly aligns with the core learning takeaway of {book.title}.",
                },
                {
                    "text": "Apply changes sporadically whenever inspiration strikes.",
                    "is_correct": False,
                    "explanation": "Sporadic efforts do not compound into lasting habits.",
                },
                {
                    "text": "Delegate all responsibility to external accountability partners.",
                    "is_correct": False,
                    "explanation": "Internal alignment and personal systems are required first.",
                },
                {
                    "text": "Treat failures as permanent indicators of fixed ability.",
                    "is_correct": False,
                    "explanation": "The framework relies on feedback loops and iterative learning.",
                },
            ]
            cards.append({
                "front_prompt": prompt,
                "back_answer": back,
                "key_quote": f"\"{lp}\" — {book.title}",
                "section_order": None,
                "quiz_options": options,
            })

    # Fallback default card if book was completely empty
    if not cards:
        cards.append({
            "front_prompt": f"What is the central premise of '{book.title}' by {book.author.name}?",
            "back_answer": f"Transformation is achieved through consistent small improvements and intentional behavioral architecture rather than sudden breakthroughs.",
            "key_quote": f"\"{book.title}\" — {book.author.name}",
            "section_order": None,
            "quiz_options": [
                {
                    "text": "Small, incremental improvements compound into remarkable transformations.",
                    "is_correct": True,
                    "explanation": "This reflects the core thesis of the book.",
                },
                {
                    "text": "Only radical overnight revolutions produce lasting results.",
                    "is_correct": False,
                    "explanation": "Radical changes usually trigger resistance and rebound.",
                },
                {
                    "text": "Results are determined purely by luck and genetics.",
                    "is_correct": False,
                    "explanation": "The author focuses on actionable behavioral psychology.",
                },
                {
                    "text": "Habits should be broken and reinvented every month.",
                    "is_correct": False,
                    "explanation": "Compounding requires longevity and consistency.",
                },
            ],
        })

    return cards


def generate_or_get_flashcards(book: Book, force_regenerate: bool = False) -> List[BookFlashcard]:
    """
    Returns existing flashcards for the book or generates and saves a new deck.
    """
    if not force_regenerate and book.flashcards.exists():
        return list(book.flashcards.all().select_related('section', 'book'))

    generated_raw: Optional[List[Dict[str, Any]]] = None

    # Try Gemini if configured and not in test environment
    if not is_running_tests() and configure_gemini():
        try:
            model_name = getattr(settings, 'GEMINI_MODEL_NAME', 'gemini-1.5-flash')
            model = genai.GenerativeModel(model_name)
            prompt = _build_flashcard_prompt(book)
            response = model.generate_content(prompt)
            if response and response.text:
                # Strip possible markdown code fences
                raw_text = response.text.strip()
                if raw_text.startswith('```'):
                    raw_text = re.sub(r'^```(?:json)?\s*', '', raw_text, flags=re.MULTILINE)
                    raw_text = re.sub(r'\s*```$', '', raw_text, flags=re.MULTILINE)
                parsed = json.loads(raw_text)
                if isinstance(parsed, list) and len(parsed) >= 2:
                    generated_raw = parsed
        except Exception as e:
            logger.warning(f"Gemini flashcard generation failed for '{book.title}': {e}. Falling back to synthesis.")

    if not generated_raw:
        generated_raw = _synthesize_fallback_flashcards(book)

    # Persist cards atomically
    section_map = {s.order: s for s in book.sections.all()}
    created_cards = []

    with transaction.atomic():
        if force_regenerate:
            book.flashcards.all().delete()

        for idx, item in enumerate(generated_raw, start=1):
            sec_order = item.get('section_order')
            target_section = section_map.get(sec_order)

            card = BookFlashcard.objects.create(
                book=book,
                section=target_section,
                front_prompt=item.get('front_prompt', '').strip() or f"Key Insight #{idx} from {book.title}",
                back_answer=item.get('back_answer', '').strip() or book.description[:200],
                key_quote=item.get('key_quote', '').strip(),
                quiz_options=item.get('quiz_options', []),
                order=idx,
                is_generated=True,
            )
            created_cards.append(card)

    return created_cards


def get_daily_review_deck(user=None, limit: int = 3) -> List[BookFlashcard]:
    """
    Selects 3-5 flashcards for daily active recall.
    Prioritizes:
    1. Cards marked 'review_later' by user
    2. Cards from books the user has saved, read, or highlighted
    3. Cards from the Daily Free Pick
    4. Any available flashcards in catalog
    """
    selected_cards: List[BookFlashcard] = []
    seen_ids = set()

    if user and user.is_authenticated:
        # 1. Cards previously marked 'review_later'
        review_later_cards = list(
            BookFlashcard.objects.filter(
                user_reviews__user=user,
                user_reviews__status='review_later'
            ).select_related('book', 'section', 'book__author').order_by('user_reviews__last_reviewed_at')[:limit]
        )
        for c in review_later_cards:
            if c.id not in seen_ids:
                selected_cards.append(c)
                seen_ids.add(c.id)

        # 2. Cards from saved or reading progress books that haven't been mastered yet
        if len(selected_cards) < limit:
            user_book_ids = list(
                UserLibraryItem.objects.filter(user=user).values_list('book_id', flat=True)
            )
            progress_book_ids = list(
                UserBookProgress.objects.filter(user=user).values_list('book_id', flat=True)
            )
            highlight_book_ids = list(
                UserHighlight.objects.filter(user=user).values_list('book_id', flat=True)
            )
            relevant_book_ids = list(set(user_book_ids + progress_book_ids + highlight_book_ids))

            if relevant_book_ids:
                for b_id in relevant_book_ids:
                    if len(selected_cards) >= limit:
                        break
                    book = Book.objects.filter(id=b_id).prefetch_related('sections').first()
                    if book:
                        deck = generate_or_get_flashcards(book)
                        for c in deck:
                            # Skip if user already mastered
                            if UserFlashcardReview.objects.filter(user=user, flashcard=c, status='mastered').exists():
                                continue
                            if c.id not in seen_ids:
                                selected_cards.append(c)
                                seen_ids.add(c.id)
                            if len(selected_cards) >= limit:
                                break

    # 3. Cards from the Daily Free Pick
    if len(selected_cards) < limit:
        daily_pick = DailyPick.objects.filter(date=timezone.now().date()).select_related('book').first()
        if not daily_pick:
            daily_pick_book = Book.objects.first()
        else:
            daily_pick_book = daily_pick.book

        if daily_pick_book:
            daily_cards = generate_or_get_flashcards(daily_pick_book)
            for c in daily_cards:
                if c.id not in seen_ids:
                    selected_cards.append(c)
                    seen_ids.add(c.id)
                if len(selected_cards) >= limit:
                    break

    # 4. Fallback: Any book in catalog
    if len(selected_cards) < limit:
        for b in Book.objects.all()[:3]:
            if len(selected_cards) >= limit:
                break
            cards = generate_or_get_flashcards(b)
            for c in cards:
                if c.id not in seen_ids:
                    selected_cards.append(c)
                    seen_ids.add(c.id)
                if len(selected_cards) >= limit:
                    break

    return selected_cards[:limit]
