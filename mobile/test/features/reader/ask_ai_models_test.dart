import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/book/domain/book_models.dart';

void main() {
  group('Ask AI Models Unit Tests', () {
    test('SectionCitation parses from JSON and serializes to JSON', () {
      final json = {
        'order': 1,
        'title': 'The Fundamentals',
        'slug': 'the-fundamentals',
        'id': 10,
      };

      final citation = SectionCitation.fromJson(json);

      expect(citation.order, equals(1));
      expect(citation.title, equals('The Fundamentals'));
      expect(citation.slug, equals('the-fundamentals'));
      expect(citation.id, equals(10));

      final serialized = citation.toJson();
      expect(serialized['order'], equals(1));
      expect(serialized['title'], equals('The Fundamentals'));
      expect(serialized['slug'], equals('the-fundamentals'));
      expect(serialized['id'], equals(10));
    });

    test('AskAiResponse parses JSON with citations and suggested followups', () {
      final json = {
        'answer': 'Here are 3 practical action steps: [Section 1: The Fundamentals]',
        'book_title': 'Atomic Habits',
        'section_title': 'The Fundamentals',
        'suggested_followups': [
          '⚡ 3 Practical action steps',
          '👶 Explain like I\'m 5',
          '📋 Execution checklist',
        ],
        'citations': [
          {
            'order': 1,
            'title': 'The Fundamentals',
            'slug': 'the-fundamentals',
            'id': 10,
          },
        ],
      };

      final response = AskAiResponse.fromJson(json);

      expect(response.answer, contains('Here are 3 practical action steps'));
      expect(response.bookTitle, equals('Atomic Habits'));
      expect(response.sectionTitle, equals('The Fundamentals'));
      expect(response.suggestedFollowups.length, equals(3));
      expect(response.suggestedFollowups.first, equals('⚡ 3 Practical action steps'));
      expect(response.citations.length, equals(1));
      expect(response.citations.first.order, equals(1));
      expect(response.citations.first.title, equals('The Fundamentals'));
    });

    test('AskAiResponse handles missing or null citations gracefully', () {
      final json = {
        'answer': 'Direct answer without citations.',
      };

      final response = AskAiResponse.fromJson(json);

      expect(response.answer, equals('Direct answer without citations.'));
      expect(response.bookTitle, equals(''));
      expect(response.sectionTitle, isNull);
      expect(response.citations, isEmpty);
      expect(response.suggestedFollowups, isEmpty);
    });

    test('AskAiMessage preserves citations and prompt metadata', () {
      final citation = const SectionCitation(
        order: 2,
        title: 'The 1st Law: Make It Obvious',
        slug: 'make-it-obvious',
        id: 11,
      );

      final message = AskAiMessage(
        id: 'msg-1',
        text: 'Habits are the compound interest of self-improvement.',
        isUser: false,
        timestamp: DateTime(2026, 10, 13, 10, 0),
        suggestedFollowups: const ['Give me an example'],
        referencedSection: 'Make It Obvious',
        citations: [citation],
      );

      expect(message.id, equals('msg-1'));
      expect(message.isUser, isFalse);
      expect(message.citations.length, equals(1));
      expect(message.citations.first.order, equals(2));
      expect(message.citations.first.title, equals('The 1st Law: Make It Obvious'));
      expect(message.referencedSection, equals('Make It Obvious'));
    });
  });
}
