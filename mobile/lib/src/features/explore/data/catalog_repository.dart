import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/networking/api_client.dart';
import '../../reader/presentation/reader_options_provider.dart';
import '../domain/catalog_models.dart';

part 'catalog_repository.g.dart';

class CatalogRepository {
  final Dio _dio;

  CatalogRepository({required Dio dio}) : _dio = dio;

  Future<List<Category>> getCategories() async {
    final response = await _dio.get('/catalog/categories/');
    final List data = response.data;
    return data.map((json) => Category.fromJson(json)).toList();
  }

  Future<List<Book>> getBooks({
    String? query,
    String? categorySlug,
    String? bookFormat,
    String? duration,
    String? sortBy,
    int page = 1,
  }) async {
    final Map<String, dynamic> queryParameters = {'page': page};
    if (query != null && query.trim().isNotEmpty) {
      queryParameters['search'] = query.trim();
    }
    if (categorySlug != null && categorySlug.isNotEmpty && categorySlug != 'all') {
      queryParameters['categories__slug'] = categorySlug;
    }
    if (bookFormat != null && bookFormat.isNotEmpty && bookFormat != 'all') {
      queryParameters['book_format'] = bookFormat;
    }
    if (duration != null && duration.isNotEmpty && duration != 'all') {
      queryParameters['duration'] = duration;
    }
    if (sortBy != null && sortBy.isNotEmpty) {
      queryParameters['sort_by'] = sortBy;
    }

    final response = await _dio.get(
      '/catalog/books/',
      queryParameters: queryParameters,
    );

    final dynamic data = response.data;
    final List results = (data is Map && data.containsKey('results'))
        ? data['results']
        : (data is List ? data : []);
    return results.map((json) => Book.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<List<SearchSuggestion>> getSearchSuggestions(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];
    final response = await _dio.get(
      '/catalog/search/suggest/',
      queryParameters: {'q': trimmed},
    );
    final data = response.data;
    final List list = (data is Map && data.containsKey('suggestions'))
        ? data['suggestions']
        : (data is List ? data : []);
    return list
        .map((json) => SearchSuggestion.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<TrendingSearchItem>> getTrendingSearches() async {
    final response = await _dio.get('/catalog/search/trending/');
    final dynamic data = response.data;
    final List list = data is List ? data : [];
    return list
        .map((json) => TrendingSearchItem.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> logSearchQuery(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    try {
      await _dio.post(
        '/catalog/search/log/',
        data: {'query': trimmed},
      );
    } catch (_) {
      // Fire-and-forget log
    }
  }
}

class ExploreFilter {
  final String query;
  final String? categorySlug;
  final String format; // 'all', 'audio', 'text'
  final String duration; // 'all', 'short', 'medium', 'long'
  final String sortBy; // 'popularity', 'newest', 'highest_rated'

  const ExploreFilter({
    this.query = '',
    this.categorySlug,
    this.format = 'all',
    this.duration = 'all',
    this.sortBy = 'popularity',
  });

  bool get hasActiveFilters =>
      (categorySlug != null && categorySlug != 'all') ||
      format != 'all' ||
      duration != 'all' ||
      sortBy != 'popularity' ||
      query.trim().isNotEmpty;

  int get activeFiltersCount {
    int count = 0;
    if (categorySlug != null && categorySlug != 'all') count++;
    if (format != 'all') count++;
    if (duration != 'all') count++;
    if (sortBy != 'popularity') count++;
    return count;
  }

  ExploreFilter copyWith({
    String? query,
    String? categorySlug,
    bool clearCategory = false,
    String? format,
    String? duration,
    String? sortBy,
  }) {
    return ExploreFilter(
      query: query ?? this.query,
      categorySlug: clearCategory ? null : (categorySlug ?? this.categorySlug),
      format: format ?? this.format,
      duration: duration ?? this.duration,
      sortBy: sortBy ?? this.sortBy,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExploreFilter &&
          runtimeType == other.runtimeType &&
          query == other.query &&
          categorySlug == other.categorySlug &&
          format == other.format &&
          duration == other.duration &&
          sortBy == other.sortBy;

  @override
  int get hashCode =>
      query.hashCode ^
      categorySlug.hashCode ^
      format.hashCode ^
      duration.hashCode ^
      sortBy.hashCode;
}

final filteredBooksProvider =
    FutureProvider.family<List<Book>, ExploreFilter>((ref, filter) async {
  return ref.watch(catalogRepositoryProvider).getBooks(
        query: filter.query,
        categorySlug: filter.categorySlug,
        bookFormat: filter.format,
        duration: filter.duration,
        sortBy: filter.sortBy,
      );
});

@riverpod
CatalogRepository catalogRepository(CatalogRepositoryRef ref) {
  final dio = ref.watch(dioProvider);
  return CatalogRepository(dio: dio);
}

@riverpod
Future<List<Category>> categories(CategoriesRef ref) {
  return ref.watch(catalogRepositoryProvider).getCategories();
}

@riverpod
Future<List<Book>> books(BooksRef ref, {String? query, String? categorySlug}) {
  return ref
      .watch(catalogRepositoryProvider)
      .getBooks(query: query, categorySlug: categorySlug);
}

class SearchHistoryNotifier extends StateNotifier<List<String>> {
  SearchHistoryNotifier(this._ref) : super(_load(_ref));

  final Ref _ref;
  static const _key = 'explore_recent_searches';

  static List<String> _load(Ref ref) {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getStringList(_key) ?? <String>[];
  }

  Future<void> add(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      return;
    }

    final next = [
      normalized,
      ...state.where((item) => item.toLowerCase() != normalized.toLowerCase()),
    ].take(10).toList();
    state = next;
    await _ref.read(sharedPreferencesProvider).setStringList(_key, next);
  }

  Future<void> remove(String query) async {
    final normalized = query.trim().toLowerCase();
    final next = state.where((item) => item.trim().toLowerCase() != normalized).toList();
    state = next;
    await _ref.read(sharedPreferencesProvider).setStringList(_key, next);
  }

  Future<void> clear() async {
    state = [];
    await _ref.read(sharedPreferencesProvider).remove(_key);
  }
}

final searchHistoryProvider =
    StateNotifierProvider<SearchHistoryNotifier, List<String>>((ref) {
      return SearchHistoryNotifier(ref);
    });

final trendingSearchesProvider =
    FutureProvider<List<TrendingSearchItem>>((ref) async {
  return ref.watch(catalogRepositoryProvider).getTrendingSearches();
});

final searchSuggestionsProvider =
    FutureProvider.family<List<SearchSuggestion>, String>((ref, query) async {
  return ref.watch(catalogRepositoryProvider).getSearchSuggestions(query);
});

