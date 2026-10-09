class Category {
  final int id;
  final String name;
  final String slug;
  final String description;

  Category({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      name: json['name'],
      slug: json['slug'],
      description: json['description'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'slug': slug, 'description': description};
  }
}

class Author {
  final int id;
  final String name;
  final String? bio;
  final String? avatarUrl;

  Author({required this.id, required this.name, this.bio, this.avatarUrl});

  factory Author.fromJson(Map<String, dynamic> json) {
    return Author(
      id: json['id'],
      name: json['name'],
      bio: json['bio'],
      avatarUrl: json['avatar_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'bio': bio, 'avatar_url': avatarUrl};
  }
}

class Book {
  final int id;
  final String title;
  final String subtitle;
  final String slug;
  final Author author;
  final List<Category> categories;
  final String? coverImageUrl;
  final int estimatedReadTimeMinutes;
  final bool isPremium;
  final bool isSaved;
  final bool isDailyFree;
  final double rating;
  final int ratingCount;
  final bool hasAudio;

  Book({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.slug,
    required this.author,
    required this.categories,
    this.coverImageUrl,
    required this.estimatedReadTimeMinutes,
    required this.isPremium,
    required this.isSaved,
    this.isDailyFree = false,
    this.rating = 4.7,
    this.ratingCount = 120,
    this.hasAudio = false,
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
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
      isDailyFree: json['is_daily_free'] ?? false,
      rating: (json['rating'] as num?)?.toDouble() ?? 4.7,
      ratingCount: (json['rating_count'] as num?)?.toInt() ?? 120,
      hasAudio: json['has_audio'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'slug': slug,
      'author': author.toJson(),
      'categories': categories.map((c) => c.toJson()).toList(),
      'cover_image_url': coverImageUrl,
      'estimated_read_time_minutes': estimatedReadTimeMinutes,
      'is_premium': isPremium,
      'is_saved': isSaved,
      'is_daily_free': isDailyFree,
      'rating': rating,
      'rating_count': ratingCount,
      'has_audio': hasAudio,
    };
  }
}

class SearchSuggestion {
  final String type; // 'book', 'author', 'category', 'query'
  final String title;
  final String? subtitle;
  final String? slug;
  final String? author;
  final String? coverImageUrl;
  final double? rating;
  final int? bookCount;

  SearchSuggestion({
    required this.type,
    required this.title,
    this.subtitle,
    this.slug,
    this.author,
    this.coverImageUrl,
    this.rating,
    this.bookCount,
  });

  factory SearchSuggestion.fromJson(Map<String, dynamic> json) {
    return SearchSuggestion(
      type: json['type'] as String? ?? 'query',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
      slug: json['slug'] as String?,
      author: json['author'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      bookCount: (json['book_count'] as num?)?.toInt(),
    );
  }
}

class TrendingSearchItem {
  final String query;
  final String type; // 'book', 'category', 'author', 'query'
  final String badge; // '🔥 Trending', '⚡ Popular', '👤 Top Author'
  final String? slug;

  TrendingSearchItem({
    required this.query,
    this.type = 'query',
    this.badge = '🔥 Trending',
    this.slug,
  });

  factory TrendingSearchItem.fromJson(Map<String, dynamic> json) {
    return TrendingSearchItem(
      query: json['query'] as String? ?? '',
      type: json['type'] as String? ?? 'query',
      badge: json['badge'] as String? ?? '🔥 Trending',
      slug: json['slug'] as String?,
    );
  }
}

