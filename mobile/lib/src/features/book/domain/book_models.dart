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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'slug': slug,
      'order': order,
      'title': title,
      'duration_seconds': durationSeconds,
      'estimated_read_minutes': estimatedReadMinutes,
      'content': content,
      'audio_url': audioUrl,
    };
  }

  SummarySection copyWith({
    int? id,
    String? slug,
    int? order,
    String? title,
    int? durationSeconds,
    int? estimatedReadMinutes,
    String? content,
    String? audioUrl,
  }) {
    return SummarySection(
      id: id ?? this.id,
      slug: slug ?? this.slug,
      order: order ?? this.order,
      title: title ?? this.title,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      estimatedReadMinutes: estimatedReadMinutes ?? this.estimatedReadMinutes,
      content: content ?? this.content,
      audioUrl: audioUrl ?? this.audioUrl,
    );
  }
}

class BookDetail extends Book {
  final String description;
  final String whatYouWillLearn;
  final String fullText;
  final String? fullBookPdfUrl;
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
    required this.fullText,
    this.fullBookPdfUrl,
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
      fullText: json['full_text'] ?? '',
      fullBookPdfUrl: json['full_book_pdf_url'],
      sections: (json['sections'] as List? ?? [])
          .map((s) => SummarySection.fromJson(s))
          .toList(),
    );
  }

  BookDetail copyWith({
    int? id,
    String? title,
    String? subtitle,
    String? slug,
    Author? author,
    List<Category>? categories,
    String? coverImageUrl,
    int? estimatedReadTimeMinutes,
    bool? isPremium,
    String? description,
    String? whatYouWillLearn,
    String? fullText,
    String? fullBookPdfUrl,
    List<SummarySection>? sections,
  }) {
    return BookDetail(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      slug: slug ?? this.slug,
      author: author ?? this.author,
      categories: categories ?? this.categories,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      estimatedReadTimeMinutes:
          estimatedReadTimeMinutes ?? this.estimatedReadTimeMinutes,
      isPremium: isPremium ?? this.isPremium,
      description: description ?? this.description,
      whatYouWillLearn: whatYouWillLearn ?? this.whatYouWillLearn,
      fullText: fullText ?? this.fullText,
      fullBookPdfUrl: fullBookPdfUrl ?? this.fullBookPdfUrl,
      sections: sections ?? this.sections,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'slug': slug,
      'author': author.toJson(),
      'categories': categories.map((e) => e.toJson()).toList(),
      'cover_image_url': coverImageUrl,
      'estimated_read_time_minutes': estimatedReadTimeMinutes,
      'is_premium': isPremium,
      'description': description,
      'what_you_will_learn': whatYouWillLearn,
      'full_text': fullText,
      'full_book_pdf_url': fullBookPdfUrl,
      'sections': sections.map((e) => e.toJson()).toList(),
    };
  }
}
