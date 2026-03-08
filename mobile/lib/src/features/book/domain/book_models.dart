import '../../explore/domain/catalog_models.dart';

class SummarySection {
  final int id;
  final String slug;
  final int order;
  final String title;
  final int durationSeconds;
  final int estimatedReadMinutes;

  // These fields come from the single section detail call when we build the reader
  final String? content;
  final String? audioUrl;

  SummarySection({
    required this.id,
    required this.slug,
    required this.order,
    required this.title,
    required this.durationSeconds,
    required this.estimatedReadMinutes,
    this.content,
    this.audioUrl,
  });

  factory SummarySection.fromJson(Map<String, dynamic> json) {
    return SummarySection(
      id: json['id'],
      slug: json['slug'],
      order: json['order'],
      title: json['title'],
      durationSeconds: json['duration_seconds'] ?? 0,
      estimatedReadMinutes: json['estimated_read_minutes'] ?? 2,
      content: json['content'],
      audioUrl: json['audio_url'],
    );
  }
}

class BookDetail extends Book {
  final String description;
  final String whatYouWillLearn;
  final List<SummarySection> sections;

  BookDetail({
    required super.id,
    required super.title,
    required super.subtitle,
    required super.slug,
    required super.author,
    required super.categories,
    super.coverImageUrl,
    required super.estimatedReadTimeMinutes,
    required super.isPremium,
    required this.description,
    required this.whatYouWillLearn,
    required this.sections,
  });

  factory BookDetail.fromJson(Map<String, dynamic> json) {
    return BookDetail(
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
      description: json['description'] ?? '',
      whatYouWillLearn: json['what_you_will_learn'] ?? '',
      sections: (json['sections'] as List? ?? [])
          .map((s) => SummarySection.fromJson(s))
          .toList(),
    );
  }
}
