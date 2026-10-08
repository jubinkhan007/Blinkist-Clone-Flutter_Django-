import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/flashcards/domain/flashcard_models.dart';

void main() {
  group('Flashcard Models Unit Tests', () {
    test('QuizOption parses from JSON and serializes to JSON', () {
      final json = {
        'text': 'Design systems that automate desired behavior.',
        'is_correct': true,
        'explanation': 'Systems compound reliably over time.',
      };

      final option = QuizOption.fromJson(json);

      expect(option.text, equals('Design systems that automate desired behavior.'));
      expect(option.isCorrect, isTrue);
      expect(option.explanation, equals('Systems compound reliably over time.'));

      final serialized = option.toJson();
      expect(serialized['text'], equals(json['text']));
      expect(serialized['is_correct'], isTrue);
      expect(serialized['explanation'], equals(json['explanation']));
    });

    test('BookFlashcard parses full JSON payload from backend', () {
      final json = {
        'id': 101,
        'book_id': 5,
        'book_slug': 'atomic-habits',
        'book_title': 'Atomic Habits',
        'book_author': 'James Clear',
        'cover_image_url': 'https://example.com/cover.png',
        'section_id': 20,
        'section_title': 'Make It Obvious',
        'front_prompt': 'What is the most effective cue design technique?',
        'back_answer': 'Implementation intentions specify both time and location.',
        'key_quote': 'Many people think they lack motivation when they really lack clarity.',
        'quiz_options': [
          {
            'text': 'Implementation intentions specifying when and where to act.',
            'is_correct': true,
            'explanation': 'Clear triggers eliminate decision hesitation.',
          },
          {
            'text': 'Waiting until daily mood peaks.',
            'is_correct': false,
            'explanation': 'Mood is unstable.',
          },
        ],
        'order': 1,
        'is_mastered': true,
        'review_status': 'mastered',
        'times_reviewed': 3,
        'last_reviewed_at': '2026-10-08T09:30:00Z',
      };

      final card = BookFlashcard.fromJson(json);

      expect(card.id, equals(101));
      expect(card.bookId, equals(5));
      expect(card.bookSlug, equals('atomic-habits'));
      expect(card.bookTitle, equals('Atomic Habits'));
      expect(card.bookAuthor, equals('James Clear'));
      expect(card.coverImageUrl, equals('https://example.com/cover.png'));
      expect(card.sectionId, equals(20));
      expect(card.sectionTitle, equals('Make It Obvious'));
      expect(card.frontPrompt, equals('What is the most effective cue design technique?'));
      expect(card.backAnswer, equals('Implementation intentions specify both time and location.'));
      expect(card.keyQuote, contains('clarity'));
      expect(card.quizOptions.length, equals(2));
      expect(card.quizOptions.first.isCorrect, isTrue);
      expect(card.order, equals(1));
      expect(card.isMastered, isTrue);
      expect(card.reviewStatus, equals('mastered'));
      expect(card.timesReviewed, equals(3));
      expect(card.lastReviewedAt?.year, equals(2026));
    });

    test('BookFlashcard handles missing or nullable fields safely', () {
      final json = {
        'id': 202,
        'front_prompt': 'Test Prompt',
        'back_answer': 'Test Answer',
      };

      final card = BookFlashcard.fromJson(json);

      expect(card.id, equals(202));
      expect(card.bookId, equals(0));
      expect(card.bookTitle, equals('Unknown Book'));
      expect(card.bookAuthor, equals('Unknown Author'));
      expect(card.coverImageUrl, isNull);
      expect(card.sectionId, isNull);
      expect(card.sectionTitle, isNull);
      expect(card.keyQuote, equals(''));
      expect(card.quizOptions, isEmpty);
      expect(card.order, equals(1));
      expect(card.isMastered, isFalse);
      expect(card.reviewStatus, isNull);
      expect(card.timesReviewed, equals(0));
      expect(card.lastReviewedAt, isNull);
    });

    test('BookFlashcard copyWith updates state correctly', () {
      final original = BookFlashcard(
        id: 1,
        bookId: 1,
        bookSlug: 'deep-work',
        bookTitle: 'Deep Work',
        bookAuthor: 'Cal Newport',
        frontPrompt: 'What is deep work?',
        backAnswer: 'Professional activities performed in a state of distraction-free concentration.',
        keyQuote: '',
        quizOptions: [],
        order: 1,
        isMastered: false,
        timesReviewed: 0,
      );

      final updated = original.copyWith(
        isMastered: true,
        reviewStatus: 'mastered',
        timesReviewed: 1,
        lastReviewedAt: DateTime.parse('2026-10-08T10:00:00Z'),
      );

      expect(updated.isMastered, isTrue);
      expect(updated.reviewStatus, equals('mastered'));
      expect(updated.timesReviewed, equals(1));
      expect(updated.lastReviewedAt, isNotNull);
      expect(updated.frontPrompt, equals(original.frontPrompt));
    });

    test('FlashcardDeck parses deck list and stats correctly', () {
      final json = {
        'book_slug': 'atomic-habits',
        'book_title': 'Atomic Habits',
        'book_author': 'James Clear',
        'cover_image_url': null,
        'total_cards': 3,
        'mastered_count': 2,
        'cards': [
          {
            'id': 1,
            'front_prompt': 'Prompt 1',
            'back_answer': 'Answer 1',
            'is_mastered': true,
          },
          {
            'id': 2,
            'front_prompt': 'Prompt 2',
            'back_answer': 'Answer 2',
            'is_mastered': true,
          },
          {
            'id': 3,
            'front_prompt': 'Prompt 3',
            'back_answer': 'Answer 3',
            'is_mastered': false,
          },
        ],
      };

      final deck = FlashcardDeck.fromJson(json);

      expect(deck.bookSlug, equals('atomic-habits'));
      expect(deck.bookTitle, equals('Atomic Habits'));
      expect(deck.totalCards, equals(3));
      expect(deck.masteredCount, equals(2));
      expect(deck.cards.length, equals(3));
      expect(deck.cards.first.isMastered, isTrue);
      expect(deck.cards.last.isMastered, isFalse);
    });

    test('DailyReviewDeck parses date and cards correctly', () {
      final json = {
        'date': '2026-10-08',
        'total_cards': 3,
        'mastered_today': 1,
        'cards': [
          {
            'id': 10,
            'front_prompt': 'Daily Card 1',
            'back_answer': 'Daily Answer 1',
          },
          {
            'id': 11,
            'front_prompt': 'Daily Card 2',
            'back_answer': 'Daily Answer 2',
          },
        ],
      };

      final dailyDeck = DailyReviewDeck.fromJson(json);

      expect(dailyDeck.date, equals('2026-10-08'));
      expect(dailyDeck.totalCards, equals(3));
      expect(dailyDeck.masteredToday, equals(1));
      expect(dailyDeck.cards.length, equals(2));
    });
  });
}
