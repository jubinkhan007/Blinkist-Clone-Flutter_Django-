class QuizOption {
  final String text;
  final bool isCorrect;
  final String explanation;

  QuizOption({
    required this.text,
    required this.isCorrect,
    required this.explanation,
  });

  factory QuizOption.fromJson(Map<String, dynamic> json) {
    return QuizOption(
      text: json['text'] ?? '',
      isCorrect: json['is_correct'] ?? false,
      explanation: json['explanation'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'is_correct': isCorrect,
      'explanation': explanation,
    };
  }
}

class BookFlashcard {
  final int id;
  final int bookId;
  final String bookSlug;
  final String bookTitle;
  final String bookAuthor;
  final String? coverImageUrl;
  final int? sectionId;
  final String? sectionTitle;
  final String frontPrompt;
  final String backAnswer;
  final String keyQuote;
  final List<QuizOption> quizOptions;
  final int order;
  final bool isMastered;
  final String? reviewStatus;
  final int timesReviewed;
  final DateTime? lastReviewedAt;

  BookFlashcard({
    required this.id,
    required this.bookId,
    required this.bookSlug,
    required this.bookTitle,
    required this.bookAuthor,
    this.coverImageUrl,
    this.sectionId,
    this.sectionTitle,
    required this.frontPrompt,
    required this.backAnswer,
    required this.keyQuote,
    required this.quizOptions,
    required this.order,
    this.isMastered = false,
    this.reviewStatus,
    this.timesReviewed = 0,
    this.lastReviewedAt,
  });

  factory BookFlashcard.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['quiz_options'] as List? ?? [];
    return BookFlashcard(
      id: json['id'],
      bookId: json['book_id'] ?? 0,
      bookSlug: json['book_slug'] ?? '',
      bookTitle: json['book_title'] ?? 'Unknown Book',
      bookAuthor: json['book_author'] ?? 'Unknown Author',
      coverImageUrl: json['cover_image_url'],
      sectionId: json['section_id'],
      sectionTitle: json['section_title'],
      frontPrompt: json['front_prompt'] ?? '',
      backAnswer: json['back_answer'] ?? '',
      keyQuote: json['key_quote'] ?? '',
      quizOptions: rawOptions
          .map((o) => QuizOption.fromJson(o as Map<String, dynamic>))
          .toList(),
      order: json['order'] ?? 1,
      isMastered: json['is_mastered'] ?? false,
      reviewStatus: json['review_status'],
      timesReviewed: json['times_reviewed'] ?? 0,
      lastReviewedAt: json['last_reviewed_at'] != null
          ? DateTime.tryParse(json['last_reviewed_at'])
          : null,
    );
  }

  BookFlashcard copyWith({
    bool? isMastered,
    String? reviewStatus,
    int? timesReviewed,
    DateTime? lastReviewedAt,
  }) {
    return BookFlashcard(
      id: id,
      bookId: bookId,
      bookSlug: bookSlug,
      bookTitle: bookTitle,
      bookAuthor: bookAuthor,
      coverImageUrl: coverImageUrl,
      sectionId: sectionId,
      sectionTitle: sectionTitle,
      frontPrompt: frontPrompt,
      backAnswer: backAnswer,
      keyQuote: keyQuote,
      quizOptions: quizOptions,
      order: order,
      isMastered: isMastered ?? this.isMastered,
      reviewStatus: reviewStatus ?? this.reviewStatus,
      timesReviewed: timesReviewed ?? this.timesReviewed,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
    );
  }
}

class FlashcardDeck {
  final String bookSlug;
  final String bookTitle;
  final String bookAuthor;
  final String? coverImageUrl;
  final int totalCards;
  final int masteredCount;
  final List<BookFlashcard> cards;

  FlashcardDeck({
    required this.bookSlug,
    required this.bookTitle,
    required this.bookAuthor,
    this.coverImageUrl,
    required this.totalCards,
    required this.masteredCount,
    required this.cards,
  });

  factory FlashcardDeck.fromJson(Map<String, dynamic> json) {
    final rawCards = json['cards'] as List? ?? [];
    return FlashcardDeck(
      bookSlug: json['book_slug'] ?? '',
      bookTitle: json['book_title'] ?? '',
      bookAuthor: json['book_author'] ?? '',
      coverImageUrl: json['cover_image_url'],
      totalCards: json['total_cards'] ?? rawCards.length,
      masteredCount: json['mastered_count'] ?? 0,
      cards: rawCards
          .map((c) => BookFlashcard.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}

class DailyReviewDeck {
  final String date;
  final int totalCards;
  final int masteredToday;
  final List<BookFlashcard> cards;

  DailyReviewDeck({
    required this.date,
    required this.totalCards,
    required this.masteredToday,
    required this.cards,
  });

  factory DailyReviewDeck.fromJson(Map<String, dynamic> json) {
    final rawCards = json['cards'] as List? ?? [];
    return DailyReviewDeck(
      date: json['date'] ?? '',
      totalCards: json['total_cards'] ?? rawCards.length,
      masteredToday: json['mastered_today'] ?? 0,
      cards: rawCards
          .map((c) => BookFlashcard.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}
