class AudioBookmark {
  final int id;
  final int bookId;
  final String bookSlug;
  final String bookTitle;
  final String bookAuthor;
  final String? bookCoverUrl;
  final int? sectionId;
  final String? sectionTitle;
  final int? sectionOrder;
  final int timestampSeconds;
  final String formattedTimestamp;
  final String title;
  final String note;
  final DateTime createdAt;

  const AudioBookmark({
    required this.id,
    required this.bookId,
    required this.bookSlug,
    required this.bookTitle,
    required this.bookAuthor,
    this.bookCoverUrl,
    this.sectionId,
    this.sectionTitle,
    this.sectionOrder,
    required this.timestampSeconds,
    required this.formattedTimestamp,
    required this.title,
    required this.note,
    required this.createdAt,
  });

  String get displayTimestamp {
    if (formattedTimestamp.isNotEmpty) return formattedTimestamp;
    final minutes = timestampSeconds ~/ 60;
    final seconds = timestampSeconds % 60;
    final hours = minutes ~/ 60;
    if (hours > 0) {
      final remMin = minutes % 60;
      return '$hours:${remMin.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  factory AudioBookmark.fromJson(Map<String, dynamic> json) {
    final book = json['book'] as Map<String, dynamic>? ?? {};
    final section = json['section'] as Map<String, dynamic>?;

    return AudioBookmark(
      id: json['id'] as int? ?? 0,
      bookId: book['id'] as int? ?? 0,
      bookSlug: book['slug'] as String? ?? '',
      bookTitle: book['title'] as String? ?? 'Unknown Book',
      bookAuthor: book['author'] as String? ?? 'Unknown Author',
      bookCoverUrl: book['cover_image_url'] as String?,
      sectionId: section?['id'] as int?,
      sectionTitle: section?['title'] as String?,
      sectionOrder: section?['order'] as int?,
      timestampSeconds: json['timestamp_seconds'] as int? ?? 0,
      formattedTimestamp: json['formatted_timestamp'] as String? ?? '',
      title: json['title'] as String? ?? '',
      note: json['note'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'book_slug': bookSlug,
      'section_id': sectionId,
      'timestamp_seconds': timestampSeconds,
      'title': title,
      'note': note,
    };
  }
}
