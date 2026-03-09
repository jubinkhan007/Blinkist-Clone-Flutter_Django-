import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../../../core/networking/api_client.dart';
import '../../book/domain/book_models.dart';

class AudioState {
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
    String? bookSlug,
    String? bookTitle,
    int? totalSections,
    int? currentIndex,
    String? currentSectionTitle,
    Duration? currentPosition,
    Duration? duration,
    bool? isPlaying,
    double? playbackSpeed,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AudioState(
      bookSlug: bookSlug ?? this.bookSlug,
      bookTitle: bookTitle ?? this.bookTitle,
      totalSections: totalSections ?? this.totalSections,
      currentIndex: currentIndex ?? this.currentIndex,
      currentSectionTitle: currentSectionTitle ?? this.currentSectionTitle,
      currentPosition: currentPosition ?? this.currentPosition,
      duration: duration ?? this.duration,
      isPlaying: isPlaying ?? this.isPlaying,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class AudioController extends StateNotifier<AudioState> {
  final AudioPlayer _player = AudioPlayer();
  List<SummarySection> _sections = [];

  AudioController() : super(const AudioState()) {
    _player.positionStream.listen((pos) {
      state = state.copyWith(currentPosition: pos);
    });
    _player.durationStream.listen((dur) {
      state = state.copyWith(duration: dur);
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

  Future<void> loadBook({
    required String bookSlug,
    required String bookTitle,
    required List<SummarySection> sections,
    int startIndex = 0,
    bool autoPlay = false,
  }) async {
    _sections = sections;
    state = state.copyWith(
      bookSlug: bookSlug,
      bookTitle: bookTitle,
      totalSections: sections.length,
      currentIndex: startIndex,
      isLoading: true,
      errorMessage: null,
    );

    if (_sections.isEmpty) {
      await stop(clearQueue: true);
      state = state.copyWith(errorMessage: 'No audio sections available.');
      return;
    }

    final normalizedStartIndex = startIndex.clamp(0, _sections.length - 1);
    final loaded = await _loadSection(normalizedStartIndex);

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

    state = state.copyWith(
      currentIndex: index,
      currentSectionTitle: section.title,
      currentPosition: Duration.zero,
      duration: null,
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
      state = state.copyWith(isLoading: true, errorMessage: null);
      final resolvedUrl = resolveServerUrl(url);
      await _player.setUrl(resolvedUrl);
      state = state.copyWith(isLoading: false);
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
    if (state.currentIndex < _sections.length - 1) {
      skipNext();
    } else {
      state = state.copyWith(isPlaying: false);
    }
  }

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();

  void togglePlayPause() {
    if (state.isPlaying) {
      _player.pause();
    } else {
      _player.play();
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
      return AudioController();
    });
