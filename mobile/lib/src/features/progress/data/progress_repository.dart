import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/networking/api_client.dart';

part 'progress_repository.g.dart';

class UserSummaryProgress {
  final int id;
  final int bookId;
  final int? currentSectionId;
  final int completedSectionsCount;

  UserSummaryProgress({
    required this.id,
    required this.bookId,
    this.currentSectionId,
    required this.completedSectionsCount,
  });

  factory UserSummaryProgress.fromJson(Map<String, dynamic> json) {
    return UserSummaryProgress(
      id: json['id'],
      bookId: json['book'],
      currentSectionId: json['current_section'],
      completedSectionsCount: json['completed_sections_count'] ?? 0,
    );
  }
}

class UserAudioProgress {
  final int id;
  final int bookId;
  final int? currentSectionId;
  final double currentPositionSeconds;
  final bool isFinished;

  UserAudioProgress({
    required this.id,
    required this.bookId,
    this.currentSectionId,
    required this.currentPositionSeconds,
    required this.isFinished,
  });

  factory UserAudioProgress.fromJson(Map<String, dynamic> json) {
    return UserAudioProgress(
      id: json['id'],
      bookId: json['book'],
      currentSectionId: json['current_section'],
      currentPositionSeconds:
          (json['current_position_seconds'] as num?)?.toDouble() ?? 0.0,
      isFinished: json['is_finished'] ?? false,
    );
  }
}

class ProgressRepository {
  final Dio _dio;

  ProgressRepository({required Dio dio}) : _dio = dio;

  Future<UserSummaryProgress> getBookProgress(int bookId) async {
    final response = await _dio.get('/progress/books/$bookId/');
    return UserSummaryProgress.fromJson(response.data);
  }

  Future<UserSummaryProgress> markSectionRead(int bookId, int sectionId) async {
    final response = await _dio.post(
      '/progress/books/$bookId/section/$sectionId/',
    );
    return UserSummaryProgress.fromJson(response.data);
  }

  Future<UserAudioProgress> getAudioProgress(int bookId) async {
    final response = await _dio.get('/progress/books/$bookId/audio/');
    return UserAudioProgress.fromJson(response.data);
  }

  Future<UserAudioProgress> saveAudioProgress({
    required int bookId,
    required int sectionId,
    required double positionSeconds,
    required bool isFinished,
  }) async {
    final response = await _dio.post(
      '/progress/books/$bookId/audio/',
      data: {
        'section_id': sectionId,
        'position_seconds': positionSeconds,
        'is_finished': isFinished,
      },
    );
    return UserAudioProgress.fromJson(response.data);
  }
}

@riverpod
ProgressRepository progressRepository(ProgressRepositoryRef ref) {
  final dio = ref.watch(dioProvider);
  return ProgressRepository(dio: dio);
}
