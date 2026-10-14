class ActionPlanItem {
  final int id;
  final int dayNumber;
  final String title;
  final String description;
  final String suggestedHabit;
  final String associatedQuote;
  final bool isCompleted;
  final DateTime? completedAt;

  const ActionPlanItem({
    required this.id,
    required this.dayNumber,
    required this.title,
    required this.description,
    required this.suggestedHabit,
    this.associatedQuote = '',
    this.isCompleted = false,
    this.completedAt,
  });

  factory ActionPlanItem.fromJson(Map<String, dynamic> json) {
    return ActionPlanItem(
      id: json['id'] as int? ?? 0,
      dayNumber: json['day_number'] as int? ?? 1,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      suggestedHabit: json['suggested_habit'] as String? ?? '',
      associatedQuote: json['associated_quote'] as String? ?? '',
      isCompleted: json['is_completed'] as bool? ?? false,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'day_number': dayNumber,
      'title': title,
      'description': description,
      'suggested_habit': suggestedHabit,
      'associated_quote': associatedQuote,
      'is_completed': isCompleted,
      'completed_at': completedAt?.toIso8601String(),
    };
  }

  ActionPlanItem copyWith({
    int? id,
    int? dayNumber,
    String? title,
    String? description,
    String? suggestedHabit,
    String? associatedQuote,
    bool? isCompleted,
    DateTime? completedAt,
  }) {
    return ActionPlanItem(
      id: id ?? this.id,
      dayNumber: dayNumber ?? this.dayNumber,
      title: title ?? this.title,
      description: description ?? this.description,
      suggestedHabit: suggestedHabit ?? this.suggestedHabit,
      associatedQuote: associatedQuote ?? this.associatedQuote,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

class ActionPlan {
  final int id;
  final int bookId;
  final String bookTitle;
  final String bookSlug;
  final String bookAuthor;
  final String bookCoverImageUrl;
  final String title;
  final int durationDays;
  final bool isActive;
  final bool isCompleted;
  final int progressPercent;
  final int completedItemsCount;
  final int totalItemsCount;
  final List<ActionPlanItem> items;
  final DateTime? createdAt;
  final DateTime? completedAt;

  const ActionPlan({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    required this.bookSlug,
    required this.bookAuthor,
    this.bookCoverImageUrl = '',
    required this.title,
    required this.durationDays,
    this.isActive = true,
    this.isCompleted = false,
    this.progressPercent = 0,
    this.completedItemsCount = 0,
    this.totalItemsCount = 0,
    this.items = const [],
    this.createdAt,
    this.completedAt,
  });

  factory ActionPlan.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    final itemsList = rawItems
        .map((e) => ActionPlanItem.fromJson(e as Map<String, dynamic>))
        .toList();

    return ActionPlan(
      id: json['id'] as int? ?? 0,
      bookId: json['book'] as int? ?? 0,
      bookTitle: json['book_title'] as String? ?? '',
      bookSlug: json['book_slug'] as String? ?? '',
      bookAuthor: json['book_author'] as String? ?? '',
      bookCoverImageUrl: json['book_cover_image_url'] as String? ?? '',
      title: json['title'] as String? ?? '',
      durationDays: json['duration_days'] as int? ?? 7,
      isActive: json['is_active'] as bool? ?? true,
      isCompleted: json['is_completed'] as bool? ?? false,
      progressPercent: json['progress_percent'] as int? ?? 0,
      completedItemsCount: json['completed_items_count'] as int? ?? 0,
      totalItemsCount: json['total_items_count'] as int? ?? itemsList.length,
      items: itemsList,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'book': bookId,
      'book_title': bookTitle,
      'book_slug': bookSlug,
      'book_author': bookAuthor,
      'book_cover_image_url': bookCoverImageUrl,
      'title': title,
      'duration_days': durationDays,
      'is_active': isActive,
      'is_completed': isCompleted,
      'progress_percent': progressPercent,
      'completed_items_count': completedItemsCount,
      'total_items_count': totalItemsCount,
      'items': items.map((e) => e.toJson()).toList(),
      'created_at': createdAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }

  ActionPlanItem? get nextPendingItem {
    for (final item in items) {
      if (!item.isCompleted) return item;
    }
    return items.isNotEmpty ? items.first : null;
  }
}

class ActionPlanExportPayload {
  final int planId;
  final String title;
  final String bookTitle;
  final int durationDays;
  final int progressPercent;
  final String markdown;
  final String notionText;
  final String icsContent;

  const ActionPlanExportPayload({
    required this.planId,
    required this.title,
    required this.bookTitle,
    required this.durationDays,
    required this.progressPercent,
    required this.markdown,
    required this.notionText,
    required this.icsContent,
  });

  factory ActionPlanExportPayload.fromJson(Map<String, dynamic> json) {
    return ActionPlanExportPayload(
      planId: json['plan_id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      bookTitle: json['book_title'] as String? ?? '',
      durationDays: json['duration_days'] as int? ?? 7,
      progressPercent: json['progress_percent'] as int? ?? 0,
      markdown: json['markdown'] as String? ?? '',
      notionText: json['notion_text'] as String? ?? '',
      icsContent: json['ics_content'] as String? ?? '',
    );
  }
}
