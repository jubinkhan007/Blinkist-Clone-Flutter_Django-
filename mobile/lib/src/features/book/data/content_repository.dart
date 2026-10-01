import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/networking/api_client.dart';
import '../../catalog/domain/collection_models.dart';
import '../../home/domain/home_models.dart';
import '../domain/book_models.dart';


part 'content_repository.g.dart';

class ContentRepository {
  final Dio _dio;

  ContentRepository({required Dio dio}) : _dio = dio;

  Future<HomeMerchandising> getHomeFeed() async {
    final response = await _dio.get('/home/');
    return HomeMerchandising.fromJson(response.data);
  }

  Future<BookDetail> getBookDetail(String slug) async {
    // 1. Check local storage first (Instant offline access)
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final localFile = File('${appDir.path}/downloads/$slug/book.json');
      if (await localFile.exists()) {
        final content = await localFile.readAsString();
        return BookDetail.fromJson(jsonDecode(content));
      }
    } catch (_) {}

    // 2. Fetch from Network
    try {
      final response = await _dio.get('/catalog/books/$slug/');
      return BookDetail.fromJson(response.data);
    } catch (e) {
      final appDir = await getApplicationDocumentsDirectory();
      final localFile = File('${appDir.path}/downloads/$slug/book.json');
      if (await localFile.exists()) {
        final content = await localFile.readAsString();
        return BookDetail.fromJson(jsonDecode(content));
      }
      rethrow;
    }
  }

  Future<List<SummarySection>> getSummarySections(String slug) async {
    // 1. Check local storage first (Offline reading & listening)
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final localFile = File('${appDir.path}/downloads/$slug/book.json');
      if (await localFile.exists()) {
        final content = await localFile.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        final book = BookDetail.fromJson(data);
        if (book.sections.isNotEmpty) {
          return book.sections;
        }
      }
    } catch (_) {}

    // 2. Fetch from Network
    try {
      final response = await _dio.get('/summaries/$slug/');
      final data = response.data as List<dynamic>;
      return data
          .map((item) => SummarySection.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // 3. Fallback to local storage on network error
      final appDir = await getApplicationDocumentsDirectory();
      final localFile = File('${appDir.path}/downloads/$slug/book.json');
      if (await localFile.exists()) {
        final content = await localFile.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        final book = BookDetail.fromJson(data);
        if (book.sections.isNotEmpty) {
          return book.sections;
        }
      }
      rethrow;
    }
  }

  Future<List<CollectionOverview>> getCollections() async {
    final response = await _dio.get('/catalog/collections/');
    final data = response.data as List<dynamic>;
    return data
        .map((item) => CollectionOverview.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<CollectionDetail> getCollectionDetail(String slug) async {
    final response = await _dio.get('/catalog/collections/$slug/');
    return CollectionDetail.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AskAiResponse> askBookAi({
    required String slug,
    required String question,
    String? sectionSlug,
    List<Map<String, String>>? history,
  }) async {
    final response = await _dio.post(
      '/catalog/books/$slug/ask/',
      data: {
        'question': question,
        if (sectionSlug != null && sectionSlug.isNotEmpty)
          'section_slug': sectionSlug,
        if (history != null && history.isNotEmpty) 'history': history,
      },
    );
    return AskAiResponse.fromJson(response.data as Map<String, dynamic>);
  }
}

@riverpod
ContentRepository contentRepository(ContentRepositoryRef ref) {
  final dio = ref.watch(dioProvider);
  return ContentRepository(dio: dio);
}

@riverpod
Future<HomeMerchandising> homeFeed(HomeFeedRef ref) {
  return ref.watch(contentRepositoryProvider).getHomeFeed();
}

@riverpod
Future<BookDetail> bookDetail(BookDetailRef ref, String slug) {
  return ref.watch(contentRepositoryProvider).getBookDetail(slug);
}

final summarySectionsProvider =
    FutureProvider.family<List<SummarySection>, String>((ref, slug) {
      return ref.watch(contentRepositoryProvider).getSummarySections(slug);
    });

final collectionsProvider = FutureProvider<List<CollectionOverview>>((ref) {
  return ref.watch(contentRepositoryProvider).getCollections();
});

final collectionDetailProvider =
    FutureProvider.family<CollectionDetail, String>((ref, slug) {
  return ref.watch(contentRepositoryProvider).getCollectionDetail(slug);
});

