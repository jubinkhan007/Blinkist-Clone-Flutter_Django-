import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../book/data/content_repository.dart';
import '../../book/domain/book_models.dart';
import 'audio_controller.dart';

class AudioPlayerScreen extends ConsumerStatefulWidget {
  final String slug;

  const AudioPlayerScreen({super.key, required this.slug});

  @override
  ConsumerState<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends ConsumerState<AudioPlayerScreen> {
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final bookAsync = ref.watch(bookDetailProvider(widget.slug));
    final audioState = ref.watch(audioControllerProvider);

    return bookAsync.when(
      data: (book) {
        // Load sections once
        if (!_initialized) {
          _initialized = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final controller = ref.read(audioControllerProvider.notifier);
            final isAlreadyLoaded =
                audioState.bookSlug == book.slug &&
                audioState.totalSections == book.sections.length;
            if (!isAlreadyLoaded) {
              controller.loadBook(
                bookId: book.id,
                bookSlug: book.slug,
                bookTitle: book.title,
                sections: book.sections,
              );
            }
          });
        }
        return _PlayerView(book: book);
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}

class _PlayerView extends ConsumerStatefulWidget {
  final BookDetail book;

  const _PlayerView({required this.book});

  @override
  ConsumerState<_PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends ConsumerState<_PlayerView> {
  BookDetail get book => widget.book;

  // Dragging state — while scrubbing, freeze the displayed position
  bool _isSeeking = false;
  double _seekValue = 0.0;

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _showChapterDrawer(BuildContext context, AudioState audioState) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Chapters',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: book.sections.length,
              itemBuilder: (_, i) {
                final section = book.sections[i];
                final isCurrent = i == audioState.currentIndex;
                final duration = section.durationSeconds > 0
                    ? '${(section.durationSeconds / 60).ceil()} min'
                    : '';
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isCurrent
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(color: isCurrent ? Colors.white : null),
                    ),
                  ),
                  title: Text(
                    section.title,
                    style: TextStyle(
                      fontWeight: isCurrent ? FontWeight.bold : null,
                    ),
                  ),
                  trailing: Text(
                    duration,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    ref.read(audioControllerProvider.notifier).jumpToSection(i);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final audioState = ref.watch(audioControllerProvider);
    final controller = ref.read(audioControllerProvider.notifier);
    final isThisBook = audioState.bookSlug == book.slug;
    final currentSection = audioState.currentIndex < book.sections.length
        ? (isThisBook ? book.sections[audioState.currentIndex] : null)
        : null;
    final total = book.sections.length;
    final current = audioState.currentIndex + 1;

    final position = audioState.currentPosition;
    final duration = audioState.duration ?? Duration.zero;
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;
    final remaining = duration - position;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              book.title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            if (currentSection != null)
              Text(
                currentSection.title,
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Text(
                '$current of $total',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Scrollable section text (read-along)
          Expanded(
            child: currentSection == null
                ? const Center(child: Text('Loading audio…'))
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 32,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentSection.title,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        if (audioState.errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber,
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    audioState.errorMessage!,
                                    style: const TextStyle(
                                      color: Colors.orange,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Text(
                          currentSection.content ??
                              'No text available for this section.',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.copyWith(height: 1.7),
                        ),
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
          ),

          // Bottom player controls
          Container(
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Divider(height: 1),
                // Seek bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Text(
                        _isSeeking
                            ? _formatDuration(
                                Duration(
                                  milliseconds:
                                      (_seekValue * duration.inMilliseconds)
                                          .round(),
                                ),
                              )
                            : _formatDuration(position),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Expanded(
                        child: Slider(
                          value: _isSeeking
                              ? _seekValue
                              : progress.clamp(0.0, 1.0),
                          onChangeStart: (val) {
                            setState(() {
                              _isSeeking = true;
                              _seekValue = val;
                            });
                          },
                          onChanged: (val) {
                            setState(() => _seekValue = val);
                          },
                          onChangeEnd: (val) {
                            final newPos = Duration(
                              milliseconds: (val * duration.inMilliseconds)
                                  .round(),
                            );
                            controller.seek(newPos);
                            setState(() => _isSeeking = false);
                          },
                        ),
                      ),
                      Text(() {
                        final displayPos = _isSeeking
                            ? Duration(
                                milliseconds:
                                    (_seekValue * duration.inMilliseconds)
                                        .round(),
                              )
                            : position;
                        final rem = duration - displayPos;
                        return '-${_formatDuration(rem.isNegative ? Duration.zero : rem)}';
                      }(), style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                // Playback controls
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 8, bottom: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Speed control
                      TextButton(
                        onPressed: () {
                          const speeds = [1.0, 1.25, 1.5, 2.0];
                          final currentIdx = speeds.indexOf(
                            audioState.playbackSpeed,
                          );
                          final nextSpeed =
                              speeds[(currentIdx + 1) % speeds.length];
                          controller.setSpeed(nextSpeed);
                        },
                        child: Text('${audioState.playbackSpeed}x'),
                      ),
                      // Seek back 15s
                      _SeekButton(
                        seconds: -15,
                        onTap: () {
                          final newPos = position - const Duration(seconds: 15);
                          controller.seek(
                            newPos.isNegative ? Duration.zero : newPos,
                          );
                        },
                      ),
                      // Play / Pause
                      audioState.isLoading
                          ? const SizedBox(
                              width: 56,
                              height: 56,
                              child: CircularProgressIndicator(),
                            )
                          : IconButton(
                              iconSize: 56,
                              icon: Icon(
                                audioState.isPlaying
                                    ? Icons.pause_circle
                                    : Icons.play_circle,
                              ),
                              onPressed: () => controller.togglePlayPause(),
                            ),
                      // Seek forward 30s
                      _SeekButton(
                        seconds: 30,
                        onTap: () {
                          final newPos = position + const Duration(seconds: 30);
                          controller.seek(
                            newPos > duration ? duration : newPos,
                          );
                        },
                      ),
                      // Chapters list
                      IconButton(
                        icon: const Icon(Icons.list),
                        tooltip: 'Chapters',
                        onPressed: () =>
                            _showChapterDrawer(context, audioState),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeekButton extends StatelessWidget {
  final int seconds; // negative = rewind, positive = forward
  final VoidCallback onTap;

  const _SeekButton({required this.seconds, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isForward = seconds > 0;
    return GestureDetector(
      onTap: onTap,
      child: Icon(isForward ? Icons.forward_30 : Icons.replay_10, size: 36),
    );
  }
}
