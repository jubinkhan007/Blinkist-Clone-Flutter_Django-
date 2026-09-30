import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../book/domain/book_models.dart';
import '../../../../core/networking/api_client.dart';

enum DownloadStatus {
  idle,
  downloading,
  completed,
  failed,
}

class DownloadTask {
  final String slug;
  final String title;
  final String author;
  final String? coverImageUrl;
  final String? localCoverPath;
  final DownloadStatus status;
  final double progress;
  final String? statusMessage;
  final String? error;
  final int totalBytes;
  final DateTime? downloadedAt;
  final int sectionsCount;
  final bool hasAudio;

  DownloadTask({
    required this.slug,
    this.title = '',
    this.author = '',
    this.coverImageUrl,
    this.localCoverPath,
    this.status = DownloadStatus.idle,
    this.progress = 0.0,
    this.statusMessage,
    this.error,
    this.totalBytes = 0,
    this.downloadedAt,
    this.sectionsCount = 0,
    this.hasAudio = false,
  });

  bool get isCompleted => status == DownloadStatus.completed;
  bool get isDownloading => status == DownloadStatus.downloading;
  bool get isFailed => status == DownloadStatus.failed;

  String get formattedSize {
    if (totalBytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    final i = (log(totalBytes) / log(1024)).floor().clamp(0, suffixes.length - 1);
    final size = totalBytes / pow(1024, i);
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  DownloadTask copyWith({
    String? slug,
    String? title,
    String? author,
    String? coverImageUrl,
    String? localCoverPath,
    DownloadStatus? status,
    double? progress,
    String? statusMessage,
    String? error,
    int? totalBytes,
    DateTime? downloadedAt,
    int? sectionsCount,
    bool? hasAudio,
  }) {
    return DownloadTask(
      slug: slug ?? this.slug,
      title: title ?? this.title,
      author: author ?? this.author,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      localCoverPath: localCoverPath ?? this.localCoverPath,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      statusMessage: statusMessage ?? this.statusMessage,
      error: error ?? this.error,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      sectionsCount: sectionsCount ?? this.sectionsCount,
      hasAudio: hasAudio ?? this.hasAudio,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'slug': slug,
      'title': title,
      'author': author,
      'cover_image_url': coverImageUrl,
      'local_cover_path': localCoverPath,
      'status': status.name,
      'progress': progress,
      'status_message': statusMessage,
      'error': error,
      'total_bytes': totalBytes,
      'downloaded_at': downloadedAt?.toIso8601String(),
      'sections_count': sectionsCount,
      'has_audio': hasAudio,
    };
  }

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    return DownloadTask(
      slug: json['slug'] ?? '',
      title: json['title'] ?? '',
      author: json['author'] ?? '',
      coverImageUrl: json['cover_image_url'],
      localCoverPath: json['local_cover_path'],
      status: DownloadStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DownloadStatus.completed,
      ),
      progress: (json['progress'] as num?)?.toDouble() ?? 1.0,
      statusMessage: json['status_message'],
      error: json['error'],
      totalBytes: (json['total_bytes'] as num?)?.toInt() ?? 0,
      downloadedAt: json['downloaded_at'] != null
          ? DateTime.tryParse(json['downloaded_at'])
          : null,
      sectionsCount: (json['sections_count'] as num?)?.toInt() ?? 0,
      hasAudio: json['has_audio'] ?? false,
    );
  }
}

class OfflineDownloadsService extends StateNotifier<Map<String, DownloadTask>> {
  final Dio _dio;
  final Map<String, CancelToken> _cancelTokens = {};

  OfflineDownloadsService(this._dio) : super({}) {
    _initFromDisk();
  }

