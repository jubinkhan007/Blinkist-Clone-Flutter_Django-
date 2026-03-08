import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../book/data/content_repository.dart';
import '../../progress/data/progress_repository.dart';
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
                          // Future iteration: use flutter_html or flutter_markdown to parse rich text
                          Text(
                            section.content ?? 'Content not downloaded.',
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
              // Bottom Controls
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
    );
  }
}
