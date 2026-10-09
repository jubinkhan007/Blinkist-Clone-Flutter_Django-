import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/networking/api_client.dart';
import '../domain/reading_list_models.dart';

class ReadingListRepository {
  final Dio _dio;

  ReadingListRepository(this._dio);

  Future<List<UserReadingList>> fetchUserReadingLists() async {
    final response = await _dio.get('/catalog/spaces/');
    final data = response.data as List<dynamic>;
    return data
        .map((item) => UserReadingList.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<UserReadingList> fetchReadingListDetail(int id, {String? token}) async {
    final queryParams = <String, dynamic>{};
    if (token != null && token.isNotEmpty) {
      queryParams['token'] = token;
    }
    final response = await _dio.get(
      '/catalog/spaces/$id/',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    return UserReadingList.fromJson(response.data as Map<String, dynamic>);
  }

  Future<UserReadingList> fetchSharedReadingList(String token) async {
    final response = await _dio.get('/catalog/spaces/share/$token/');
    return UserReadingList.fromJson(response.data as Map<String, dynamic>);
  }

  Future<UserReadingList> createReadingList({
    required String title,
    String? description,
    String? emoji,
    String? colorHex,
    bool isPublic = false,
  }) async {
    final payload = <String, dynamic>{
      'title': title,
      'is_public': isPublic,
      if (description != null) 'description': description,
      if (emoji != null) 'emoji': emoji,
      if (colorHex != null) 'color_hex': colorHex,
    };
    final response = await _dio.post('/catalog/spaces/', data: payload);
    return UserReadingList.fromJson(response.data as Map<String, dynamic>);
  }

  Future<UserReadingList> updateReadingList(
    int id, {
    String? title,
    String? description,
    String? emoji,
    String? colorHex,
    bool? isPublic,
  }) async {
    final payload = <String, dynamic>{
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (emoji != null) 'emoji': emoji,
      if (colorHex != null) 'color_hex': colorHex,
      if (isPublic != null) 'is_public': isPublic,
    };
    final response = await _dio.patch('/catalog/spaces/$id/', data: payload);
    return UserReadingList.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteReadingList(int id) async {
    await _dio.delete('/catalog/spaces/$id/');
  }

  Future<void> addBookToReadingList(
    int listId,
    String bookSlug, {
    String? note,
  }) async {
    final payload = <String, dynamic>{
      'book_slug': bookSlug,
      if (note != null && note.isNotEmpty) 'note': note,
    };
    await _dio.post('/catalog/spaces/$listId/books/', data: payload);
  }

  Future<void> removeBookFromReadingList(int listId, String bookSlug) async {
    await _dio.delete('/catalog/spaces/$listId/books/$bookSlug/');
  }

  Future<void> reorderReadingList(int listId, List<String> bookSlugs) async {
    await _dio.post(
      '/catalog/spaces/$listId/reorder/',
      data: {'book_slugs': bookSlugs},
    );
  }

  Future<ReadingListMembership> fetchBookMemberships(String bookSlug) async {
    final response = await _dio.get(
      '/catalog/spaces/membership/',
      queryParameters: {'book_slug': bookSlug},
    );
    return ReadingListMembership.fromJson(
        response.data as Map<String, dynamic>);
  }

  Future<UserReadingList> cloneSharedReadingList(String token) async {
    final response = await _dio.post('/catalog/spaces/share/$token/clone/');
    return UserReadingList.fromJson(response.data as Map<String, dynamic>);
  }
}

final readingListRepositoryProvider = Provider<ReadingListRepository>((ref) {
  return ReadingListRepository(ref.watch(dioProvider));
});

final userReadingListsProvider =
    FutureProvider<List<UserReadingList>>((ref) async {
  return ref.watch(readingListRepositoryProvider).fetchUserReadingLists();
});

final readingListDetailProvider =
    FutureProvider.family<UserReadingList, ({int id, String? token})>(
        (ref, arg) async {
  return ref
      .watch(readingListRepositoryProvider)
      .fetchReadingListDetail(arg.id, token: arg.token);
});

final sharedReadingListProvider =
    FutureProvider.family<UserReadingList, String>((ref, token) async {
  return ref.watch(readingListRepositoryProvider).fetchSharedReadingList(token);
});

final bookMembershipsProvider =
    FutureProvider.family<ReadingListMembership, String>((ref, bookSlug) async {
  return ref
      .watch(readingListRepositoryProvider)
      .fetchBookMemberships(bookSlug);
});