  Future<void> _initFromDisk() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${appDir.path}/downloads');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
        return;
      }

      final Map<String, DownloadTask> loaded = {};

      // 1. Try reading registry index file
      final indexFile = File('${downloadsDir.path}/downloads_index.json');
      if (await indexFile.exists()) {
        try {
          final content = await indexFile.readAsString();
          final List<dynamic> list = jsonDecode(content);
          for (final item in list) {
            final task = DownloadTask.fromJson(item as Map<String, dynamic>);
            // Verify folder and book.json still exist on disk
            final bookJson = File('${downloadsDir.path}/${task.slug}/book.json');
            if (await bookJson.exists()) {
              loaded[task.slug] = task;
            }
          }
        } catch (e) {
          debugPrint('Failed to parse downloads_index.json: $e');
        }
      }

      // 2. Discover any folders with book.json that might not be in the index
      await for (final entity in downloadsDir.list(followLinks: false)) {
        if (entity is Directory) {
          final slug = entity.path.split(Platform.pathSeparator).last;
          if (!loaded.containsKey(slug)) {
            final bookJson = File('${entity.path}/book.json');
            if (await bookJson.exists()) {
              try {
                final content = await bookJson.readAsString();
                final data = jsonDecode(content) as Map<String, dynamic>;
                final book = BookDetail.fromJson(data);
                final bytes = await _calculateDirSize(entity);
                final coverFile = File('${entity.path}/cover.jpg');

                loaded[slug] = DownloadTask(
                  slug: slug,
                  title: book.title,
                  author: book.author.name,
                  coverImageUrl: book.coverImageUrl,
                  localCoverPath: await coverFile.exists() ? coverFile.path : null,
                  status: DownloadStatus.completed,
                  progress: 1.0,
                  statusMessage: 'Downloaded',
                  totalBytes: bytes,
                  downloadedAt: await bookJson.lastModified(),
                  sectionsCount: book.sections.length,
                  hasAudio: book.sections.any((s) => s.audioUrl != null),
                );
              } catch (e) {
                debugPrint('Failed to restore book from ${entity.path}: $e');
              }
            }
          }
        }
      }

      state = loaded;
      await _saveIndex();
    } catch (e) {
      debugPrint('Error initializing offline downloads: $e');
    }
  }

  Future<int> _calculateDirSize(Directory dir) async {
    int total = 0;
    try {
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            total += await entity.length();
          }
        }
      }
    } catch (_) {}
    return total;
  }

  Future<void> _saveIndex() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final indexFile = File('${appDir.path}/downloads/downloads_index.json');
      final list = state.values
          .where((t) => t.isCompleted)
          .map((t) => t.toJson())
          .toList();
      await indexFile.writeAsString(jsonEncode(list));
    } catch (e) {
      debugPrint('Failed to save downloads_index.json: $e');
    }
  }

  Future<void> startDownload(BookDetail book) async {
    if (state.containsKey(book.slug) && state[book.slug]!.isCompleted) {
      return; // Already downloaded
    }

    final cancelToken = CancelToken();
    _cancelTokens[book.slug] = cancelToken;

    state = {
      ...state,
      book.slug: DownloadTask(
        slug: book.slug,
        title: book.title,
        author: book.author.name,
        coverImageUrl: book.coverImageUrl,
        status: DownloadStatus.downloading,
        progress: 0.0,
        statusMessage: 'Starting download...',
        sectionsCount: book.sections.length,
        hasAudio: book.sections.any((s) => s.audioUrl != null && s.audioUrl!.isNotEmpty),
      ),
    };

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final bookDir = Directory('${appDir.path}/downloads/${book.slug}');
      if (!await bookDir.exists()) {
        await bookDir.create(recursive: true);
      }

      final audioSections = book.sections
          .where((s) => s.audioUrl != null && s.audioUrl!.isNotEmpty)
          .toList();
      final totalSteps = 1 + (book.coverImageUrl != null ? 1 : 0) + audioSections.length;
      int completedSteps = 0;

      void updateStepProgress(String message) {
        completedSteps++;
        final progress = (completedSteps / totalSteps).clamp(0.0, 0.98);
        state = {
          ...state,
          book.slug: state[book.slug]!.copyWith(
            progress: progress,
            statusMessage: message,
          ),
        };
      }

      // 1. Download Cover Image
      String? localCoverPath;
      if (book.coverImageUrl != null && book.coverImageUrl!.isNotEmpty) {
        state = {
          ...state,
          book.slug: state[book.slug]!.copyWith(statusMessage: 'Downloading cover image...'),
        };
        final ext = book.coverImageUrl!.split('.').last.split('?').first;
        final safeExt = (ext.length >= 3 && ext.length <= 4) ? ext : 'jpg';
        localCoverPath = '${bookDir.path}/cover.$safeExt';

        final remoteCover = resolveServerUrl(book.coverImageUrl!);
        await _dio.download(
          remoteCover,
          localCoverPath,
          cancelToken: cancelToken,
        );
        updateStepProgress('Cover saved');
      }

      // 2. Download Audio Files & Update Sections
      final List<SummarySection> updatedSections = [];
      int audioIndex = 0;

      for (final section in book.sections) {
        if (cancelToken.isCancelled) return;

        if (section.audioUrl != null && section.audioUrl!.isNotEmpty) {
          audioIndex++;
          state = {
            ...state,
            book.slug: state[book.slug]!.copyWith(
              statusMessage: 'Downloading audio chapter $audioIndex/${audioSections.length}...',
            ),
          };

          final ext = section.audioUrl!.split('.').last.split('?').first;
          final safeExt = (ext.length >= 3 && ext.length <= 4) ? ext : 'mp3';
          final localAudioPath = '${bookDir.path}/section_${section.slug}.$safeExt';

          final remoteAudio = resolveServerUrl(section.audioUrl!);
          await _dio.download(
            remoteAudio,
            localAudioPath,
            cancelToken: cancelToken,
          );

          updateStepProgress('Audio $audioIndex/${audioSections.length} saved');
          updatedSections.add(section.copyWith(audioUrl: 'file://$localAudioPath'));
        } else {
          updatedSections.add(section);
        }
      }

      // 3. Save modified Book JSON
      state = {
        ...state,
        book.slug: state[book.slug]!.copyWith(statusMessage: 'Saving summary data...'),
      };

      final offlineBook = book.copyWith(
        coverImageUrl: localCoverPath != null ? 'file://$localCoverPath' : null,
        sections: updatedSections,
      );

      final jsonFile = File('${bookDir.path}/book.json');
      await jsonFile.writeAsString(jsonEncode(offlineBook.toJson()));

      // Calculate total disk footprint
      final totalBytes = await _calculateDirSize(bookDir);

      _cancelTokens.remove(book.slug);

      state = {
        ...state,
        book.slug: state[book.slug]!.copyWith(
          status: DownloadStatus.completed,
          progress: 1.0,
          statusMessage: 'Downloaded',
          localCoverPath: localCoverPath,
          totalBytes: totalBytes,
          downloadedAt: DateTime.now(),
        ),
      };

      await _saveIndex();
    } catch (e) {
      if (cancelToken.isCancelled) {
        // Handled in cancelDownload
        return;
      }
      _cancelTokens.remove(book.slug);
      debugPrint('Download failed for ${book.slug}: $e');
      state = {
        ...state,
        book.slug: state[book.slug]!.copyWith(
          status: DownloadStatus.failed,
          error: e.toString(),
          statusMessage: 'Download failed',
        ),
      };
    }
  }

  Future<void> cancelDownload(String slug) async {
    final token = _cancelTokens.remove(slug);
    if (token != null && !token.isCancelled) {
      token.cancel('User cancelled download');
    }

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final bookDir = Directory('${appDir.path}/downloads/$slug');
      if (await bookDir.exists()) {
        await bookDir.delete(recursive: true);
      }
    } catch (_) {}

    final newState = Map<String, DownloadTask>.from(state);
    newState.remove(slug);
    state = newState;
  }

  Future<void> removeDownload(String slug) async {
    cancelDownload(slug);

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final bookDir = Directory('${appDir.path}/downloads/$slug');
      if (await bookDir.exists()) {
        await bookDir.delete(recursive: true);
      }
    } catch (_) {}

    final newState = Map<String, DownloadTask>.from(state);
    newState.remove(slug);
    state = newState;

    await _saveIndex();
  }

  Future<void> clearAllDownloads() async {
    // Cancel all in-flight downloads
    for (final token in _cancelTokens.values) {
      if (!token.isCancelled) token.cancel('Clear all');
    }
    _cancelTokens.clear();

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${appDir.path}/downloads');
      if (await downloadsDir.exists()) {
        await downloadsDir.delete(recursive: true);
      }
    } catch (_) {}

    state = {};
    await _saveIndex();
  }
}

final offlineDownloadsProvider =
    StateNotifierProvider<OfflineDownloadsService, Map<String, DownloadTask>>((
      ref,
    ) {
      final dio = ref.watch(dioProvider);
      return OfflineDownloadsService(dio);
    });

final totalStorageUsedBytesProvider = Provider<int>((ref) {
  final downloads = ref.watch(offlineDownloadsProvider);
  return downloads.values
      .where((t) => t.isCompleted)
      .fold<int>(0, (sum, t) => sum + t.totalBytes);
});

final formattedTotalStorageProvider = Provider<String>((ref) {
  final totalBytes = ref.watch(totalStorageUsedBytesProvider);
  if (totalBytes <= 0) return '0 B';
  const suffixes = ['B', 'KB', 'MB', 'GB'];
  final i = (log(totalBytes) / log(1024)).floor().clamp(0, suffixes.length - 1);
  final size = totalBytes / pow(1024, i);
  return '${size.toStringAsFixed(1)} ${suffixes[i]}';
});
