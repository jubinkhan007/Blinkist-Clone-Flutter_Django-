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
    );
  }
}
