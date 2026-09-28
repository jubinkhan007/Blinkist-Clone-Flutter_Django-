import '../../explore/domain/catalog_models.dart';

class ContinueReadingBook extends Book {
  final double percentComplete;
  final DateTime? lastReadAt;
  final String? currentSectionTitle;
  final String lastMode;

  ContinueReadingBook({
    required super.id,
    required super.title,
    required super.subtitle,
    required super.slug,
    required super.author,
    required super.categories,
    super.coverImageUrl,
    required super.estimatedReadTimeMinutes,
    required super.isPremium,
    required super.isSaved,
    required this.percentComplete,
    required this.lastReadAt,
    required this.currentSectionTitle,
    required this.lastMode,
  });

  factory ContinueReadingBook.fromJson(Map<String, dynamic> json) {
    return ContinueReadingBook(
      id: json['id'],
      title: json['title'],
      subtitle: json['subtitle'] ?? '',
      slug: json['slug'],
      author: Author.fromJson(json['author']),
      categories: (json['categories'] as List)
          .map((c) => Category.fromJson(c))
          .toList(),
      coverImageUrl: json['cover_image_url'],
      estimatedReadTimeMinutes: json['estimated_read_time_minutes'] ?? 15,
      isPremium: json['is_premium'] ?? false,
      isSaved: json['is_saved'] ?? false,
      percentComplete: (json['percent_complete'] as num?)?.toDouble() ?? 0,
      lastReadAt: json['last_read_at'] != null
          ? DateTime.tryParse(json['last_read_at'])
          : null,
      currentSectionTitle: json['current_section_title'],
      lastMode: json['last_mode'] ?? 'read',
    );
  }
}

class HomeMerchandising {
  final Book? dailyPick;
  final List<Book> featured;
  final List<Book> recentlyAdded;
  final List<Book> recommended;
  final List<ContinueReadingBook> continueReading;

  HomeMerchandising({
    this.dailyPick,
    required this.featured,
    required this.recentlyAdded,
    required this.recommended,
    required this.continueReading,
  });

  factory HomeMerchandising.fromJson(Map<String, dynamic> json) {
    return HomeMerchandising(
      dailyPick: json['daily_pick'] != null
          ? Book.fromJson(json['daily_pick'])
          : null,
      featured: (json['featured'] as List)
          .map((i) => Book.fromJson(i))
          .toList(),
      recentlyAdded: (json['recently_added'] as List)
          .map((i) => Book.fromJson(i))
          .toList(),
      recommended: (json['recommended'] as List)
          .map((i) => Book.fromJson(i))
          .toList(),
      continueReading: (json['continue_reading'] as List? ?? [])
          .map((i) => ContinueReadingBook.fromJson(i))
          .toList(),
    );
  }
}
