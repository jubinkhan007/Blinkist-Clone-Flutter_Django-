import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../book/data/content_repository.dart';
import '../../progress/data/progress_repository.dart';
import 'audio_controller.dart';
import 'reader_options_provider.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  final String slug;

  const ReaderScreen({super.key, required this.slug});

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showTypographyModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Typography Settings',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              const Text('Font Size'),
              Consumer(
                builder: (context, ref, child) {
                  final options = ref.watch(readerOptionsProvider);
                  return Slider(
                    value: options.fontSize,
                    min: 12.0,
                    max: 32.0,
                    divisions: 10,
                    onChanged: (val) => ref
                        .read(readerOptionsProvider.notifier)
                        .updateFontSize(val),
                  );
                },
              ),
              const SizedBox(height: 16),
              const Text('Theme'),
              Consumer(
                builder: (context, ref, child) {
                  final options = ref.watch(readerOptionsProvider);
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ChoiceChip(
                        label: const Text('Light'),
                        selected: options.theme == 'light',
                        onSelected: (_) => ref
                            .read(readerOptionsProvider.notifier)
                            .updateTheme('light'),
                      ),
                      ChoiceChip(
                        label: const Text('Dark'),
                        selected: options.theme == 'dark',
                        onSelected: (_) => ref
                            .read(readerOptionsProvider.notifier)
                            .updateTheme('dark'),
                      ),
                      ChoiceChip(
                        label: const Text('Sepia'),
                        selected: options.theme == 'sepia',
                        onSelected: (_) => ref
                            .read(readerOptionsProvider.notifier)
                            .updateTheme('sepia'),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookAsync = ref.watch(bookDetailProvider(widget.slug));
    final readerOptions = ref.watch(readerOptionsProvider);
    final audioController = ref.read(audioControllerProvider.notifier);

    // Apply basic thematic background based on settings
    Color backgroundColor = Theme.of(context).colorScheme.surface;
    Color textColor = Theme.of(context).colorScheme.onSurface;

    if (readerOptions.theme == 'dark') {
      backgroundColor = const Color(0xFF121212);
      textColor = Colors.white70;
    } else if (readerOptions.theme == 'sepia') {
      backgroundColor = const Color(0xFFF4ECD8);
      textColor = const Color(0xFF5b4636);
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          bookAsync.maybeWhen(
            data: (book) {
              final hasAnyAudio = book.sections.any(
                (s) => (s.audioUrl?.trim().isNotEmpty ?? false),
              );
              return IconButton(
                tooltip: 'Listen while reading',
                icon: const Icon(Icons.headphones),
                onPressed: hasAnyAudio && book.sections.isNotEmpty
                    ? () => audioController.loadBook(
                        bookId: book.id,
                        bookSlug: book.slug,
                        bookTitle: book.title,
                        sections: book.sections,
                        startIndex: _currentIndex,
                        autoPlay: true,
                      )
                    : null,
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
          IconButton(
            icon: const Icon(Icons.text_fields),
            onPressed: () => _showTypographyModal(context, ref),
          ),
        ],
      ),
      body: bookAsync.when(
        data: (book) {
          if (book.sections.isEmpty) {
            return Center(
              child: Text(
                'No content available.',
                style: TextStyle(color: textColor),
              ),
            );
          }

          return Column(
            children: [
              // Progress Bar
              LinearProgressIndicator(
                value: (_currentIndex + 1) / book.sections.length,
                backgroundColor: textColor.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() => _currentIndex = index);

                    try {
                      final section = book.sections[index];
                      ref
                          .read(progressRepositoryProvider)
                          .markSectionRead(book.id, section.id);
                    } catch (e) {
                      debugPrint('Could not update reading progress: $e');
                    }
                  },
                  itemCount: book.sections.length,
                  itemBuilder: (context, index) {
                    final section = book.sections[index];
                    final isContentLocked = section.content == null;

                    if (isContentLocked) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lock_outline,
                                size: 64,
                                color: textColor.withOpacity(0.4),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                section.title,
                                style: TextStyle(
                                  fontSize: readerOptions.fontSize * 1.3,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'This content is available for premium users only.',
                                style: TextStyle(
                                  fontSize: readerOptions.fontSize,
                                  color: textColor.withOpacity(0.6),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              FilledButton.icon(
                                onPressed: () => context.push(
                                  Uri(
                                    path: '/paywall',
                                    queryParameters: {
                                      'slug': book.slug,
                                      'title': book.title,
                                    },
                                  ).toString(),
                                ),
                                icon: const Icon(Icons.star),
                                label: const Text('Upgrade to Premium'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 32.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            section.title,
                            style: TextStyle(
                              fontSize: readerOptions.fontSize * 1.5,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                              fontFamily: readerOptions.fontFamily,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            section.content!,
                            style: TextStyle(
                              fontSize: readerOptions.fontSize,
                              height: 1.6,
                              color: textColor,
                              fontFamily: readerOptions.fontFamily,
                            ),
                          ),
                          const SizedBox(height: 48),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text(
            'Failed to load text.',
            style: TextStyle(color: textColor),
          ),
        ),
      ),
      bottomNavigationBar: bookAsync.maybeWhen(
        data: (book) => Consumer(
          builder: (context, ref, _) {
            final audioState = ref.watch(audioControllerProvider);
            final audioController = ref.read(audioControllerProvider.notifier);

            final isThisBook =
                audioState.bookSlug == book.slug &&
                audioState.totalSections > 0;
            final duration = audioState.duration ?? Duration.zero;
            final progress = duration.inMilliseconds > 0
                ? (audioState.currentPosition.inMilliseconds /
                          duration.inMilliseconds)
                      .clamp(0.0, 1.0)
                : 0.0;

            return Container(
              color: backgroundColor,
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isThisBook) ...[
                      const Divider(height: 1),
                      LinearProgressIndicator(
                        value: progress,
                        minHeight: 2,
                        backgroundColor: textColor.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: audioState.isPlaying ? 'Pause' : 'Play',
                              icon: Icon(
                                audioState.isPlaying
                                    ? Icons.pause_circle
                                    : Icons.play_circle,
                              ),
                              iconSize: 40,
                              onPressed: audioState.isLoading
                                  ? null
                                  : audioController.togglePlayPause,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    audioState.bookTitle ?? book.title,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: textColor.withOpacity(0.8),
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    audioState.currentSectionTitle ?? 'Audio',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: textColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (audioState.errorMessage != null)
                                    Text(
                                      audioState.errorMessage!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: Colors.orange),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Previous',
                              icon: const Icon(Icons.skip_previous),
                              onPressed: audioController.skipPrevious,
                            ),
                            IconButton(
                              tooltip: 'Next',
                              icon: const Icon(Icons.skip_next),
                              onPressed: audioController.skipNext,
                            ),
                            IconButton(
                              tooltip: 'Open player',
                              icon: const Icon(Icons.open_in_full),
                              onPressed: () =>
                                  context.push('/books/${book.slug}/listen'),
                            ),
                            IconButton(
                              tooltip: 'Stop',
                              icon: const Icon(Icons.close),
                              onPressed: () =>
                                  audioController.stop(clearQueue: true),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      const Divider(height: 1),
                    ],
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Previous'),
                            onPressed: _currentIndex > 0
                                ? () => _pageController.previousPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  )
                                : null,
                          ),
                          Text(
                            '${_currentIndex + 1} of ${book.sections.length}',
                            style: TextStyle(color: textColor),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('Next'),
                            // If it's the last section, maybe change label to "Finish"
                            onPressed: _currentIndex < book.sections.length - 1
                                ? () => _pageController.nextPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        orElse: () => null,
      ),
    );
  }
}
