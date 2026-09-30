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
    final sectionsAsync = ref.watch(summarySectionsProvider(widget.slug));
    final audioState = ref.watch(audioControllerProvider);

    return bookAsync.when(
      data: (book) => sectionsAsync.when(
        data: (sections) {
          // Load sections once
          if (!_initialized) {
            _initialized = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final controller = ref.read(audioControllerProvider.notifier);
              final isAlreadyLoaded =
                  audioState.bookSlug == book.slug &&
                  audioState.totalSections == sections.length;
              if (!isAlreadyLoaded) {
                controller.loadBook(
                  bookId: book.id,
                  bookSlug: book.slug,
                  bookTitle: book.title,
                  sections: sections,
                );
              }
            });
          }
          return _PlayerView(book: book, sections: sections);
        },
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      ),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}

class _PlayerView extends ConsumerStatefulWidget {
  final BookDetail book;
  final List<SummarySection> sections;

  const _PlayerView({required this.book, required this.sections});

  @override
  ConsumerState<_PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends ConsumerState<_PlayerView> {
  BookDetail get book => widget.book;
  List<SummarySection> get sections => widget.sections;

  // Dragging state — while scrubbing, freeze the displayed position
  bool _isSeeking = false;
  double _seekValue = 0.0;

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _buildSleepTimerButton(BuildContext context, AudioState audioState) {
    final isTimerActive = audioState.sleepTimerMode != 'off';
    String timerText = '';
    if (audioState.sleepTimerRemaining != null) {
      timerText = _formatDuration(audioState.sleepTimerRemaining!);
    } else if (audioState.sleepTimerMode == 'end_of_chapter') {
      timerText = 'Ch.';
    } else if (audioState.sleepTimerMode == 'end_of_summary') {
      timerText = 'End';
    }

    if (!isTimerActive) {
      return IconButton(
        icon: const Icon(Icons.bedtime_outlined),
        tooltip: 'Sleep Timer',
        onPressed: () => _showSleepTimerSheet(context),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: InkWell(
        onTap: () => _showSleepTimerSheet(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bedtime_rounded,
                size: 14,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 4),
              Text(
                timerText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSleepTimerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final audioState = ref.watch(audioControllerProvider);
          final controller = ref.read(audioControllerProvider.notifier);

          final timerOptions = [
            (mode: 'off', label: 'Off', subtitle: 'Timer inactive'),
            (
              mode: 'end_of_chapter',
              label: 'End of current chapter',
              subtitle: 'Stop when chapter finishes',
            ),
            (mode: '15m', label: '15 minutes', subtitle: 'Pause in 15m'),
            (mode: '30m', label: '30 minutes', subtitle: 'Pause in 30m'),
            (mode: '45m', label: '45 minutes', subtitle: 'Pause in 45m'),
            (mode: '60m', label: '60 minutes', subtitle: 'Pause in 1 hour'),
            (
              mode: 'end_of_summary',
              label: 'End of summary',
              subtitle: 'Stop when entire book finishes',
            ),
          ];

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Icon(
                          Icons.bedtime_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Sleep Timer',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (audioState.sleepTimerRemaining != null) ...[
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _formatDuration(audioState.sleepTimerRemaining!),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: timerOptions.length,
                      itemBuilder: (context, index) {
                        final option = timerOptions[index];
                        final isSelected =
                            audioState.sleepTimerMode == option.mode;

                        return ListTile(
                          title: Text(
                            option.label,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                          ),
                          subtitle: Text(
                            isSelected && audioState.sleepTimerRemaining != null
                                ? '${_formatDuration(audioState.sleepTimerRemaining!)} remaining'
                                : option.subtitle,
                            style: TextStyle(
                              color: isSelected
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primary.withOpacity(0.8)
                                  : null,
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(
                                  Icons.check_circle_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                )
                              : null,
                          onTap: () {
                            controller.setSleepTimer(option.mode);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showSpeedSelectorSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final audioState = ref.watch(audioControllerProvider);
          final controller = ref.read(audioControllerProvider.notifier);

          final speeds = [
            (speed: 0.75, label: '0.75x', description: 'Relaxed & Clear'),
            (speed: 1.0, label: '1.0x', description: 'Normal (Standard speed)'),
            (
              speed: 1.25,
              label: '1.25x',
              description: 'Recommended (Optimal retention)',
            ),
            (speed: 1.5, label: '1.5x', description: 'Brisk (Quick listen)'),
            (speed: 1.75, label: '1.75x', description: 'Fast (Time saver)'),
            (speed: 2.0, label: '2.0x', description: 'Super Fast (Skim)'),
          ];

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Icon(
                          Icons.speed_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Playback Speed',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: speeds.length,
                      itemBuilder: (context, index) {
                        final item = speeds[index];
                        final isSelected =
                            (audioState.playbackSpeed - item.speed).abs() < 0.01;

                        return ListTile(
                          leading: Container(
                            width: 54,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer
                                  : Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              item.label,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer
                                    : null,
                              ),
                            ),
                          ),
                          title: Text(
                            item.label,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                          ),
                          subtitle: Text(item.description),
                          trailing: isSelected
                              ? Icon(
                                  Icons.check_circle_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                )
                              : null,
                          onTap: () {
                            controller.setSpeed(item.speed);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showChapterDrawer(BuildContext context) {
    int totalSeconds = 0;
    for (final s in sections) {
      totalSeconds += s.durationSeconds > 0
          ? s.durationSeconds
          : (s.estimatedReadMinutes * 60);
    }
    final totalMin = (totalSeconds / 60).ceil();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final audioState = ref.watch(audioControllerProvider);

          return SafeArea(
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chapters',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${sections.length} chapters • $totalMin min total',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: sections.length,
                    itemBuilder: (context, i) {
                      final section = sections[i];
                      final isCurrent = i == audioState.currentIndex;
                      final isCompleted =
                          audioState.completedSectionIds.contains(section.id) ||
                              (audioState.bookSlug == book.slug &&
                                  i < audioState.currentIndex);
                      final durationSec = section.durationSeconds > 0
                          ? section.durationSeconds
                          : (section.estimatedReadMinutes * 60);
                      final durationText = durationSec > 0
                          ? '${(durationSec / 60).ceil()} min'
                          : '';

                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? Theme.of(
                                  context,
                                ).colorScheme.primaryContainer.withOpacity(0.3)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: isCurrent
                              ? Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withOpacity(0.5),
                                )
                              : null,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isCurrent
                                ? Theme.of(context).colorScheme.primary
                                : (isCompleted
                                    ? Colors.teal.shade50
                                    : Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest),
                            child: isCurrent
                                ? const Icon(
                                    Icons.graphic_eq_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  )
                                : (isCompleted
                                    ? const Icon(
                                        Icons.check_circle_rounded,
                                        color: Colors.teal,
                                        size: 20,
                                      )
                                    : Text(
                                        '${i + 1}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      )),
                          ),
                          title: Text(
                            section.title,
                            style: TextStyle(
                              fontWeight: isCurrent
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isCurrent
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                          ),
                          subtitle: isCurrent
                              ? Text(
                                  'Now playing',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                )
                              : (isCompleted
                                  ? const Text(
                                      'Completed',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.teal,
                                      ),
                                    )
                                  : null),
                          trailing: Text(
                            durationText,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            ref
                                .read(audioControllerProvider.notifier)
                                .jumpToSection(i);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final audioState = ref.watch(audioControllerProvider);
    final controller = ref.read(audioControllerProvider.notifier);
    final isThisBook = audioState.bookSlug == book.slug;
    final currentSection = audioState.currentIndex < sections.length
        ? (isThisBook ? sections[audioState.currentIndex] : null)
        : null;
    final total = sections.length;
    final current = audioState.currentIndex + 1;

    final position = audioState.currentPosition;
    final rawDuration = audioState.duration;
    final fallbackDurationSeconds = currentSection == null
        ? 0
        : (currentSection.durationSeconds > 0
              ? currentSection.durationSeconds
              : (currentSection.estimatedReadMinutes * 60));
    final uiDuration = (rawDuration != null && rawDuration > Duration.zero)
        ? rawDuration
        : (fallbackDurationSeconds > 0
              ? Duration(seconds: fallbackDurationSeconds)
              : Duration.zero);
    final progress = uiDuration.inMilliseconds > 0
        ? position.inMilliseconds / uiDuration.inMilliseconds
        : 0.0;

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
          _buildSleepTimerButton(context, audioState),
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 4),
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
                                      (_seekValue * uiDuration.inMilliseconds)
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
                          onChanged: uiDuration.inMilliseconds <= 0
                              ? null
                              : (val) {
                                  setState(() => _seekValue = val);
                                },
                          onChangeStart: (val) {
                            setState(() {
                              _isSeeking = true;
                              _seekValue = val;
                            });
                          },
                          onChangeEnd: uiDuration.inMilliseconds <= 0
                              ? null
                              : (val) {
                                  final newPos = Duration(
                                    milliseconds:
                                        (val * uiDuration.inMilliseconds)
                                            .round(),
                                  );
                                  controller.seek(newPos);
                                  setState(() => _isSeeking = false);
                                },
                        ),
                      ),
                      Text(
                        _formatDuration(uiDuration),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                // Playback controls
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 8, bottom: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Speed selector button
                      InkWell(
                        onTap: () => _showSpeedSelectorSheet(context),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant
                                  .withOpacity(0.5),
                            ),
                          ),
                          child: Text(
                            '${audioState.playbackSpeed.toStringAsFixed(audioState.playbackSpeed.truncateToDouble() == audioState.playbackSpeed ? 1 : 2)}x',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
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
                            uiDuration == Duration.zero
                                ? newPos
                                : (newPos > uiDuration ? uiDuration : newPos),
                          );
                        },
                      ),
                      // Chapters list
                      IconButton(
                        icon: const Icon(Icons.list),
                        tooltip: 'Chapters',
                        onPressed: () => _showChapterDrawer(context),
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
