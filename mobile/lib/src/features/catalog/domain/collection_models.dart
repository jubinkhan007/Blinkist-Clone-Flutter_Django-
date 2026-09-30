import '../../explore/domain/catalog_models.dart';

class CollectionPreviewBook {
  final int id;
  final String title;
  final String? coverImageUrl;

  CollectionPreviewBook({
    required this.id,
    required this.title,
    this.coverImageUrl,
  });

  factory CollectionPreviewBook.fromJson(Map<String, dynamic> json) {
    return CollectionPreviewBook(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      coverImageUrl: json['cover_image_url'],
    );
  }
}

class CollectionOverview {
  final int id;
  final String title;
  final String subtitle;
  final String slug;
  final String description;
  final String? bannerImageUrl;
  final String icon;
  final String colorHex;
  final int targetDurationDays;
  final bool isFeatured;
  final int booksCount;
  final int totalEstimatedMinutes;
  final List<CollectionPreviewBook> previewBooks;

  CollectionOverview({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.slug,
    required this.description,
    this.bannerImageUrl,
    required this.icon,
    required this.colorHex,
    required this.targetDurationDays,
    required this.isFeatured,
    required this.booksCount,
    required this.totalEstimatedMinutes,
    required this.previewBooks,
  });

  factory CollectionOverview.fromJson(Map<String, dynamic> json) {
    return CollectionOverview(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      slug: json['slug'] ?? '',
      description: json['description'] ?? '',
      bannerImageUrl: json['banner_image_url'],
      icon: json['icon'] ?? 'auto_stories',
      colorHex: json['color_hex'] ?? '#0284C7',
      targetDurationDays: json['target_duration_days'] ?? 7,
      isFeatured: json['is_featured'] ?? true,
      booksCount: json['books_count'] ?? 0,
      totalEstimatedMinutes: json['total_estimated_minutes'] ?? 0,
      previewBooks: (json['preview_books'] as List? ?? [])
          .map(
            (item) =>
                CollectionPreviewBook.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class CollectionItem {
  final int id;
  final int order;
  final String note;
  final Book book;
  final bool isCompleted;

  CollectionItem({
    required this.id,
    required this.order,
    required this.note,
    required this.book,
    required this.isCompleted,
  });

  factory CollectionItem.fromJson(Map<String, dynamic> json) {
    return CollectionItem(
      id: json['id'] ?? 0,
      order: json['order'] ?? 0,
      note: json['note'] ?? '',
      book: Book.fromJson(json['book']),
      isCompleted: json['is_completed'] ?? false,
    );
  }
}

class CollectionDetail {
  final int id;
  final String title;
  final String subtitle;
  final String slug;
  final String description;
  final String? bannerImageUrl;
  final String icon;
  final String colorHex;
  final int targetDurationDays;
  final int booksCount;
  final int totalEstimatedMinutes;
  final int completedBooksCount;
  final double progressPercent;
  final List<CollectionItem> items;

  CollectionDetail({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.slug,
    required this.description,
    this.bannerImageUrl,
    required this.icon,
    required this.colorHex,
    required this.targetDurationDays,
    required this.booksCount,
    required this.totalEstimatedMinutes,
    required this.completedBooksCount,
    required this.progressPercent,
    required this.items,
  });

  factory CollectionDetail.fromJson(Map<String, dynamic> json) {
    return CollectionDetail(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      slug: json['slug'] ?? '',
      description: json['description'] ?? '',
      bannerImageUrl: json['banner_image_url'],
      icon: json['icon'] ?? 'auto_stories',
      colorHex: json['color_hex'] ?? '#0284C7',
      targetDurationDays: json['target_duration_days'] ?? 7,
      booksCount: json['books_count'] ?? 0,
      totalEstimatedMinutes: json['total_estimated_minutes'] ?? 0,
      completedBooksCount: json['completed_books_count'] ?? 0,
      progressPercent: (json['progress_percent'] as num?)?.toDouble() ?? 0.0,
      items: (json['items'] as List? ?? [])
          .map((item) => CollectionItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
