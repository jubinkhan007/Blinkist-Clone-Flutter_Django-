import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/networking/api_client.dart';
import '../domain/audio_bookmark_models.dart';

class AudioBookmarkRepository {
  final Dio _dio;

  AudioBookmarkRepository(this._dio);

  Future<List<AudioBookmark>> fetchBookmarks({String? bookSlug}) async {
    final response = await _dio.get(
      '/audio-bookmarks/',
      queryParameters: bookSlug != null ? {'book_slug': bookSlug} : null,
    );
    final data = response.data;
    final List<dynamic> list = data is Map ? (data['results'] ?? []) : data;
    return list
        .map((json) => AudioBookmark.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<AudioBookmark> createBookmark({
    required String bookSlug,
    int? sectionId,
    required int timestampSeconds,
    String title = '',
    String note = '',
  }) async {
    final response = await _dio.post(
      '/audio-bookmarks/',
      data: {
        'book_slug': bookSlug,
        'section_id': sectionId,
        'timestamp_seconds': timestampSeconds,
        'title': title,
        'note': note,
      },
    );
    return AudioBookmark.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AudioBookmark> updateBookmark(
    int id, {
    String? title,
    String? note,
  }) async {
    final data = <String, dynamic>{};
    if (title != null) data['title'] = title;
    if (note != null) data['note'] = note;

    final response = await _dio.patch(
      '/audio-bookmarks/$id/',
      data: data,
    );
    return AudioBookmark.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteBookmark(int id) async {
    await _dio.delete('/audio-bookmarks/$id/');
  }
}

final audioBookmarkRepositoryProvider = Provider<AudioBookmarkRepository>((ref) {
  return AudioBookmarkRepository(ref.watch(dioProvider));
});

final userAudioBookmarksProvider =
    FutureProvider<List<AudioBookmark>>((ref) async {
  return ref.watch(audioBookmarkRepositoryProvider).fetchBookmarks();
});

final bookAudioBookmarksProvider =
    FutureProvider.family<List<AudioBookmark>, String>((ref, slug) async {
  return ref.watch(audioBookmarkRepositoryProvider).fetchBookmarks(bookSlug: slug);
});
