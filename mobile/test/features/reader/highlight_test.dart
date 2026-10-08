import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/reader/domain/highlight_models.dart';

void main() {
  group('UserHighlight Model Tests', () {
    test('UserHighlight parses completely from backend JSON response', () {
      final json = {
        'id': 42,
        'book': {
          'id': 10,
          'slug': 'atomic-habits',
          'title': 'Atomic Habits',
          'author': 'James Clear',
          'cover_image_url': 'https://example.com/cover.jpg',
        },
        'section': {
          'id': 105,
          'title': 'The Fundamentals',
          'order': 1,
        },
        'selected_text': 'You do not rise to the level of your goals.',
        'note': 'Key takeaway on system-first thinking.',
        'color': 'pink',
        'created_at': '2026-10-07T12:00:00Z',
      };

      final highlight = UserHighlight.fromJson(json);

      expect(highlight.id, equals(42));
      expect(highlight.bookId, equals(10));
      expect(highlight.bookSlug, equals('atomic-habits'));
      expect(highlight.bookTitle, equals('Atomic Habits'));
      expect(highlight.bookAuthor, equals('James Clear'));
      expect(highlight.bookCoverUrl, equals('https://example.com/cover.jpg'));
      expect(highlight.sectionId, equals(105));
      expect(highlight.sectionTitle, equals('The Fundamentals'));
      expect(highlight.sectionOrder, equals(1));
      expect(
        highlight.selectedText,
        equals('You do not rise to the level of your goals.'),
      );
      expect(highlight.note, equals('Key takeaway on system-first thinking.'));
      expect(highlight.color, equals('pink'));
      expect(highlight.createdAt.year, equals(2026));
    });

    test('UserHighlight defaults safely when optional fields are null or omitted', () {
      final json = {
        'id': 99,
        'selected_text': 'Tiny changes make a remarkable difference.',
      };

      final highlight = UserHighlight.fromJson(json);

      expect(highlight.id, equals(99));
      expect(highlight.bookId, equals(0));
      expect(highlight.bookSlug, equals(''));
      expect(highlight.bookTitle, equals('Unknown Book'));
      expect(highlight.bookAuthor, equals('Unknown Author'));
      expect(highlight.bookCoverUrl, isNull);
      expect(highlight.sectionId, isNull);
      expect(highlight.sectionTitle, isNull);
      expect(highlight.selectedText, equals('Tiny changes make a remarkable difference.'));
      expect(highlight.note, equals(''));
      expect(highlight.color, equals('yellow')); // default color
      expect(highlight.createdAt, isNotNull);
    });

    test('UserHighlight serializes to JSON correctly', () {
      final now = DateTime.parse('2026-10-07T14:30:00Z');
      final highlight = UserHighlight(
        id: 7,
        bookId: 1,
        bookSlug: 'deep-work',
        bookTitle: 'Deep Work',
        bookAuthor: 'Cal Newport',
        sectionId: 12,
        sectionTitle: 'Rule #1',
        selectedText: 'Clarity about what matters provides clarity about what does not.',
        note: 'Crucial for focus sessions.',
        color: 'blue',
        createdAt: now,
      );

      final json = highlight.toJson();

      expect(json['id'], equals(7));
      expect(json['book_slug'], equals('deep-work'));
      expect(json['section_id'], equals(12));
      expect(json['selected_text'], equals('Clarity about what matters provides clarity about what does not.'));
      expect(json['note'], equals('Crucial for focus sessions.'));
      expect(json['color'], equals('blue'));
      expect(json['created_at'], equals(now.toIso8601String()));
    });

    test('Supports all 4 highlight palette colors (yellow, green, blue, pink)', () {
      final colors = ['yellow', 'green', 'blue', 'pink'];
      for (final c in colors) {
        final highlight = UserHighlight.fromJson({
          'id': 1,
          'selected_text': 'Text',
          'color': c,
          'note': 'Note for $c',
        });
        expect(highlight.color, equals(c));
        expect(highlight.note, equals('Note for $c'));
      }
    });
  });
}
