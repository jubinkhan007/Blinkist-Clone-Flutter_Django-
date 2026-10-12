import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/networking/api_client.dart';
import '../domain/daily_digest_models.dart';

class DailyDigestRepository {
  final Dio _dio;

  DailyDigestRepository({required Dio dio}) : _dio = dio;

  Future<DailyAudioDigest?> getDailyDigest({String? date}) async {
    try {
      final response = await _dio.get(
        '/media/daily-digest/',
        queryParameters: date != null ? {'date': date} : null,
      );
      if (response.data is Map<String, dynamic>) {
        return DailyAudioDigest.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      debugPrint('Failed to fetch daily audio digest: $e');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error fetching daily audio digest: $e');
      return null;
    }
  }

  Future<DailyDigestProgress?> updateProgress({
    required int digestId,
    required int currentItemIndex,
    required int currentPositionSeconds,
    required bool isCompleted,
  }) async {
    try {
      final response = await _dio.post(
        '/media/daily-digest/progress/',
        data: {
          'digest_id': digestId,
          'current_item_index': currentItemIndex,
          'current_position_seconds': currentPositionSeconds,
          'is_completed': isCompleted,
        },
      );
      if (response.data is Map<String, dynamic> && response.data['progress'] != null) {
        return DailyDigestProgress.fromJson(
          response.data['progress'] as Map<String, dynamic>,
        );
      }
      return null;
    } catch (e) {
      debugPrint('Failed to update daily digest progress: $e');
      return null;
    }
  }
}

final dailyDigestRepositoryProvider = Provider<DailyDigestRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return DailyDigestRepository(dio: dio);
});

final dailyDigestProvider = FutureProvider<DailyAudioDigest?>((ref) async {
  return ref.watch(dailyDigestRepositoryProvider).getDailyDigest();
});
