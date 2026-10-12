class DailyDigestProgress {
  final bool isCompleted;
  final int currentItemIndex;
  final int currentPositionSeconds;
  final DateTime? completedAt;
  final DateTime? updatedAt;

  const DailyDigestProgress({
    this.isCompleted = false,
    this.currentItemIndex = 0,
    this.currentPositionSeconds = 0,
    this.completedAt,
    this.updatedAt,
  });

  factory DailyDigestProgress.fromJson(Map<String, dynamic> json) {
    return DailyDigestProgress(
      isCompleted: json['is_completed'] as bool? ?? false,
      currentItemIndex: json['current_item_index'] as int? ?? 0,
      currentPositionSeconds: json['current_position_seconds'] as int? ?? 0,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'is_completed': isCompleted,
      'current_item_index': currentItemIndex,
      'current_position_seconds': currentPositionSeconds,
      'completed_at': completedAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

class DailyAudioDigestItem {
  final int id;
  final int order;
  final String insightPrompt;
  final int bookId;
  final String bookTitle;
  final String bookSubtitle;
  final String bookSlug;
  final String authorName;
  final String? coverImageUrl;
  final int sectionId;
  final String sectionTitle;
  final int sectionOrder;
  final String? audioUrl;
  final int durationSeconds;

  const DailyAudioDigestItem({
    required this.id,
    required this.order,
    required this.insightPrompt,
    required this.bookId,
    required this.bookTitle,
    this.bookSubtitle = '',
    required this.bookSlug,
    required this.authorName,
    this.coverImageUrl,
    required this.sectionId,
    required this.sectionTitle,
    this.sectionOrder = 1,
    this.audioUrl,
    this.durationSeconds = 0,
  });

  factory DailyAudioDigestItem.fromJson(Map<String, dynamic> json) {
    return DailyAudioDigestItem(
      id: json['id'] as int? ?? 0,
      order: json['order'] as int? ?? 1,
      insightPrompt: json['insight_prompt'] as String? ?? 'Key Insight',
      bookId: json['book_id'] as int? ?? 0,
      bookTitle: json['book_title'] as String? ?? '',
      bookSubtitle: json['book_subtitle'] as String? ?? '',
      bookSlug: json['book_slug'] as String? ?? '',
      authorName: json['author_name'] as String? ?? '',
      coverImageUrl: json['cover_image_url'] as String?,
      sectionId: json['section_id'] as int? ?? 0,
      sectionTitle: json['section_title'] as String? ?? '',
      sectionOrder: json['section_order'] as int? ?? 1,
      audioUrl: json['audio_url'] as String?,
      durationSeconds: json['duration_seconds'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order': order,
      'insight_prompt': insightPrompt,
      'book_id': bookId,
      'book_title': bookTitle,
      'book_subtitle': bookSubtitle,
      'book_slug': bookSlug,
      'author_name': authorName,
      'cover_image_url': coverImageUrl,
      'section_id': sectionId,
      'section_title': sectionTitle,
      'section_order': sectionOrder,
      'audio_url': audioUrl,
      'duration_seconds': durationSeconds,
    };
  }

  String get formattedDuration {
    final mins = durationSeconds ~/ 60;
    final secs = durationSeconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }
}

class DailyAudioDigest {
  final int id;
  final String date;
  final String title;
  final String subtitle;
  final String theme;
  final int totalDurationSeconds;
  final String formattedDuration;
  final List<DailyAudioDigestItem> items;
  final DailyDigestProgress? userProgress;

  const DailyAudioDigest({
    required this.id,
    required this.date,
    required this.title,
    required this.subtitle,
    required this.theme,
    required this.totalDurationSeconds,
    required this.formattedDuration,
    required this.items,
    this.userProgress,
  });

  factory DailyAudioDigest.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    final itemsList = rawItems
        .map((item) => DailyAudioDigestItem.fromJson(item as Map<String, dynamic>))
        .toList();

    return DailyAudioDigest(
      id: json['id'] as int? ?? 0,
      date: json['date'] as String? ?? '',
      title: json['title'] as String? ?? 'Daily Blink • Morning Digest',
      subtitle: json['subtitle'] as String? ?? '3 key insights to power your morning',
      theme: json['theme'] as String? ?? 'Focus, Habits & Mental Agility',
      totalDurationSeconds: json['total_duration_seconds'] as int? ?? 0,
      formattedDuration: json['formatted_duration'] as String? ?? '6 min',
      items: itemsList,
      userProgress: json['user_progress'] != null
          ? DailyDigestProgress.fromJson(json['user_progress'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,
      'title': title,
      'subtitle': subtitle,
      'theme': theme,
      'total_duration_seconds': totalDurationSeconds,
      'formatted_duration': formattedDuration,
      'items': items.map((e) => e.toJson()).toList(),
      'user_progress': userProgress?.toJson(),
    };
  }

  bool get isCompleted => userProgress?.isCompleted ?? false;
  int get currentTrackIndex => userProgress?.currentItemIndex ?? 0;
  int get currentPositionSeconds => userProgress?.currentPositionSeconds ?? 0;
}
