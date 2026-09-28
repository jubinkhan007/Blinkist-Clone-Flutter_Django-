import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../explore/domain/catalog_models.dart';
import '../../home/presentation/home_screen.dart';
import '../../reader/data/highlight_repository.dart';
import '../../reader/domain/highlight_models.dart';
import '../../reader/presentation/quote_card_dialog.dart';
import '../data/library_repository.dart';
import '../data/offline_downloads_service.dart';

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(offlineDownloadsProvider);
    final savedBooksAsync = ref.watch(libraryBooksProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Library'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'My Books'),
              Tab(text: 'Downloads'),
              Tab(text: 'Notebook'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            savedBooksAsync.when(
              data: (books) => _SavedBooksTab(books: books),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Failed to load: $error')),
            ),
            _DownloadsTab(downloads: downloads),
            const _NotebookTab(),
          ],
        ),
      ),
    );
  }
}

class _SavedBooksTab extends ConsumerWidget {
  const _SavedBooksTab({required this.books});

  final List<Book> books;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (books.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.bookmark_border,
                size: 64,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                'Save books to read them later',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => context.go('/explore'),
                child: const Text('Explore'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(libraryBooksProvider);
        await ref.read(libraryBooksProvider.future);
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.65,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: books.length,
        itemBuilder: (context, index) => BookCard(book: books[index]),
      ),
    );
  }
}

class _DownloadsTab extends ConsumerWidget {
  const _DownloadsTab({required this.downloads});

  final Map<String, dynamic> downloads;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (downloads.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_download_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No downloads yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Books you download will appear here for offline reading.',
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: downloads.length,
      itemBuilder: (context, index) {
        final slug = downloads.keys.elementAt(index);
        final task = downloads[slug]!;

        return ListTile(
          leading: const Icon(Icons.menu_book),
          title: Text(task.slug),
          subtitle: task.isCompleted
              ? const Text('Downloaded')
              : LinearProgressIndicator(value: task.progress),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              ref.read(offlineDownloadsProvider.notifier).removeDownload(slug);
            },
          ),
          onTap: task.isCompleted
              ? () => context.push('/books/${task.slug}')
              : null,
        );
      },
    );
  }
}

class _NotebookTab extends ConsumerWidget {
  const _NotebookTab();

  Color _getHighlightColor(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'green':
        return const Color(0xFF81C784);
      case 'blue':
        return const Color(0xFF64B5F6);
      case 'pink':
        return const Color(0xFFF06292);
      case 'yellow':
      default:
        return const Color(0xFFFFD54F);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highlightsAsync = ref.watch(userHighlightsProvider);

    return highlightsAsync.when(
      data: (highlights) {
        if (highlights.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.edit_note_rounded,
                    size: 72,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your Notebook is Empty',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Highlight quotes and write notes while reading summaries to build your personal knowledge base.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    icon: const Icon(Icons.explore_outlined, size: 18),
                    onPressed: () => context.go('/explore'),
                    label: const Text('Start Reading'),
                  ),
                ],
              ),
            ),
          );
        }

        // Group highlights by book
        final Map<String, List<UserHighlight>> grouped = {};
        for (final h in highlights) {
          final key = h.bookTitle.isNotEmpty
              ? h.bookTitle
              : (h.bookSlug.isNotEmpty ? h.bookSlug : 'Unknown Book');
          grouped.putIfAbsent(key, () => []).add(h);
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(userHighlightsProvider);
            await ref.read(userHighlightsProvider.future);
          },
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            itemCount: grouped.keys.length,
            itemBuilder: (context, index) {
              final bookTitle = grouped.keys.elementAt(index);
              final bookHighlights = grouped[bookTitle]!;
              final firstH = bookHighlights.first;

              return Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withOpacity(0.5),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Book Header
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (firstH.bookCoverUrl != null &&
                              firstH.bookCoverUrl!.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(
                                firstH.bookCoverUrl!,
                                width: 36,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 36,
                                  height: 50,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  child: const Icon(Icons.book, size: 20),
                                ),
                              ),
                            )
                          else
                            Container(
                              width: 36,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.menu_book_rounded,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                                size: 20,
                              ),
                            ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  bookTitle,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (firstH.bookAuthor.isNotEmpty)
                                  Text(
                                    firstH.bookAuthor,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            onPressed: () =>
                                context.push('/books/${firstH.bookSlug}/read'),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Read', style: TextStyle(fontSize: 12)),
                                SizedBox(width: 2),
                                Icon(Icons.chevron_right, size: 16),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),

                      // Highlights inside this book
                      ...bookHighlights.map((h) {
                        final color = _getHighlightColor(h.color);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border(
                              left: BorderSide(
                                color: color,
                                width: 4,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '“${h.selectedText.trim()}”',
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              if (h.note.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
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
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.note_alt_outlined,
                                        size: 15,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          h.note,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  if (h.sectionTitle != null &&
                                      h.sectionTitle!.isNotEmpty)
                                    Expanded(
                                      child: Text(
                                        h.sectionTitle!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outline,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    )
                                  else
                                    const Spacer(),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.palette_outlined,
                                          size: 18,
                                        ),
                                        tooltip: 'Generate Quote Card',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () {
                                          QuoteCardDialog.show(
                                            context,
                                            quoteText: h.selectedText,
                                            bookTitle: h.bookTitle,
                                            bookAuthor: h.bookAuthor,
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                        ),
                                        tooltip: 'Delete Highlight',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () async {
                                          final confirmed =
                                              await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text(
                                                'Delete Highlight?',
                                              ),
                                              content: const Text(
                                                'Are you sure you want to remove this highlight from your notebook?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, false),
                                                  child: const Text('Cancel'),
                                                ),
                                                FilledButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, true),
                                                  child: const Text('Delete'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirmed == true) {
                                            try {
                                              await ref
                                                  .read(
                                                    highlightRepositoryProvider,
                                                  )
                                                  .deleteHighlight(h.id);
                                              ref.invalidate(
                                                userHighlightsProvider,
                                              );
                                              ref.invalidate(
                                                bookHighlightsProvider(
                                                  h.bookSlug,
                                                ),
                                              );
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Highlight removed from Notebook',
                                                    ),
                                                    duration: Duration(
                                                      seconds: 2,
                                                    ),
                                                  ),
                                                );
                                              }
                                            } catch (e) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Failed to delete: $e',
                                                    ),
                                                  ),
                                                );
                                              }
                                            }
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                'Failed to load notebook: $error',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(userHighlightsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
