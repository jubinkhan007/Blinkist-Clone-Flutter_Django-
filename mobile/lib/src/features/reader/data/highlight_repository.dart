import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/networking/api_client.dart';
import '../domain/highlight_models.dart';

class HighlightRepository {
  final Dio _dio;

  HighlightRepository(this._dio);

  Future<List<UserHighlight>> fetchHighlights({String? bookSlug}) async {
    final response = await _dio.get(
      '/highlights/',
      queryParameters: bookSlug != null ? {'book_slug': bookSlug} : null,
    );
    final data = response.data;
    final List<dynamic> list = data is Map ? (data['results'] ?? []) : data;
    return list
        .map((json) => UserHighlight.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<UserHighlight> createHighlight({
    required String bookSlug,
    int? sectionId,
    required String selectedText,
    String note = '',
    String color = 'yellow',
  }) async {
    final response = await _dio.post(
      '/highlights/',
      data: {
        'book_slug': bookSlug,
        'section_id': sectionId,
        'selected_text': selectedText,
        'note': note,
        'color': color,
      },
    );
    return UserHighlight.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteHighlight(int id) async {
    await _dio.delete('/highlights/$id/');
  }
}

final highlightRepositoryProvider = Provider<HighlightRepository>((ref) {
  return HighlightRepository(ref.watch(dioProvider));
});

final userHighlightsProvider = FutureProvider<List<UserHighlight>>((ref) async {
  return ref.watch(highlightRepositoryProvider).fetchHighlights();
});

final bookHighlightsProvider =
    FutureProvider.family<List<UserHighlight>, String>((ref, slug) async {
  return ref.watch(highlightRepositoryProvider).fetchHighlights(bookSlug: slug);
});
