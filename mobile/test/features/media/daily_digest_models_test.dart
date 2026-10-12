import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/media/domain/daily_digest_models.dart';
import 'package:mobile/src/features/reader/presentation/audio_controller.dart';

void main() {
  group('Daily Audio Digest Models', () {
    test('DailyAudioDigestItem parses from json correctly', () {
      final json = {
        'id': 101,
        'order': 1,
        'insight_prompt': 'Insight 1 • Designing Systems Over Goals',
        'book_id': 10,
        'book_title': 'Atomic Habits',
        'book_subtitle': 'An Easy & Proven Way to Build Good Habits',
        'book_slug': 'atomic-habits',
        'author_name': 'James Clear',
        'cover_image_url': '/media/books/covers/atomic.jpg',
        'section_id': 55,
        'section_title': 'The Power of Tiny Changes',
        'section_order': 2,
        'audio_url': '/media/books/audio/atomic_1.mp3',
        'duration_seconds': 195,
      };

      final item = DailyAudioDigestItem.fromJson(json);

      expect(item.id, 101);
      expect(item.order, 1);
      expect(item.insightPrompt, 'Insight 1 • Designing Systems Over Goals');
      expect(item.bookId, 10);
      expect(item.bookTitle, 'Atomic Habits');
      expect(item.bookSlug, 'atomic-habits');
      expect(item.authorName, 'James Clear');
      expect(item.sectionId, 55);
      expect(item.sectionTitle, 'The Power of Tiny Changes');
      expect(item.durationSeconds, 195);
      expect(item.formattedDuration, '3:15');
    });

    test('DailyAudioDigest parses with items and user progress', () {
      final json = {
        'id': 1,
        'date': '2026-10-12',
        'title': 'Daily Blink • Morning Digest',
        'subtitle': '3 transformative ideas to energize your morning',
        'theme': 'Focus, Habits & Mental Agility',
        'total_duration_seconds': 540,
        'formatted_duration': '9 min',
        'items': [
          {
            'id': 1,
            'order': 1,
            'insight_prompt': 'Insight 1',
            'book_id': 1,
            'book_title': 'Atomic Habits',
            'book_slug': 'atomic-habits',
            'author_name': 'James Clear',
            'section_id': 10,
            'section_title': 'Habit Loops',
            'duration_seconds': 180,
          },
          {
            'id': 2,
            'order': 2,
            'insight_prompt': 'Insight 2',
            'book_id': 2,
            'book_title': 'Thinking, Fast and Slow',
            'book_slug': 'thinking-fast-and-slow',
            'author_name': 'Daniel Kahneman',
            'section_id': 20,
            'section_title': 'System 1 vs System 2',
            'duration_seconds': 180,
          },
        ],
        'user_progress': {
          'is_completed': false,
          'current_item_index': 1,
          'current_position_seconds': 45,
          'completed_at': null,
        },
      };

      final digest = DailyAudioDigest.fromJson(json);

      expect(digest.id, 1);
      expect(digest.date, '2026-10-12');
      expect(digest.theme, 'Focus, Habits & Mental Agility');
      expect(digest.items.length, 2);
      expect(digest.isCompleted, false);
      expect(digest.currentTrackIndex, 1);
      expect(digest.currentPositionSeconds, 45);
    });

    test('AudioState preserves and modifies daily digest fields with copyWith', () {
      const state = AudioState();
      expect(state.isDailyDigestMode, false);
      expect(state.activeDigestId, isNull);
      expect(state.dailyDigestTheme, isNull);

      final digestState = state.copyWith(
        isDailyDigestMode: true,
        activeDigestId: 42,
        dailyDigestTheme: 'Focus, Habits & Mental Agility',
      );

      expect(digestState.isDailyDigestMode, true);
      expect(digestState.activeDigestId, 42);
      expect(digestState.dailyDigestTheme, 'Focus, Habits & Mental Agility');

      // Unset / regular book playback clears daily digest mode
      final regularState = digestState.copyWith(
        isDailyDigestMode: false,
        activeDigestId: null,
        dailyDigestTheme: null,
      );

      expect(regularState.isDailyDigestMode, false);
      expect(regularState.activeDigestId, isNull);
      expect(regularState.dailyDigestTheme, isNull);
    });
  });
}
