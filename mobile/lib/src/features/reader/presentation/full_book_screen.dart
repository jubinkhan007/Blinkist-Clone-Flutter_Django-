import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../book/data/content_repository.dart';
import 'reader_options_provider.dart';

class FullBookScreen extends ConsumerWidget {
  final String slug;

  const FullBookScreen({super.key, required this.slug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(bookDetailProvider(slug));
    final readerOptions = ref.watch(readerOptionsProvider);

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
        title: bookAsync.maybeWhen(
          data: (book) => Text(
            book.title,
            style: TextStyle(color: textColor, fontSize: 16),
            overflow: TextOverflow.ellipsis,
          ),
          orElse: () => const SizedBox.shrink(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.text_fields),
            onPressed: () => _showTypographyModal(context, ref),
          ),
        ],
      ),
      body: bookAsync.when(
        data: (book) {
          if (book.fullText.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.book_outlined,
                        size: 64,
                        color: textColor.withValues(alpha: 0.3)),
                    const SizedBox(height: 16),
                    Text(
                      'Full book text not available yet.',
                      style: TextStyle(color: textColor),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  style: TextStyle(
                    fontSize: readerOptions.fontSize * 1.6,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    fontFamily: readerOptions.fontFamily,
                  ),
                ),
                if (book.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    book.subtitle,
                    style: TextStyle(
                      fontSize: readerOptions.fontSize * 1.1,
                      color: textColor.withValues(alpha: 0.7),
                      fontFamily: readerOptions.fontFamily,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  book.author.name,
                  style: TextStyle(
                    fontSize: readerOptions.fontSize,
                    color: textColor.withValues(alpha: 0.6),
                    fontFamily: readerOptions.fontFamily,
                  ),
                ),
                Divider(color: textColor.withValues(alpha: 0.2), height: 48),
                Text(
                  book.fullText,
                  style: TextStyle(
                    fontSize: readerOptions.fontSize,
                    height: 1.7,
                    color: textColor,
                    fontFamily: readerOptions.fontFamily,
                  ),
                ),
                const SizedBox(height: 64),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _showTypographyModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Typography', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            const Text('Font Size'),
            Consumer(
              builder: (context, ref, _) {
                final options = ref.watch(readerOptionsProvider);
                return Slider(
                  value: options.fontSize,
                  min: 12,
                  max: 32,
                  divisions: 10,
                  onChanged: (val) =>
                      ref.read(readerOptionsProvider.notifier).updateFontSize(val),
                );
              },
            ),
            const SizedBox(height: 8),
            const Text('Theme'),
            Consumer(
              builder: (context, ref, _) {
                final options = ref.watch(readerOptionsProvider);
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final theme in ['light', 'dark', 'sepia'])
                      ChoiceChip(
                        label: Text(theme[0].toUpperCase() + theme.substring(1)),
                        selected: options.theme == theme,
                        onSelected: (_) => ref
                            .read(readerOptionsProvider.notifier)
                            .updateTheme(theme),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
