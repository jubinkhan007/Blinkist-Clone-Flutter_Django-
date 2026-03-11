import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../../../core/networking/api_client.dart';
import '../../book/domain/book_models.dart';

import '../../progress/data/progress_repository.dart';

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
  final AudioPlayer _player = AudioPlayer();
  final ProgressRepository _progressRepository;
  List<SummarySection> _sections = [];

  AudioController(this._progressRepository) : super(const AudioState()) {
    _player.positionStream.listen((pos) {
      state = state.copyWith(currentPosition: pos);
    });
    _player.durationStream.listen((dur) {
      // Only apply when the player resolves a precise value — never wipe with null
      if (dur != null) state = state.copyWith(duration: dur);
    });
    _player.playingStream.listen((playing) {
      state = state.copyWith(isPlaying: playing);
    });
    _player.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        _onSectionComplete();
      }
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

    final normalizedStartIndex = initialIndex.clamp(0, _sections.length - 1);
    final loaded = await _loadSection(normalizedStartIndex);

    if (initialPosition > Duration.zero) {
      await _player.seek(initialPosition);
    }

    if (!autoPlay) return;
    if (loaded) {
      await _player.play();
      return;
    }

    // If the requested section has no audio, try to find the next playable section.
    for (var i = normalizedStartIndex + 1; i < _sections.length; i++) {
      final ok = await _loadSection(i);
      if (ok) {
        await _player.play();
        return;
      }
    }
  }

  Future<bool> _loadSection(int index) async {
    if (index < 0 || index >= _sections.length) return false;
    final section = _sections[index];
    final url = section.audioUrl?.trim();

    // Use the section's known duration immediately so the UI has something to show
    final sectionDuration = section.durationSeconds > 0
        ? Duration(seconds: section.durationSeconds)
        : null;

    // Direct construction — copyWith can't set nullable fields to null
    state = AudioState(
      bookId: state.bookId,
      bookSlug: state.bookSlug,
      bookTitle: state.bookTitle,
      totalSections: state.totalSections,
      currentIndex: index,
      currentSectionTitle: section.title,
      currentPosition: Duration.zero,
      duration: sectionDuration,
      isPlaying: state.isPlaying,
      playbackSpeed: state.playbackSpeed,
      isLoading: true,
      errorMessage: null,
    );

    if (url == null || url.isEmpty) {
      await _player.stop();
      state = state.copyWith(
        isLoading: false,
        isPlaying: false,
        errorMessage: 'No audio for this section.',
      );
      return false;
    }

    try {
      Duration? dur;
      if (url.startsWith('file://')) {
        final path = url.replaceFirst('file://', '');
        dur = await _player.setFilePath(path);
      } else {
        final resolvedUrl = resolveServerUrl(url);
        dur = await _player.setUrl(resolvedUrl);
      }
      // Prefer the precise player duration; fall back to the section metadata
      final effectiveDuration = dur ?? _player.duration ?? sectionDuration;
      state = AudioState(
        bookId: state.bookId,
        bookSlug: state.bookSlug,
        bookTitle: state.bookTitle,
        totalSections: state.totalSections,
        currentIndex: state.currentIndex,
        currentSectionTitle: state.currentSectionTitle,
        currentPosition: Duration.zero,
        duration: effectiveDuration,
        isPlaying: state.isPlaying,
        playbackSpeed: state.playbackSpeed,
        isLoading: false,
        errorMessage: null,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load audio.',
      );
      debugPrint('AudioController error: $e');
      return false;
    }
  }

  void _onSectionComplete() {
    _saveProgress(isFinished: true);
    if (state.currentIndex < _sections.length - 1) {
      skipNext();
    } else {
      state = state.copyWith(isPlaying: false);
    }
  }

  Future<void> play() => _player.play();
  Future<void> pause() async {
    await _player.pause();
    await _saveProgress();
  }

  void togglePlayPause() {
    if (state.isPlaying) {
      pause();
    } else {
      play();
    }
  }

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> skipNext() async {
    for (var i = state.currentIndex + 1; i < _sections.length; i++) {
      final ok = await _loadSection(i);
      if (ok) {
        await _player.play();
        return;
      }
    }
    await _player.stop();
    await _saveProgress();
    state = state.copyWith(isPlaying: false);
  }

  Future<void> skipPrevious() async {
    // If more than 3s in, restart; otherwise go back
    if (state.currentPosition.inSeconds > 3) {
      await _player.seek(Duration.zero);
    } else {
      for (var i = state.currentIndex - 1; i >= 0; i--) {
        final ok = await _loadSection(i);
        if (ok) {
          await _player.play();
          return;
        }
      }
      await _player.stop();
      await _saveProgress();
      state = state.copyWith(isPlaying: false);
    }
  }

  Future<void> jumpToSection(int index) async {
    final ok = await _loadSection(index);
    if (ok) {
      await _player.play();
    }
  }

  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
    state = state.copyWith(playbackSpeed: speed);
  }

  Future<void> stop({bool clearQueue = false}) async {
    await _saveProgress();
    await _player.stop();
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
    _player.dispose();
    super.dispose();
  }
}

final audioControllerProvider =
    StateNotifierProvider<AudioController, AudioState>((ref) {
      final repo = ref.watch(progressRepositoryProvider);
      return AudioController(repo);
    });
