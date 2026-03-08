import '../../explore/domain/catalog_models.dart';

class HomeMerchandising {
  final List<Book> featured;
  final List<Book> recentlyAdded;
  final List<Book> recommended;
  final List<dynamic> continueReading;

  HomeMerchandising({
    required this.featured,
    required this.recentlyAdded,
    required this.recommended,
    required this.continueReading,
  });

  factory HomeMerchandising.fromJson(Map<String, dynamic> json) {
    return HomeMerchandising(
      featured: (json['featured'] as List)
          .map((i) => Book.fromJson(i))
          .toList(),
      recentlyAdded: (json['recently_added'] as List)
          .map((i) => Book.fromJson(i))
          .toList(),
      recommended: (json['recommended'] as List)
          .map((i) => Book.fromJson(i))
          .toList(),
      continueReading: json['continue_reading'] ?? [],
    );
  }
}
