import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/networking/api_client.dart';
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
    Map<String, dynamic> queryParameters = {'page': page};
    if (query != null && query.isNotEmpty) queryParameters['search'] = query;
    if (categorySlug != null)
      queryParameters['categories__slug'] = categorySlug;

    final response = await _dio.get(
      '/catalog/books/',
      queryParameters: queryParameters,
    );

    // Handing paginated DRF response format: { "count": XX, "next": "...", "previous": null, "results": [...] }
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
