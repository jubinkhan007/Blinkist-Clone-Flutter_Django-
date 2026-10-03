import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/networking/api_client.dart';
import '../../book/data/content_repository.dart';
import '../../book/domain/book_models.dart';
import '../data/audio_bookmark_repository.dart';
import 'audio_controller.dart';

class AudioPlayerScreen extends ConsumerStatefulWidget {
  final String slug;
  final int? initialSectionIndex;
  final int? initialPositionSeconds;

  const AudioPlayerScreen({
    super.key,
    required this.slug,
    this.initialSectionIndex,
    this.initialPositionSeconds,
  });

  @override
  ConsumerState<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends ConsumerState<AudioPlayerScreen> {
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final audioState = ref.watch(audioControllerProvider);
    final activeSlug = (_initialized && audioState.bookSlug != null)
        ? audioState.bookSlug!
        : widget.slug;

    final bookAsync = ref.watch(bookDetailProvider(activeSlug));
    final sectionsAsync = ref.watch(summarySectionsProvider(activeSlug));

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
              if (!isAlreadyLoaded ||
                  widget.initialSectionIndex != null ||
                  widget.initialPositionSeconds != null) {
                if (isAlreadyLoaded &&
                    (widget.initialSectionIndex != null ||
                        widget.initialPositionSeconds != null)) {
                  final targetSec =
                      widget.initialSectionIndex ?? audioState.currentIndex;
                  final targetPos = widget.initialPositionSeconds != null
                      ? Duration(seconds: widget.initialPositionSeconds!)
                      : Duration.zero;
                  controller.jumpToSectionAndSeek(targetSec, targetPos);
                } else {
                  controller.loadBook(
                    bookId: book.id,
                    bookSlug: book.slug,
                    bookTitle: book.title,
                    authorName: book.author.name,
                    coverImageUrl: book.coverImageUrl,
                    sections: sections,
                    startIndex: widget.initialSectionIndex,
                    startPosition: widget.initialPositionSeconds != null
                        ? Duration(seconds: widget.initialPositionSeconds!)
                        : null,
                    autoPlay: widget.initialSectionIndex != null ||
                        widget.initialPositionSeconds != null,
                  );
                }
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

  void _showQueueSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final audioState = ref.watch(audioControllerProvider);
          final controller = ref.read(audioControllerProvider.notifier);
          final queue = audioState.queue;

          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.4,
            maxChildSize: 0.92,
            expand: false,
            builder: (context, scrollController) {
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Audio Queue',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${queue.length} ${queue.length == 1 ? 'summary' : 'summaries'} up next',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          const Spacer(),
                          if (queue.isNotEmpty)
                            TextButton.icon(
                              onPressed: () => controller.clearQueue(),
                              icon: const Icon(Icons.clear_all, size: 18),
                              label: const Text('Clear'),
                              style: TextButton.styleFrom(
                                foregroundColor:
                                    Theme.of(context).colorScheme.error,
                              ),
                            ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    // Auto-play switch
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.repeat_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Auto-play Next Summary',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    'Advance automatically when summary ends',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: audioState.autoPlayNext,
                              onChanged: (_) => controller.toggleAutoPlayNext(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Now playing banner
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'NOW PLAYING',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                audioState.bookTitle ?? book.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (audioState.isPlaying)
                              Icon(
                                Icons.graphic_eq_rounded,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    // Queue list or empty state
                    Expanded(
                      child: queue.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.queue_music_outlined,
                                      size: 56,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outlineVariant,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Queue is empty',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Add summaries from book pages or themed collections to listen continuously.',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ReorderableListView.builder(
                              scrollController: scrollController,
                              buildDefaultDragHandles: false,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              itemCount: queue.length,
                              onReorder: (oldIndex, newIndex) {
                                controller.reorderQueue(oldIndex, newIndex);
                              },
                              itemBuilder: (context, index) {
                                final item = queue[index];
                                final hasCover =
                                    item.coverImageUrl != null &&
                                    item.coverImageUrl!.isNotEmpty;

                                return Container(
                                  key: ValueKey(item.slug),
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        Theme.of(context).colorScheme.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outlineVariant
                                          .withOpacity(0.5),
                                    ),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    leading: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: hasCover
                                          ? Image.network(
                                              resolveServerUrl(
                                                item.coverImageUrl!,
                                              ),
                                              width: 44,
                                              height: 44,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (_, __, ___) => Container(
                                                    width: 44,
                                                    height: 44,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .surfaceContainerHighest,
                                                    child: const Icon(
                                                      Icons.book,
                                                      size: 20,
                                                    ),
                                                  ),
                                            )
                                          : Container(
                                              width: 44,
                                              height: 44,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerHighest,
                                              child: const Icon(
                                                Icons.book,
                                                size: 20,
                                              ),
                                            ),
                                    ),
                                    title: Text(
                                      item.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      '${item.authorName} • ~${item.estimatedMinutes} min',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.play_circle_outline_rounded,
                                          ),
                                          tooltip: 'Play Now',
                                          onPressed: () {
                                            controller.playQueuedBook(index);
                                            Navigator.pop(context);
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.remove_circle_outline_rounded,
                                            color: Colors.grey,
                                          ),
                                          tooltip: 'Remove',
                                          onPressed: () {
                                            controller.removeFromQueue(index);
                                          },
                                        ),
                                        ReorderableDragStartListener(
                                          index: index,
                                          child: const Icon(
                                            Icons.drag_handle_rounded,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showBookmarkSheet(BuildContext context) {
    final audioState = ref.read(audioControllerProvider);
    final curIndex = audioState.currentIndex;
    final currentSection =
        curIndex < sections.length ? sections[curIndex] : null;
    final positionSec = audioState.currentPosition.inSeconds;
    final formattedTime = _formatDuration(audioState.currentPosition);
    final noteController = TextEditingController();
    final titleController = TextEditingController(
      text: currentSection != null
          ? currentSection.title
          : 'Bookmark @ $formattedTime',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom,
        ),
        child: Consumer(
          builder: (context, ref, _) {
            final bookBookmarksAsync =
                ref.watch(bookAudioBookmarksProvider(book.slug));

            return SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.bookmark_add_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Save Audio Bookmark',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(bottomSheetContext),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withOpacity(0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.timer_outlined,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    formattedTime,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                currentSection?.title ?? book.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Personal Note / Takeaway (Optional)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: noteController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText:
                              'What inspired you at this moment in the summary?',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withOpacity(0.7),
                          ),
                          filled: true,
                          fillColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withOpacity(0.3),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color:
                                  Theme.of(context).colorScheme.outlineVariant,
                            ),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.bookmark_added_rounded,
                              size: 18),
                          label: const Text('Save Bookmark to Notebook'),
                          onPressed: () async {
                            final note = noteController.text.trim();
                            final title = titleController.text.trim();
                            try {
                              await ref
                                  .read(audioBookmarkRepositoryProvider)
                                  .createBookmark(
                                    bookSlug: book.slug,
                                    sectionId: currentSection?.id,
                                    timestampSeconds: positionSec,
                                    title: title,
                                    note: note,
                                  );
                              ref.invalidate(userAudioBookmarksProvider);
                              ref.invalidate(
                                bookAudioBookmarksProvider(book.slug),
                              );
                              if (bottomSheetContext.mounted) {
                                Navigator.pop(bottomSheetContext);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Saved bookmark at $formattedTime to My Notebook!',
                                    ),
                                    action: SnackBarAction(
                                      label: 'View Notebook',
                                      onPressed: () => context.go('/library'),
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (bottomSheetContext.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to save bookmark: $e'),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      bookBookmarksAsync.when(
                        data: (bookmarks) {
                          if (bookmarks.isEmpty) return const SizedBox.shrink();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Divider(),
                              const SizedBox(height: 8),
                              Text(
                                'Saved Bookmarks in this Book (${bookmarks.length})',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: bookmarks.length,
                                itemBuilder: (context, i) {
                                  final bm = bookmarks[i];
                                  return Container(
                                    margin:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: ListTile(
                                      dense: true,
                                      leading: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primaryContainer,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          bm.displayTimestamp,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onPrimaryContainer,
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        bm.sectionTitle ?? bm.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: bm.note.isNotEmpty
                                          ? Text(
                                              bm.note,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            )
                                          : null,
                                      trailing: IconButton(
                                        icon: const Icon(
                                          Icons.play_circle_outline_rounded,
                                          size: 22,
                                        ),
                                        tooltip: 'Jump to timestamp',
                                        onPressed: () {
                                          final secIdx = sections.indexWhere(
                                            (s) => s.id == bm.sectionId,
                                          );
                                          final targetIdx =
                                              secIdx >= 0 ? secIdx : curIndex;
                                          ref
                                              .read(
                                                audioControllerProvider.notifier,
                                              )
                                              .jumpToSectionAndSeek(
                                                targetIdx,
                                                Duration(
                                                  seconds: bm.timestampSeconds,
                                                ),
                                              );
                                          Navigator.pop(bottomSheetContext);
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
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
          IconButton(
            icon: const Icon(Icons.bookmark_add_outlined),
            tooltip: 'Save Bookmark',
            onPressed: () => _showBookmarkSheet(context),
          ),
          IconButton(
            icon: Badge.count(
              count: audioState.queue.length,
              isLabelVisible: audioState.queue.isNotEmpty,
              child: const Icon(Icons.queue_music_rounded),
            ),
            tooltip: 'Audio Queue',
            onPressed: () => _showQueueSheet(context),
          ),
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
                // Quick Bookmark bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Spacer(),
                      InkWell(
                        onTap: () => _showBookmarkSheet(context),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withOpacity(0.3),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.bookmark_add_rounded,
                                size: 14,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Bookmark @ ${_formatDuration(position)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
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
                      // Audio Queue
                      IconButton(
                        icon: Badge.count(
                          count: audioState.queue.length,
                          isLabelVisible: audioState.queue.isNotEmpty,
                          child: const Icon(Icons.queue_music_rounded),
                        ),
                        tooltip: 'Audio Queue',
                        onPressed: () => _showQueueSheet(context),
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
