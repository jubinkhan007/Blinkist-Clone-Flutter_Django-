import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../../../../main.dart';
import '../../book/domain/book_models.dart';
import '../../progress/data/progress_repository.dart';
import '../data/audio_handler.dart';

class AudioState {
  static const Object _unset = Object();

  final int? bookId;
  final String? bookSlug;
  final String? bookTitle;
  final int totalSections;
  final int currentIndex;
  final String? currentSectionTitle;
  final Duration currentPosition;
  final Duration? duration;
  final bool isPlaying;
  final double playbackSpeed;
  final bool isLoading;
  final String? errorMessage;

  const AudioState({
    this.bookId,
    this.bookSlug,
    this.bookTitle,
    this.totalSections = 0,
    this.currentIndex = 0,
    this.currentSectionTitle,
    this.currentPosition = Duration.zero,
    this.duration,
    this.isPlaying = false,
    this.playbackSpeed = 1.0,
    this.isLoading = false,
    this.errorMessage,
  });

  AudioState copyWith({
    Object? bookId = _unset,
    Object? bookSlug = _unset,
    Object? bookTitle = _unset,
    int? totalSections,
    int? currentIndex,
    Object? currentSectionTitle = _unset,
    Duration? currentPosition,
    Object? duration = _unset,
    bool? isPlaying,
    double? playbackSpeed,
    bool? isLoading,
    Object? errorMessage = _unset,
  }) {
    return AudioState(
      bookId: bookId == _unset ? this.bookId : bookId as int?,
      bookSlug: bookSlug == _unset ? this.bookSlug : bookSlug as String?,
      bookTitle: bookTitle == _unset ? this.bookTitle : bookTitle as String?,
      totalSections: totalSections ?? this.totalSections,
      currentIndex: currentIndex ?? this.currentIndex,
      currentSectionTitle: currentSectionTitle == _unset
          ? this.currentSectionTitle
          : currentSectionTitle as String?,
      currentPosition: currentPosition ?? this.currentPosition,
      duration: duration == _unset ? this.duration : duration as Duration?,
      isPlaying: isPlaying ?? this.isPlaying,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage == _unset
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class AudioController extends StateNotifier<AudioState> {
  final AppAudioHandler _handler;
  final ProgressRepository _progressRepository;
  List<SummarySection> _sections = [];

  AudioController(this._handler, this._progressRepository) : super(const AudioState()) {
    _init();
  }

  void _init() {
    // Listen to playback state changes
    _handler.playbackState.listen((ps) {
      state = state.copyWith(
        isPlaying: ps.playing,
        playbackSpeed: ps.speed,
        isLoading: ps.processingState == AudioProcessingState.loading ||
            ps.processingState == AudioProcessingState.buffering,
      );

      if (ps.processingState == AudioProcessingState.completed) {
        _onSectionComplete();
      }
    });

    // Listen to current media item changes
    _handler.mediaItem.listen((item) {
      if (item != null) {
        final index = _sections.indexWhere((s) => s.id.toString() == item.id || s.title == item.title);
        state = state.copyWith(
          currentIndex: index >= 0 ? index : state.currentIndex,
          currentSectionTitle: item.title,
          duration: item.duration,
          bookId: item.extras?['bookId'],
          bookSlug: item.extras?['bookSlug'],
          bookTitle: item.extras?['bookTitle'],
        );
      }
    });

    // Listen to position changes
    AudioService.position.listen((pos) {
      state = state.copyWith(currentPosition: pos);
    });
  }

  Future<void> _saveProgress({bool isFinished = false}) async {
    if (state.bookId == null || currentSection == null) return;
    try {
      await _progressRepository.saveAudioProgress(
        bookId: state.bookId!,
        sectionId: currentSection!.id,
        positionSeconds: state.currentPosition.inSeconds.toDouble(),
        isFinished: isFinished,
      );
    } catch (e) {
      debugPrint('Failed to save audio progress: $e');
    }
  }

  Future<void> loadBook({
    required int bookId,
    required String bookSlug,
    required String bookTitle,
    required List<SummarySection> sections,
    int? startIndex,
    bool autoPlay = false,
  }) async {
    _sections = sections;
    int initialIndex = startIndex ?? 0;
    Duration initialPosition = Duration.zero;

    if (startIndex == null) {
      try {
        final progress = await _progressRepository.getAudioProgress(bookId);
        if (progress.currentSectionId != null) {
          final idx = sections.indexWhere(
            (s) => s.id == progress.currentSectionId,
          );
          if (idx >= 0) {
            initialIndex = idx;
            initialPosition = Duration(
              seconds: progress.currentPositionSeconds.toInt(),
            );
          }
        }
      } catch (e) {
        debugPrint('Failed to load audio progress (might be first time): $e');
      }
    }

    state = state.copyWith(
      bookId: bookId,
      bookSlug: bookSlug,
      bookTitle: bookTitle,
      totalSections: sections.length,
      currentIndex: initialIndex,
      isLoading: true,
      errorMessage: null,
    );

    if (_sections.isEmpty) {
      await stop(clearQueue: true);
      state = state.copyWith(errorMessage: 'No audio sections available.');
      return;
    }

    // Filter sections that have audio
    final playableSections = _sections.where((s) => s.audioUrl != null && s.audioUrl!.isNotEmpty).toList();
    
    if (playableSections.isEmpty) {
      state = state.copyWith(isLoading: false, errorMessage: 'No audio sections available.');
      return;
    }

    final mediaItems = playableSections.map((s) => MediaItem(
      id: s.audioUrl!,
      album: bookTitle,
      title: s.title,
      artist: 'Blinkist Clone', // Could be book author if available
      duration: s.durationSeconds > 0 ? Duration(seconds: s.durationSeconds) : null,
      extras: {
        'bookId': bookId,
        'bookSlug': bookSlug,
        'bookTitle': bookTitle,
        'sectionId': s.id,
      },
    )).toList();

    // Find the adjusted initial index in the playable list
    final targetSectionId = _sections[initialIndex.clamp(0, _sections.length - 1)].id;
    int adjustedIndex = mediaItems.indexWhere((item) => item.extras?['sectionId'] == targetSectionId);
    if (adjustedIndex < 0) adjustedIndex = 0;

    try {
      await _handler.loadPlaylist(mediaItems, initialIndex: adjustedIndex);
      
      if (initialPosition > Duration.zero) {
        await _handler.seek(initialPosition);
      }

      if (autoPlay) {
        await _handler.play();
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load audio.',
      );
      debugPrint('AudioController error: $e');
    }
  }

  void _onSectionComplete() {
    _saveProgress(isFinished: true);
    // audio_service / just_audio handles skipping to next in playlist
  }

  Future<void> play() => _handler.play();
  Future<void> pause() async {
    await _handler.pause();
    await _saveProgress();
  }

  void togglePlayPause() {
    if (state.isPlaying) {
      pause();
    } else {
      play();
    }
  }

  Future<void> seek(Duration position) => _handler.seek(position);

  Future<void> skipNext() => _handler.skipToNext();

  Future<void> skipPrevious() => _handler.skipToPrevious();

  Future<void> jumpToSection(int index) async {
    final sectionId = _sections[index].id;
    final queue = _handler.queue.value;
    final queueIndex = queue.indexWhere((item) => item.extras?['sectionId'] == sectionId);
    
    if (queueIndex >= 0) {
      await _handler.skipToQueueItem(queueIndex);
      await _handler.play();
    } else {
      // If section not in queue (maybe it had no audio), we can't jump to it
      state = state.copyWith(errorMessage: 'No audio for this section.');
    }
  }

  Future<void> setSpeed(double speed) async {
    await _handler.setPlaybackSpeed(speed);
    // state is updated via listener
  }

  Future<void> stop({bool clearQueue = false}) async {
    await _saveProgress();
    await _handler.stop();
    if (clearQueue) {
      _sections = [];
      state = const AudioState();
      return;
    }
    state = state.copyWith(
      isPlaying: false,
      isLoading: false,
      currentPosition: Duration.zero,
      duration: null,
      errorMessage: null,
    );
  }

  SummarySection? get currentSection {
    if (_sections.isEmpty || state.currentIndex >= _sections.length)
      return null;
    return _sections[state.currentIndex];
  }

  List<SummarySection> get sections => _sections;

  @override
  void dispose() {
    // We don't dispose the handler here as it's a singleton in main
    super.dispose();
  }
}

final audioControllerProvider =
    StateNotifierProvider<AudioController, AudioState>((ref) {
      final repo = ref.watch(progressRepositoryProvider);
      final handler = ref.watch(audioHandlerProvider);
      return AudioController(handler, repo);
    });
