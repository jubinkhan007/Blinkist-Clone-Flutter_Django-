import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import '../../../../core/networking/api_client.dart';

/// An [AudioHandler] that uses [just_audio] for playback.
class AppAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final _player = AudioPlayer();
  final _playlist = ConcatenatingAudioSource(children: []);
  bool _playInterrupted = false;

  AppAudioHandler() {
    _init();
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());

    // Interruption handling (calls, navigation ducking, alarms)
    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        switch (event.type) {
          case AudioInterruptionType.duck:
            _player.setVolume(0.25);
            break;
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            if (_player.playing) {
              _playInterrupted = true;
              _player.pause();
            }
            break;
        }
      } else {
        switch (event.type) {
          case AudioInterruptionType.duck:
            _player.setVolume(1.0);
            break;
          case AudioInterruptionType.pause:
            if (_playInterrupted) {
              _playInterrupted = false;
              _player.play();
            }
            break;
          case AudioInterruptionType.unknown:
            _playInterrupted = false;
            break;
        }
      }
    });

    // Auto-pause when headphones unplugged or Bluetooth disconnected
    session.becomingNoisyEventStream.listen((_) {
      _player.pause();
    });

    // Broadcast state changes from the player to audio_service
    _player.playbackEventStream.listen(_broadcastState);

    // Listen to index changes to update the current MediaItem
    _player.currentIndexStream.listen((index) {
      if (index != null && queue.value.isNotEmpty && index < queue.value.length) {
        mediaItem.add(queue.value[index]);
      }
    });

    // Real-time duration sync for lock-screen scrubbers
    _player.durationStream.listen((duration) {
      if (duration != null && mediaItem.value != null) {
        if (mediaItem.value!.duration != duration) {
          mediaItem.add(mediaItem.value!.copyWith(duration: duration));
        }
      }
    });

    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        // Just_audio handles sequence automatically
      }
    });
  }

  /// Broadcasts the current player state to the system lock-screen and notifications.
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
      androidCompactActionIndices: const [0, 2, 4], // Rewind 15s, Play/Pause, FastForward 15s
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
  Future<void> play() async {
    final session = await AudioSession.instance;
    await session.setActive(true);
    return _player.play();
  }

  @override
  Future<void> pause() {
    _playInterrupted = false;
    return _player.pause();
  }

  @override
  Future<void> stop() async {
    _playInterrupted = false;
    await _player.stop();
    final session = await AudioSession.instance;
    await session.setActive(false);
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> fastForward() async {
    final current = _player.position;
    final total = _player.duration;
    final target = current + const Duration(seconds: 15);
    if (total != null && target > total) {
      await _player.seek(total);
    } else {
      await _player.seek(target);
    }
  }

  @override
  Future<void> rewind() async {
    final current = _player.position;
    final target = current - const Duration(seconds: 15);
    if (target.isNegative) {
      await _player.seek(Duration.zero);
    } else {
      await _player.seek(target);
    }
  }

  @override
  Future<void> seekForward(bool begin) async {
    if (begin) {
      await fastForward();
    }
  }

  @override
  Future<void> seekBackward(bool begin) async {
    if (begin) {
      await rewind();
    }
  }

  @override
  Future<void> click([MediaButton button = MediaButton.media]) async {
    switch (button) {
      case MediaButton.media:
        if (_player.playing) {
          await pause();
        } else {
          await play();
        }
        break;
      case MediaButton.next:
        await skipToNext();
        break;
      case MediaButton.previous:
        await skipToPrevious();
        break;
    }
  }

  @override
  Future<dynamic> customAction(String name, [Map<String, dynamic>? extras]) async {
    switch (name) {
      case 'skip15Forward':
        await fastForward();
        return true;
      case 'skip15Backward':
        await rewind();
        return true;
      default:
        return super.customAction(name, extras);
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
