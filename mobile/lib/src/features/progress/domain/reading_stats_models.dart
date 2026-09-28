class UserReadingStats {
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastActiveDate;
  final bool isActiveToday;
  final int totalSectionsRead;
  final int totalBooksCompleted;
  final int totalAudioMinutes;
  final int totalHighlights;
  final List<bool> weeklyActivity; // Mon to Sun

  const UserReadingStats({
    required this.currentStreak,
    required this.longestStreak,
    this.lastActiveDate,
    required this.isActiveToday,
    required this.totalSectionsRead,
    required this.totalBooksCompleted,
    required this.totalAudioMinutes,
    required this.totalHighlights,
    required this.weeklyActivity,
  });

  factory UserReadingStats.fromJson(Map<String, dynamic> json) {
    final activeDateRaw = json['last_active_date'];
    final weeklyRaw = json['weekly_activity'] as List<dynamic>? ?? [];

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
      totalHighlights: (json['total_highlights'] as num?)?.toInt() ?? 0,
      weeklyActivity: weeklyRaw.map((e) => e == true).toList(),
    );
  }

  static UserReadingStats empty() {
    return const UserReadingStats(
      currentStreak: 0,
      longestStreak: 0,
      isActiveToday: false,
      totalSectionsRead: 0,
      totalBooksCompleted: 0,
      totalAudioMinutes: 0,
      totalHighlights: 0,
      weeklyActivity: [false, false, false, false, false, false, false],
    );
  }
}
