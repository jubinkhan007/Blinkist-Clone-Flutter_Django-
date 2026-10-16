import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/networking/api_client.dart';
import '../../../../core/storage/local_cache_database.dart';
import '../../catalog/domain/collection_models.dart';
import '../../home/domain/home_models.dart';
import '../domain/book_models.dart';

part 'content_repository.g.dart';

class ContentRepository {
  final Dio _dio;
  final LocalCacheDatabase? _cacheDb;

  ContentRepository({required Dio dio, LocalCacheDatabase? cacheDb})
      : _dio = dio,
        _cacheDb = cacheDb;

  Future<HomeMerchandising> getHomeFeed() async {
    try {
      final response = await _dio.get('/home/');
      final data = response.data as Map<String, dynamic>;
      _cacheDb?.cacheHomeFeed(data);
      return HomeMerchandising.fromJson(data);
    } catch (e) {
      // Offline fallback: load from SQLite cache
      final cached = await _cacheDb?.getCachedHomeFeed();
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  Future<BookDetail> getBookDetail(String slug) async {
    // 1. Check local file download first (Instant offline access)
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
      final book = BookDetail.fromJson(response.data);
      _cacheDb?.cacheBookDetail(book);
      return book;
    } catch (e) {
      // 3. Fallback: check file downloads again, then SQLite database
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final localFile = File('${appDir.path}/downloads/$slug/book.json');
        if (await localFile.exists()) {
          final content = await localFile.readAsString();
          return BookDetail.fromJson(jsonDecode(content));
        }
      } catch (_) {}

      final cached = await _cacheDb?.getCachedBookDetail(slug);
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  Future<List<SummarySection>> getSummarySections(String slug) async {
    // 1. Check local file downloads first (Offline reading & listening)
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
      final sections = data
          .map((item) => SummarySection.fromJson(item as Map<String, dynamic>))
          .toList();
      _cacheDb?.cacheSections(slug, sections);
      return sections;
    } catch (e) {
      // 3. Fallback to local file storage, then SQLite database
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

      final cached = await _cacheDb?.getCachedSections(slug);
      if (cached != null && cached.isNotEmpty) {
        return cached;
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
    final payload = {
      'question': question,
      if (sectionSlug != null && sectionSlug.isNotEmpty)
        'section_slug': sectionSlug,
      if (history != null && history.isNotEmpty) 'history': history,
    };
    try {
      final response = await _dio.post(
        '/summaries/$slug/ask/',
        data: payload,
      );
      return AskAiResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        final response = await _dio.post(
          '/catalog/books/$slug/ask/',
          data: payload,
        );
        return AskAiResponse.fromJson(response.data as Map<String, dynamic>);
      }
      rethrow;
    }
  }
}

@riverpod
ContentRepository contentRepository(ContentRepositoryRef ref) {
  final dio = ref.watch(dioProvider);
  final cacheDb = ref.watch(localCacheDatabaseProvider);
  return ContentRepository(dio: dio, cacheDb: cacheDb);
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

