class ReadingPeriodStats {
  final int readingMinutes;
  final int audioMinutes;
  final int totalMinutes;
  final int daysActive;
  final int booksCompleted;

  const ReadingPeriodStats({
    required this.readingMinutes,
    required this.audioMinutes,
    required this.totalMinutes,
    required this.daysActive,
    required this.booksCompleted,
  });

  factory ReadingPeriodStats.fromJson(Map<String, dynamic>? json) {
    if (json == null) return ReadingPeriodStats.empty();
    return ReadingPeriodStats(
      readingMinutes: (json['reading_minutes'] as num?)?.toInt() ?? 0,
      audioMinutes: (json['audio_minutes'] as num?)?.toInt() ?? 0,
      totalMinutes: (json['total_minutes'] as num?)?.toInt() ?? 0,
      daysActive: (json['days_active'] as num?)?.toInt() ?? 0,
      booksCompleted: (json['books_completed'] as num?)?.toInt() ?? 0,
    );
  }

  static ReadingPeriodStats empty() {
    return const ReadingPeriodStats(
      readingMinutes: 0,
      audioMinutes: 0,
      totalMinutes: 0,
      daysActive: 0,
      booksCompleted: 0,
    );
  }
}

class HeatmapDay {
  final DateTime date;
  final int dayOfWeek; // 0 = Mon, 6 = Sun
  final int readingMinutes;
  final int audioMinutes;
  final int totalMinutes;
  final int booksCompleted;
  final int intensity; // 0..3
  final bool isActive;

  const HeatmapDay({
    required this.date,
    required this.dayOfWeek,
    required this.readingMinutes,
    required this.audioMinutes,
    required this.totalMinutes,
    required this.booksCompleted,
    required this.intensity,
    required this.isActive,
  });

  factory HeatmapDay.fromJson(Map<String, dynamic> json) {
    return HeatmapDay(
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      dayOfWeek: (json['day_of_week'] as num?)?.toInt() ?? 0,
      readingMinutes: (json['reading_minutes'] as num?)?.toInt() ?? 0,
      audioMinutes: (json['audio_minutes'] as num?)?.toInt() ?? 0,
      totalMinutes: (json['total_minutes'] as num?)?.toInt() ?? 0,
      booksCompleted: (json['books_completed'] as num?)?.toInt() ?? 0,
      intensity: (json['intensity'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] == true,
    );
  }
}

class UserBadgeItem {
  final String key;
  final String title;
  final String description;
  final String category;
  final String icon;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final int currentProgress;
  final int targetProgress;
  final double progressPercent;

  const UserBadgeItem({
    required this.key,
    required this.title,
    required this.description,
    required this.category,
    required this.icon,
    required this.isUnlocked,
    this.unlockedAt,
    required this.currentProgress,
    required this.targetProgress,
    required this.progressPercent,
  });

  factory UserBadgeItem.fromJson(Map<String, dynamic> json) {
    final unlockedAtRaw = json['unlocked_at'];
    return UserBadgeItem(
      key: json['key'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'streaks',
      icon: json['icon'] as String? ?? 'star',
      isUnlocked: json['is_unlocked'] == true,
      unlockedAt: unlockedAtRaw is String ? DateTime.tryParse(unlockedAtRaw) : null,
      currentProgress: (json['current_progress'] as num?)?.toInt() ?? 0,
      targetProgress: (json['target_progress'] as num?)?.toInt() ?? 1,
      progressPercent: (json['progress_percent'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class UserReadingStats {
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastActiveDate;
  final bool isActiveToday;
  final int totalSectionsRead;
  final int totalBooksCompleted;
  final int totalAudioMinutes;
  final int totalReadingMinutes;
  final int totalHighlights;
  final List<bool> weeklyActivity; // Mon to Sun
  final ReadingPeriodStats weekly;
  final ReadingPeriodStats monthly;
  final List<HeatmapDay> activityHeatmap;
  final int unlockedBadgesCount;
  final int totalBadgesCount;
  final List<UserBadgeItem> recentBadges;

  const UserReadingStats({
    required this.currentStreak,
    required this.longestStreak,
    this.lastActiveDate,
    required this.isActiveToday,
    required this.totalSectionsRead,
    required this.totalBooksCompleted,
    required this.totalAudioMinutes,
    required this.totalReadingMinutes,
    required this.totalHighlights,
    required this.weeklyActivity,
    required this.weekly,
    required this.monthly,
    required this.activityHeatmap,
    required this.unlockedBadgesCount,
    required this.totalBadgesCount,
    required this.recentBadges,
  });

  factory UserReadingStats.fromJson(Map<String, dynamic> json) {
    final activeDateRaw = json['last_active_date'];
    final weeklyRaw = json['weekly_activity'] as List<dynamic>? ?? [];
    final heatmapRaw = json['activity_heatmap'] as List<dynamic>? ?? [];
    final badgesRaw = json['recent_badges'] as List<dynamic>? ?? [];

    return UserReadingStats(
      currentStreak: (json['current_streak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longest_streak'] as num?)?.toInt() ?? 0,
      lastActiveDate: activeDateRaw is String
          ? DateTime.tryParse(activeDateRaw)
          : null,
      isActiveToday: json['is_active_today'] == true,
      totalSectionsRead: (json['total_sections_read'] as num?)?.toInt() ?? 0,
      totalBooksCompleted: (json['total_books_completed'] as num?)?.toInt() ?? 0,
      totalAudioMinutes: (json['total_audio_minutes'] as num?)?.toInt() ?? 0,
      totalReadingMinutes: (json['total_reading_minutes'] as num?)?.toInt() ?? 0,
      totalHighlights: (json['total_highlights'] as num?)?.toInt() ?? 0,
      weeklyActivity: weeklyRaw.map((e) => e == true).toList(),
      weekly: ReadingPeriodStats.fromJson(json['weekly'] as Map<String, dynamic>?),
      monthly: ReadingPeriodStats.fromJson(json['monthly'] as Map<String, dynamic>?),
      activityHeatmap: heatmapRaw
          .whereType<Map<String, dynamic>>()
          .map((e) => HeatmapDay.fromJson(e))
          .toList(),
      unlockedBadgesCount: (json['unlocked_badges_count'] as num?)?.toInt() ?? 0,
      totalBadgesCount: (json['total_badges_count'] as num?)?.toInt() ?? 0,
      recentBadges: badgesRaw
          .whereType<Map<String, dynamic>>()
          .map((e) => UserBadgeItem.fromJson(e))
          .toList(),
    );
  }

  static UserReadingStats empty() {
    return UserReadingStats(
      currentStreak: 0,
      longestStreak: 0,
      isActiveToday: false,
      totalSectionsRead: 0,
      totalBooksCompleted: 0,
      totalAudioMinutes: 0,
      totalReadingMinutes: 0,
      totalHighlights: 0,
      weeklyActivity: const [false, false, false, false, false, false, false],
      weekly: ReadingPeriodStats.empty(),
      monthly: ReadingPeriodStats.empty(),
      activityHeatmap: const [],
      unlockedBadgesCount: 0,
      totalBadgesCount: 0,
      recentBadges: const [],
    );
  }
}
