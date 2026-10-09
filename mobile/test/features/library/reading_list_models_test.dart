import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/routing/deep_link_service.dart';
import 'package:mobile/src/features/library/domain/reading_list_models.dart';

void main() {
  group('Reading List & Spaces Models Tests', () {
    test('UserReadingListItem parses from JSON and serializes to JSON', () {
      final json = {
        'id': 1,
        'book': {
          'id': 10,
          'title': 'Outliers',
          'subtitle': 'The Story of Success',
          'slug': 'outliers',
          'author': {'id': 1, 'name': 'Malcolm Gladwell'},
          'categories': [
            {'id': 2, 'name': 'Psychology', 'slug': 'psychology'}
          ],
          'estimated_read_time_minutes': 15,
          'is_premium': false,
          'is_saved': true,
        },
        'order': 1,
        'note': 'Must-read chapter on the 10,000 hour rule',
        'added_at': '2026-10-08T12:00:00Z',
      };

      final item = UserReadingListItem.fromJson(json);

      expect(item.id, equals(1));
      expect(item.book.slug, equals('outliers'));
      expect(item.book.author.name, equals('Malcolm Gladwell'));
      expect(item.order, equals(1));
      expect(item.note, equals('Must-read chapter on the 10,000 hour rule'));
      expect(item.addedAt, isNotNull);

      final serialized = item.toJson();
      expect(serialized['id'], equals(1));
      expect(serialized['order'], equals(1));
      expect(serialized['note'], equals('Must-read chapter on the 10,000 hour rule'));
    });

    test('UserReadingList parses summary JSON', () {
      final json = {
        'id': 5,
        'title': 'Morning Mindset',
        'description': 'Daily inspiration to start the day right',
        'emoji': '🌅',
        'color_hex': '#10B981',
        'is_public': true,
        'share_token': 'b7c4d5e6-1234-5678-90ab-cdef12345678',
        'owner_id': 2,
        'owner_name': 'Sarah',
        'is_owner': true,
        'items_count': 3,
        'total_estimated_minutes': 45,
        'preview_covers': ['https://example.com/cover1.jpg', 'https://example.com/cover2.jpg'],
        'created_at': '2026-10-01T08:00:00Z',
        'updated_at': '2026-10-08T09:00:00Z',
      };

      final space = UserReadingList.fromJson(json);

      expect(space.id, equals(5));
      expect(space.title, equals('Morning Mindset'));
      expect(space.emoji, equals('🌅'));
      expect(space.colorHex, equals('#10B981'));
      expect(space.isPublic, isTrue);
      expect(space.isOwner, isTrue);
      expect(space.ownerName, equals('Sarah'));
      expect(space.itemsCount, equals(3));
      expect(space.totalEstimatedMinutes, equals(45));
      expect(space.previewCovers.length, equals(2));
      expect(space.items, isEmpty);
    });

    test('UserReadingList parses detail JSON with nested items', () {
      final json = {
        'id': 8,
        'title': 'Tech Leaders',
        'description': 'Essential books for engineering leaders',
        'emoji': '🚀',
        'color_hex': '#3B82F6',
        'is_public': false,
        'share_token': 'aaaa-bbbb-cccc',
        'is_owner': true,
        'items_count': 1,
        'total_estimated_minutes': 20,
        'items': [
          {
            'id': 101,
            'book': {
              'id': 20,
              'title': 'High Output Management',
              'slug': 'high-output-management',
              'author': {'id': 3, 'name': 'Andy Grove'},
              'categories': [],
              'estimated_read_time_minutes': 20,
              'is_premium': true,
              'is_saved': false,
            },
            'order': 1,
            'note': 'Classic management leverage concepts',
          }
        ],
      };

      final space = UserReadingList.fromJson(json);

      expect(space.id, equals(8));
      expect(space.items.length, equals(1));
      expect(space.items.first.book.title, equals('High Output Management'));
      expect(space.items.first.note, equals('Classic management leverage concepts'));
    });

    test('UserReadingList copyWith updates fields correctly', () {
      const space = UserReadingList(
        id: 1,
        title: 'Original Title',
        shareToken: 'token-123',
        emoji: '📚',
        colorHex: '#3B82F6',
      );

      final updated = space.copyWith(
        title: 'Updated Title',
        emoji: '🔥',
        colorHex: '#EF4444',
        isPublic: true,
      );

      expect(updated.id, equals(1));
      expect(updated.title, equals('Updated Title'));
      expect(updated.emoji, equals('🔥'));
      expect(updated.colorHex, equals('#EF4444'));
      expect(updated.isPublic, isTrue);
      expect(updated.shareToken, equals('token-123'));
    });

    test('ReadingListMembership parses book membership and checks IDs', () {
      final json = {
        'book_slug': 'atomic-habits',
        'list_ids': [1, 4, 9],
      };

      final membership = ReadingListMembership.fromJson(json);

      expect(membership.bookSlug, equals('atomic-habits'));
      expect(membership.listIds, equals([1, 4, 9]));
      expect(membership.containsList(1), isTrue);
      expect(membership.containsList(4), isTrue);
      expect(membership.containsList(9), isTrue);
      expect(membership.containsList(2), isFalse);
    });

    test('DeepLinkService handles space links correctly', () {
      expect(
        DeepLinkService.normalize('blinkist://spaces/42'),
        equals('/spaces/42'),
      );
      expect(
        DeepLinkService.normalize('https://blinkist.com/spaces/share/abc-123'),
        equals('/spaces/share/abc-123'),
      );
      expect(
        DeepLinkService.normalize('https://www.blinkist.com/library?tab=spaces'),
        equals('/library?tab=spaces'),
      );
    });
  });
}
