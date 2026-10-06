import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/progress/domain/reading_stats_models.dart';

void main() {
  group('ReadingStatsModels Tests', () {
    test('ReadingPeriodStats parses correctly from JSON', () {
      final json = {
        'reading_minutes': 18,
        'audio_minutes': 42,
        'total_minutes': 60,
        'days_active': 5,
        'books_completed': 3,
      };

      final stats = ReadingPeriodStats.fromJson(json);
      expect(stats.readingMinutes, equals(18));
      expect(stats.audioMinutes, equals(42));
      expect(stats.totalMinutes, equals(60));
      expect(stats.daysActive, equals(5));
      expect(stats.booksCompleted, equals(3));
    });

    test('HeatmapDay parses correctly from JSON', () {
      final json = {
        'date': '2026-10-06',
        'day_of_week': 1,
        'reading_minutes': 12,
        'audio_minutes': 15,
        'total_minutes': 27,
        'books_completed': 1,
        'intensity': 3,
        'is_active': true,
      };

      final day = HeatmapDay.fromJson(json);
      expect(day.date.year, equals(2026));
      expect(day.dayOfWeek, equals(1));
      expect(day.readingMinutes, equals(12));
      expect(day.audioMinutes, equals(15));
      expect(day.totalMinutes, equals(27));
      expect(day.booksCompleted, equals(1));
      expect(day.intensity, equals(3));
      expect(day.isActive, isTrue);
    });

    test('UserBadgeItem parses correctly from JSON', () {
      final json = {
        'key': 'streak_7',
        'title': '7-Day Habit Master',
        'description': 'Built an unbreakable 7-day habit.',
        'category': 'streaks',
        'icon': 'military_tech',
        'is_unlocked': true,
        'unlocked_at': '2026-10-06T10:00:00Z',
        'current_progress': 7,
        'target_progress': 7,
        'progress_percent': 1.0,
      };

      final badge = UserBadgeItem.fromJson(json);
      expect(badge.key, equals('streak_7'));
      expect(badge.title, equals('7-Day Habit Master'));
      expect(badge.category, equals('streaks'));
      expect(badge.isUnlocked, isTrue);
      expect(badge.unlockedAt, isNotNull);
      expect(badge.currentProgress, equals(7));
      expect(badge.targetProgress, equals(7));
      expect(badge.progressPercent, equals(1.0));
    });

    test('UserReadingStats parses full aggregated JSON response', () {
      final json = {
        'current_streak': 5,
        'longest_streak': 12,
        'last_active_date': '2026-10-06',
        'is_active_today': true,
        'total_sections_read': 24,
        'total_books_completed': 4,
        'total_audio_minutes': 85,
        'total_reading_minutes': 72,
        'total_highlights': 9,
        'weekly_activity': [true, true, true, false, true, true, false],
        'weekly': {
          'reading_minutes': 15,
          'audio_minutes': 30,
          'total_minutes': 45,
          'days_active': 4,
          'books_completed': 1,
        },
        'monthly': {
          'reading_minutes': 60,
          'audio_minutes': 80,
          'total_minutes': 140,
          'days_active': 10,
          'books_completed': 3,
        },
        'activity_heatmap': [
          {
            'date': '2026-10-06',
            'day_of_week': 1,
            'reading_minutes': 15,
            'audio_minutes': 10,
            'total_minutes': 25,
            'books_completed': 1,
            'intensity': 2,
            'is_active': true,
          }
        ],
        'unlocked_badges_count': 3,
        'total_badges_count': 17,
        'recent_badges': [
          {
            'key': 'first_spark',
            'title': 'First Spark',
            'description': 'Started habit',
            'category': 'streaks',
            'icon': 'local_fire_department',
            'is_unlocked': true,
            'unlocked_at': '2026-10-01T00:00:00Z',
            'current_progress': 1,
            'target_progress': 1,
            'progress_percent': 1.0,
          }
        ],
      };

      final stats = UserReadingStats.fromJson(json);
      expect(stats.currentStreak, equals(5));
      expect(stats.longestStreak, equals(12));
      expect(stats.isActiveToday, isTrue);
      expect(stats.totalBooksCompleted, equals(4));
      expect(stats.totalReadingMinutes, equals(72));
      expect(stats.weekly.totalMinutes, equals(45));
      expect(stats.monthly.totalMinutes, equals(140));
      expect(stats.activityHeatmap.length, equals(1));
      expect(stats.unlockedBadgesCount, equals(3));
      expect(stats.recentBadges.length, equals(1));
    });

    test('UserReadingStats.empty returns safe default metrics', () {
      final empty = UserReadingStats.empty();
      expect(empty.currentStreak, equals(0));
      expect(empty.longestStreak, equals(0));
      expect(empty.isActiveToday, isFalse);
      expect(empty.totalBooksCompleted, equals(0));
      expect(empty.activityHeatmap, isEmpty);
      expect(empty.recentBadges, isEmpty);
    });
  });
}
