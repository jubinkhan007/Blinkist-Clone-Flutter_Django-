import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../book/domain/book_models.dart';
import '../../../../core/networking/api_client.dart';

class DownloadTask {
  final String slug;
  final double progress;
  final bool isCompleted;
  final String? error;

  DownloadTask({
    required this.slug,
    this.progress = 0.0,
    this.isCompleted = false,
    this.error,
  });

  DownloadTask copyWith({double? progress, bool? isCompleted, String? error}) {
    return DownloadTask(
      slug: slug,
      progress: progress ?? this.progress,
      isCompleted: isCompleted ?? this.isCompleted,
      error: error ?? this.error,
    );
  }
}

class OfflineDownloadsService extends StateNotifier<Map<String, DownloadTask>> {
  final Dio _dio;

  OfflineDownloadsService(this._dio) : super({});

  Future<void> startDownload(BookDetail book) async {
    if (state.containsKey(book.slug) && state[book.slug]!.isCompleted) {
      return; // Already downloaded
    }

    state = {...state, book.slug: DownloadTask(slug: book.slug, progress: 0.0)};

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final bookDir = Directory('${appDir.path}/downloads/${book.slug}');
      if (!await bookDir.exists()) {
        await bookDir.create(recursive: true);
      }

      int totalItems =
          1 +
          (book.coverImageUrl != null ? 1 : 0) +
          book.sections.where((s) => s.audioUrl != null).length;
      int completedItems = 0;

      void updateProgress() {
        completedItems++;
        state = {
          ...state,
          book.slug: state[book.slug]!.copyWith(
            progress: completedItems / totalItems,
          ),
        };
      }

      // 1. Download Cover Image
      String? localCoverPath;
      if (book.coverImageUrl != null) {
        final ext = book.coverImageUrl!.split('.').last;
        final safeExt = ext.length > 4 ? 'jpg' : ext;
        localCoverPath = '${bookDir.path}/cover.$safeExt';

        final remoteCover = resolveServerUrl(book.coverImageUrl!);
        await _dio.download(remoteCover, localCoverPath);
        updateProgress();
      }

      // 2. Download Audio Files & Update Sections
      final List<SummarySection> updatedSections = [];
      for (final section in book.sections) {
        if (section.audioUrl != null) {
          final ext = section.audioUrl!.split('.').last;
          final safeExt = ext.length > 4 ? 'mp3' : ext;
          final localAudioPath =
              '${bookDir.path}/section_${section.slug}.$safeExt';

          final remoteAudio = resolveServerUrl(section.audioUrl!);
          await _dio.download(remoteAudio, localAudioPath);
          updateProgress();

          updatedSections.add(
            section.copyWith(audioUrl: 'file://$localAudioPath'),
          );
        } else {
          updatedSections.add(section);
        }
      }

      // 3. Save modified Book JSON
      final offlineBook = book.copyWith(
        coverImageUrl: localCoverPath != null ? 'file://$localCoverPath' : null,
        sections: updatedSections,
      );

      final jsonFile = File('${bookDir.path}/book.json');
      await jsonFile.writeAsString(jsonEncode(offlineBook.toJson()));
      updateProgress();

      state = {
        ...state,
        book.slug: state[book.slug]!.copyWith(progress: 1.0, isCompleted: true),
      };
    } catch (e) {
      state = {
        ...state,
        book.slug: state[book.slug]!.copyWith(
          error: e.toString(),
          isCompleted: true,
        ),
      };
    }
  }

  Future<void> removeDownload(String slug) async {
    final appDir = await getApplicationDocumentsDirectory();
    final bookDir = Directory('${appDir.path}/downloads/$slug');
    if (await bookDir.exists()) {
      await bookDir.delete(recursive: true);
    }

    final newState = Map<String, DownloadTask>.from(state);
    newState.remove(slug);
    state = newState;
  }
}

final offlineDownloadsProvider =
    StateNotifierProvider<OfflineDownloadsService, Map<String, DownloadTask>>((
      ref,
    ) {
      final dio = ref.watch(dioProvider);
      return OfflineDownloadsService(dio);
    });
