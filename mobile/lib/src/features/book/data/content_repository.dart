import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/networking/api_client.dart';
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
    // 1. Check local storage first (Offline Mode)
    final appDir = await getApplicationDocumentsDirectory();
    final localFile = File('${appDir.path}/downloads/$slug/book.json');
    if (await localFile.exists()) {
      try {
        final content = await localFile.readAsString();
        final json = jsonDecode(content);
        return BookDetail.fromJson(json);
      } catch (_) {
        // Fallback to network if local read fails
      }
    }

    // 2. Fetch from Network
    final response = await _dio.get('/catalog/books/$slug/');
    return BookDetail.fromJson(response.data);
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
