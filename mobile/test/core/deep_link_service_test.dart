import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/routing/deep_link_service.dart';

void main() {
  group('DeepLinkService URI normalization', () {
    test('normalizes custom scheme 2-slash format', () {
      expect(
        DeepLinkService.normalize('blinkist://books/atomic-habits'),
        equals('/books/atomic-habits'),
      );
    });

    test('normalizes custom scheme 3-slash format', () {
      expect(
        DeepLinkService.normalize('blinkist:///books/atomic-habits'),
        equals('/books/atomic-habits'),
      );
    });

    test('normalizes audio seek query parameters', () {
      expect(
        DeepLinkService.normalize('blinkist://books/deep-work/listen?section=1&pos=45'),
        equals('/books/deep-work/listen?section=1&pos=45'),
      );
    });

    test('normalizes curated collections route', () {
      expect(
        DeepLinkService.normalize('blinkist://collections/productivity-masterclass'),
        equals('/collections/productivity-masterclass'),
      );
    });

    test('normalizes library tab query parameter', () {
      expect(
        DeepLinkService.normalize('blinkist://library?tab=notebook'),
        equals('/library?tab=notebook'),
      );
      expect(
        DeepLinkService.normalize('blinkist://library?tab=downloads'),
        equals('/library?tab=downloads'),
      );
    });

    test('normalizes explore search and category query parameters', () {
      expect(
        DeepLinkService.normalize('blinkist://explore?category=business&search=habits'),
        equals('/explore?category=business&search=habits'),
      );
    });

    test('normalizes universal https web links', () {
      expect(
        DeepLinkService.normalize('https://blinkist.com/books/atomic-habits/read'),
        equals('/books/atomic-habits/read'),
      );
      expect(
        DeepLinkService.normalize('https://www.blinkist.com/collections/leaders?sort=top'),
        equals('/collections/leaders?sort=top'),
      );
    });

    test('normalizes relative paths', () {
      expect(
        DeepLinkService.normalize('/books/atomic-habits'),
        equals('/books/atomic-habits'),
      );
      expect(
        DeepLinkService.normalize('books/atomic-habits'),
        equals('/books/atomic-habits'),
      );
    });

    test('handles empty or whitespace strings safely', () {
      expect(DeepLinkService.normalize(''), equals('/'));
      expect(DeepLinkService.normalize('   '), equals('/'));
    });
  });
}
