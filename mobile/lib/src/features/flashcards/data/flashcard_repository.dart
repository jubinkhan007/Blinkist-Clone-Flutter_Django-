import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/networking/api_client.dart';
import '../domain/flashcard_models.dart';

class FlashcardRepository {
  final Dio _dio;

  FlashcardRepository(this._dio);

  Future<FlashcardDeck> fetchBookFlashcards(String bookSlug, {bool forceRegenerate = false}) async {
    final response = await _dio.get(
      '/summaries/books/$bookSlug/flashcards/',
      queryParameters: forceRegenerate ? {'force_regenerate': 'true'} : null,
    );
    return FlashcardDeck.fromJson(response.data as Map<String, dynamic>);
  }

  Future<DailyReviewDeck> fetchDailyReviewDeck({int limit = 3}) async {
    final response = await _dio.get(
      '/summaries/flashcards/daily-review/',
      queryParameters: {'limit': limit},
    );
    return DailyReviewDeck.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> reviewCard({
    required int cardId,
    required String status, // 'mastered' | 'review_later'
  }) async {
    final response = await _dio.post(
      '/summaries/flashcards/$cardId/review/',
      data: {'status': status},
    );
    return response.data as Map<String, dynamic>;
  }
}

final flashcardRepositoryProvider = Provider<FlashcardRepository>((ref) {
  return FlashcardRepository(ref.watch(dioProvider));
});

final bookFlashcardsProvider =
    FutureProvider.family<FlashcardDeck, String>((ref, slug) async {
  return ref.watch(flashcardRepositoryProvider).fetchBookFlashcards(slug);
});

final dailyReviewDeckProvider = FutureProvider<DailyReviewDeck>((ref) async {
  return ref.watch(flashcardRepositoryProvider).fetchDailyReviewDeck();
});
