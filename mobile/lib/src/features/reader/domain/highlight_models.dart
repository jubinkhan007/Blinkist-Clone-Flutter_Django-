class UserHighlight {
  final int id;
  final int bookId;
  final String bookSlug;
  final String bookTitle;
  final String bookAuthor;
  final String? bookCoverUrl;
  final int? sectionId;
  final String? sectionTitle;
  final int? sectionOrder;
  final String selectedText;
  final String note;
  final String color; // 'yellow', 'green', 'blue', 'pink'
  final DateTime createdAt;

  UserHighlight({
    required this.id,
    required this.bookId,
    required this.bookSlug,
    required this.bookTitle,
    required this.bookAuthor,
    this.bookCoverUrl,
    this.sectionId,
    this.sectionTitle,
    this.sectionOrder,
    required this.selectedText,
    required this.note,
    required this.color,
    required this.createdAt,
  });

  factory UserHighlight.fromJson(Map<String, dynamic> json) {
    final book = json['book'] as Map<String, dynamic>? ?? {};
    final section = json['section'] as Map<String, dynamic>?;

    return UserHighlight(
      id: json['id'],
      bookId: book['id'] ?? 0,
      bookSlug: book['slug'] ?? '',
      bookTitle: book['title'] ?? 'Unknown Book',
      bookAuthor: book['author'] ?? 'Unknown Author',
      bookCoverUrl: book['cover_image_url'],
      sectionId: section?['id'],
      sectionTitle: section?['title'],
      sectionOrder: section?['order'],
      selectedText: json['selected_text'] ?? '',
      note: json['note'] ?? '',
      color: json['color'] ?? 'yellow',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'book_slug': bookSlug,
      'section_id': sectionId,
      'selected_text': selectedText,
      'note': note,
      'color': color,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
