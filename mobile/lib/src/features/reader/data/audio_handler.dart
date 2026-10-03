import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import '../../../../core/networking/api_client.dart';

/// An [AudioHandler] that uses [just_audio] for playback.
class AppAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final _player = AudioPlayer();
  final _playlist = ConcatenatingAudioSource(children: []);

  AppAudioHandler() {
    _init();
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());

    // Broadcast state changes from the player to audio_service
    _player.playbackEventStream.listen(_broadcastState);

    // Listen to index changes to update the current MediaItem
    _player.currentIndexStream.listen((index) {
      if (index != null && queue.value.isNotEmpty && index < queue.value.length) {
        mediaItem.add(queue.value[index]);
      }
    });

    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        // Just_audio handles sequence automatically
      }
    });
  }

  /// Broadcasts the current player state to the system.
  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.rewind,
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.fastForward,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.fastForward,
        MediaAction.rewind,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
      },
      androidCompactActionIndices: const [1, 2, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    ));
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> fastForward() async {
    final newPos = _player.position + const Duration(seconds: 30);
    final total = _player.duration;
    if (total != null && newPos > total) {
      await _player.seek(total);
    } else {
      await _player.seek(newPos);
    }
  }

  @override
  Future<void> rewind() async {
    final newPos = _player.position - const Duration(seconds: 15);
    if (newPos.isNegative) {
      await _player.seek(Duration.zero);
    } else {
      await _player.seek(newPos);
    }
  }

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() async {
    if (_player.position.inSeconds > 3) {
      _player.seek(Duration.zero);
    } else {
      _player.seekToPrevious();
    }
  }

  @override
  Future<void> skipToQueueItem(int index) => _player.seek(Duration.zero, index: index);

  /// Custom method to load a book into the handler.
  Future<void> loadPlaylist(List<MediaItem> items, {int initialIndex = 0}) async {
    final sources = items.map((item) {
      final uri = Uri.parse(item.id);
      if (uri.scheme == 'file') {
        return AudioSource.file(uri.toFilePath(), tag: item);
      } else {
        final resolvedUrl = resolveServerUrl(item.id);
        return AudioSource.uri(Uri.parse(resolvedUrl), tag: item);
      }
    }).toList();

    _playlist.clear();
    await _playlist.addAll(sources);
    queue.add(items);
    
    await _player.setAudioSource(
      _playlist,
      initialIndex: initialIndex,
    );
  }

  Future<void> setPlaybackSpeed(double speed) => _player.setSpeed(speed);

  AudioPlayer get player => _player;
}
