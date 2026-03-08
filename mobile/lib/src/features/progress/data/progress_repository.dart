import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/networking/api_client.dart';

part 'progress_repository.g.dart';

class UserBookProgress {
  final int id;
  final int bookId;
  final int? currentSectionId;
  final int percentComplete;
  final bool isCompleted;

  UserBookProgress({
    required this.id,
    required this.bookId,
    this.currentSectionId,
    required this.percentComplete,
    required this.isCompleted,
  });

  factory UserBookProgress.fromJson(Map<String, dynamic> json) {
    return UserBookProgress(
      id: json['id'],
      bookId: json['book'],
      currentSectionId: json['current_section'],
      percentComplete: json['percent_complete'],
      isCompleted: json['is_completed'],
    );
  }
}

class ProgressRepository {
  final Dio _dio;

  ProgressRepository({required Dio dio}) : _dio = dio;

  Future<UserBookProgress> getBookProgress(int bookId) async {
    final response = await _dio.get('/progress/books/$bookId/');
    return UserBookProgress.fromJson(response.data);
  }

  Future<UserBookProgress> markSectionRead(int bookId, int sectionId) async {
    final response = await _dio.post(
      '/progress/books/$bookId/section/$sectionId/',
    );
    return UserBookProgress.fromJson(response.data);
  }
}

@riverpod
ProgressRepository progressRepository(ProgressRepositoryRef ref) {
  final dio = ref.watch(dioProvider);
  return ProgressRepository(dio: dio);
}
