import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/networking/api_client.dart';
import '../../../../core/storage/local_cache_database.dart';
import '../domain/reading_stats_models.dart';

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

class UserFullBookProgress {
  final int id;
  final int bookId;
  final int currentPage;
  final double currentOffset;

  UserFullBookProgress({
    required this.id,
    required this.bookId,
    required this.currentPage,
    required this.currentOffset,
  });

  factory UserFullBookProgress.fromJson(Map<String, dynamic> json) {
    return UserFullBookProgress(
      id: json['id'],
      bookId: json['book'],
      currentPage: (json['current_page'] as num?)?.toInt() ?? 0,
      currentOffset: (json['current_offset'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class CrossDevicePlaybackSession {
  final bool hasActiveSession;
  final bool canResume;
  final String? promptMessage;
  final int? bookId;
  final String? bookSlug;
  final String? bookTitle;
  final String? authorName;
  final String? coverImageUrl;
  final int? sectionId;
  final String? sectionTitle;
  final int sectionOrder;
  final int totalSections;
  final double positionSeconds;
  final String formattedPosition;
  final double durationSeconds;
  final String? audioUrl;
  final String deviceType;
  final String deviceName;
  final bool isPlaying;

  const CrossDevicePlaybackSession({
    required this.hasActiveSession,
    this.canResume = false,
    this.promptMessage,
    this.bookId,
    this.bookSlug,
    this.bookTitle,
    this.authorName,
    this.coverImageUrl,
    this.sectionId,
    this.sectionTitle,
    this.sectionOrder = 1,
    this.totalSections = 1,
    this.positionSeconds = 0.0,
    this.formattedPosition = '00:00',
    this.durationSeconds = 600.0,
    this.audioUrl,
    this.deviceType = 'unknown',
    this.deviceName = 'device',
    this.isPlaying = false,
  });

  factory CrossDevicePlaybackSession.fromJson(Map<String, dynamic> json) {
    return CrossDevicePlaybackSession(
      hasActiveSession: json['has_active_session'] as bool? ?? false,
      canResume: json['can_resume'] as bool? ?? false,
      promptMessage: json['prompt_message'] as String?,
      bookId: json['book_id'] as int?,
      bookSlug: json['book_slug'] as String?,
      bookTitle: json['book_title'] as String?,
      authorName: json['author_name'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      sectionId: json['section_id'] as int?,
      sectionTitle: json['section_title'] as String?,
      sectionOrder: (json['section_order'] as num?)?.toInt() ?? 1,
      totalSections: (json['total_sections'] as num?)?.toInt() ?? 1,
      positionSeconds: (json['position_seconds'] as num?)?.toDouble() ?? 0.0,
      formattedPosition: json['formatted_position'] as String? ?? '00:00',
      durationSeconds: (json['duration_seconds'] as num?)?.toDouble() ?? 600.0,
      audioUrl: json['audio_url'] as String?,
      deviceType: json['device_type'] as String? ?? 'unknown',
      deviceName: json['device_name'] as String? ?? 'device',
      isPlaying: json['is_playing'] as bool? ?? false,
    );
  }
}

class ProgressRepository {
  final Dio _dio;
  final LocalCacheDatabase? _cacheDb;

  ProgressRepository({required Dio dio, LocalCacheDatabase? cacheDb})
      : _dio = dio,
        _cacheDb = cacheDb;

  Future<UserSummaryProgress> getBookProgress(int bookId) async {
    try {
      final response = await _dio.get('/progress/books/$bookId/');
      return UserSummaryProgress.fromJson(response.data);
    } catch (_) {
      return UserSummaryProgress(
        id: 0,
        bookId: bookId,
        completedSectionsCount: 0,
      );
    }
  }

  Future<UserSummaryProgress> markSectionRead(
    int bookId,
    int sectionId, {
    String? bookSlug,
  }) async {
    if (bookSlug != null) {
      await _cacheDb?.saveLocalProgress(
        bookSlug: bookSlug,
        bookId: bookId,
      );
    }

    try {
      final response = await _dio.post(
        '/progress/books/$bookId/section/$sectionId/',
      );
      return UserSummaryProgress.fromJson(response.data);
    } catch (e) {
      // Offline fallback: enqueue into sync queue
      await _cacheDb?.enqueueSyncAction('section_read', {
        'book_id': bookId,
        'section_id': sectionId,
        if (bookSlug != null) 'book_slug': bookSlug,
      });

      return UserSummaryProgress(
        id: 0,
        bookId: bookId,
        currentSectionId: sectionId,
        completedSectionsCount: 1,
      );
    }
  }

  Future<UserAudioProgress> getAudioProgress(int bookId) async {
    try {
      final response = await _dio.get('/progress/books/$bookId/audio/');
      return UserAudioProgress.fromJson(response.data);
    } catch (_) {
      return UserAudioProgress(
        id: 0,
        bookId: bookId,
        currentSectionId: null,
        currentPositionSeconds: 0.0,
        isFinished: false,
      );
    }
  }

  Future<UserAudioProgress> saveAudioProgress({
    required int bookId,
    required int sectionId,
    required double positionSeconds,
    required bool isFinished,
    String? bookSlug,
  }) async {
    if (bookSlug != null) {
      await _cacheDb?.saveLocalProgress(
        bookSlug: bookSlug,
        bookId: bookId,
        audioSectionId: sectionId,
        audioPositionSeconds: positionSeconds,
        isCompleted: isFinished,
      );
    }

    try {
      final response = await _dio.post(
        '/progress/books/$bookId/audio/',
        data: {
          'section_id': sectionId,
          'position_seconds': positionSeconds,
          'is_finished': isFinished,
        },
      );
      return UserAudioProgress.fromJson(response.data);
    } catch (e) {
      // Offline fallback: enqueue into sync queue
      await _cacheDb?.enqueueSyncAction('audio_progress', {
        'book_id': bookId,
        'section_id': sectionId,
        'position_seconds': positionSeconds,
        'is_finished': isFinished,
        if (bookSlug != null) 'book_slug': bookSlug,
      });

      return UserAudioProgress(
        id: 0,
        bookId: bookId,
        currentSectionId: sectionId,
        currentPositionSeconds: positionSeconds,
        isFinished: isFinished,
      );
    }
  }

  Future<UserFullBookProgress> getFullBookProgress(int bookId) async {
    try {
      final response = await _dio.get('/progress/books/$bookId/full/');
      return UserFullBookProgress.fromJson(response.data);
    } catch (_) {
      return UserFullBookProgress(
        id: 0,
        bookId: bookId,
        currentPage: 0,
        currentOffset: 0.0,
      );
    }
  }

  Future<UserFullBookProgress> saveFullBookProgress({
    required int bookId,
    required int currentPage,
    required double currentOffset,
    String? bookSlug,
  }) async {
    try {
      final response = await _dio.post(
        '/progress/books/$bookId/full/',
        data: {'current_page': currentPage, 'current_offset': currentOffset},
      );
      return UserFullBookProgress.fromJson(response.data);
    } catch (e) {
      await _cacheDb?.enqueueSyncAction('full_book_progress', {
        'book_id': bookId,
        'current_page': currentPage,
        'current_offset': currentOffset,
        if (bookSlug != null) 'book_slug': bookSlug,
      });

      return UserFullBookProgress(
        id: 0,
        bookId: bookId,
        currentPage: currentPage,
        currentOffset: currentOffset,
      );
    }
  }

  Future<UserReadingStats> getReadingStats() async {
    try {
      final response = await _dio.get('/progress/stats/');
      return UserReadingStats.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        return UserReadingStats.empty();
      }
      rethrow;
    }
  }

  Future<List<UserBadgeItem>> getBadges() async {
    try {
      final response = await _dio.get('/progress/badges/');
      final data = response.data;
      final list = (data is Map ? data['badges'] : data) as List<dynamic>? ?? [];
      return list
          .whereType<Map<String, dynamic>>()
          .map((e) => UserBadgeItem.fromJson(e))
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        return [];
      }
      rethrow;
    }
  }

  Future<void> recordActivity() async {
    try {
      await _dio.post('/progress/activity/');
    } catch (_) {}
  }

  // Cross-Platform Playback Sync
  Future<CrossDevicePlaybackSession?> getActivePlaybackSession({
    String currentDeviceType = 'mobile',
  }) async {
    try {
      final response = await _dio.get(
        '/progress/active-session/',
        queryParameters: {'current_device_type': currentDeviceType},
      );
      if (response.data is Map<String, dynamic>) {
        return CrossDevicePlaybackSession.fromJson(
          response.data as Map<String, dynamic>,
        );
      }
    } catch (_) {}
    return null;
  }

  Future<void> updateActivePlaybackSession({
    required int bookId,
    String? bookSlug,
    int? sectionId,
    required double positionSeconds,
    double? durationSeconds,
    String deviceType = 'mobile',
    String deviceName = 'Mobile App',
    bool isPlaying = false,
    bool isFinished = false,
  }) async {
    try {
      await _dio.post(
        '/progress/active-session/',
        data: {
          'book_id': bookId,
          if (bookSlug != null) 'book_slug': bookSlug,
          if (sectionId != null) 'section_id': sectionId,
          'position_seconds': positionSeconds,
          if (durationSeconds != null) 'duration_seconds': durationSeconds,
          'device_type': deviceType,
          'device_name': deviceName,
          'is_playing': isPlaying,
          'is_finished': isFinished,
        },
      );
    } catch (_) {}
  }

  Future<CrossDevicePlaybackSession?> handoffPlaybackSession({
    String targetDeviceType = 'mobile',
    String targetDeviceName = 'Mobile App',
  }) async {
    try {
      final response = await _dio.post(
        '/progress/active-session/handoff/',
        data: {
          'device_type': targetDeviceType,
          'device_name': targetDeviceName,
        },
      );
      if (response.data is Map<String, dynamic> &&
          response.data['session'] is Map<String, dynamic>) {
        return CrossDevicePlaybackSession.fromJson(
          response.data['session'] as Map<String, dynamic>,
        );
      }
    } catch (_) {}
    return null;
  }
}

@riverpod
ProgressRepository progressRepository(ProgressRepositoryRef ref) {
  final dio = ref.watch(dioProvider);
  final cacheDb = ref.watch(localCacheDatabaseProvider);
  return ProgressRepository(dio: dio, cacheDb: cacheDb);
}

final readingStatsProvider = FutureProvider<UserReadingStats>((ref) async {
  return ref.watch(progressRepositoryProvider).getReadingStats();
});

final badgesProvider = FutureProvider<List<UserBadgeItem>>((ref) async {
  return ref.watch(progressRepositoryProvider).getBadges();
});

final crossDevicePlaybackSessionProvider =
    FutureProvider<CrossDevicePlaybackSession?>((ref) async {
  return ref.watch(progressRepositoryProvider).getActivePlaybackSession();
});


