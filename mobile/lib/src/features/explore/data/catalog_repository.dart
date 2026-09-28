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
    int page = 1,
  }) async {
    final Map<String, dynamic> queryParameters = {'page': page};
    if (query != null && query.isNotEmpty) {
      queryParameters['search'] = query;
    }
    if (categorySlug != null) {
      queryParameters['categories__slug'] = categorySlug;
    }

    final response = await _dio.get(
      '/catalog/books/',
      queryParameters: queryParameters,
    );

    final List data = response.data['results'];
    return data.map((json) => Book.fromJson(json)).toList();
  }
}

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

  Future<void> clear() async {
    state = [];
    await _ref.read(sharedPreferencesProvider).remove(_key);
  }
}

final searchHistoryProvider =
    StateNotifierProvider<SearchHistoryNotifier, List<String>>((ref) {
      return SearchHistoryNotifier(ref);
    });
