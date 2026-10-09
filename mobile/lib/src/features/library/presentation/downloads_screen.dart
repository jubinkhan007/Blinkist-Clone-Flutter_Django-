import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/networking/api_client.dart';

import '../../explore/domain/catalog_models.dart';
import '../../home/presentation/home_screen.dart';
import '../../reader/data/highlight_repository.dart';
import '../../reader/domain/highlight_models.dart';
import '../../reader/data/audio_bookmark_repository.dart';
import '../../reader/domain/audio_bookmark_models.dart';
import '../../reader/presentation/quote_card_dialog.dart';
import 'package:flutter/services.dart';
import '../data/library_repository.dart';
import '../data/offline_downloads_service.dart';
import '../data/reading_list_repository.dart';
import '../domain/reading_list_models.dart';

class DownloadsScreen extends ConsumerWidget {
  final String? initialTab;

  const DownloadsScreen({super.key, this.initialTab});

  int _resolveTabIndex(String? tab) {
    if (tab == null) return 0;
    switch (tab.toLowerCase()) {
      case 'spaces':
      case 'shelves':
        return 1;
      case 'downloads':
        return 2;
      case 'notebook':
      case 'notes':
      case 'bookmarks':
        return 3;
      case 'books':
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(offlineDownloadsProvider);
    final savedBooksAsync = ref.watch(libraryBooksProvider);

    return DefaultTabController(
      key: ValueKey(initialTab),
      initialIndex: _resolveTabIndex(initialTab),
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Library'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'My Books'),
              Tab(text: 'Spaces'),
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
            const _SpacesTab(),
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

  final Map<String, DownloadTask> downloads;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completedTasks = downloads.values.where((t) => t.isCompleted).toList();
    final activeTasks = downloads.values.where((t) => t.isDownloading).toList();
    final failedTasks = downloads.values.where((t) => t.isFailed).toList();
    final totalStorageStr = ref.watch(formattedTotalStorageProvider);
    final notifier = ref.read(offlineDownloadsProvider.notifier);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (downloads.isEmpty || (completedTasks.isEmpty && activeTasks.isEmpty && failedTasks.isEmpty)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_download_outlined,
                  size: 48,
                  color: colorScheme.outline,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No Downloads Yet',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Download books and audio summaries to listen anywhere, anytime — even on planes and offline commutes.',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.explore_outlined, size: 18),
                onPressed: () => context.go('/explore'),
                label: const Text('Explore Books to Download'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        // 1. Storage Overview Header
        if (completedTasks.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outlineVariant.withOpacity(0.4),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.storage_rounded,
                    color: colorScheme.onPrimaryContainer,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${completedTasks.length} ${completedTasks.length == 1 ? "Book" : "Books"} Offline',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Total Storage: $totalStorageStr',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.delete_sweep_outlined, size: 18, color: Colors.red),
                  label: const Text('Clear All', style: TextStyle(color: Colors.red, fontSize: 13)),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Remove All Downloads?'),
                        content: Text(
                          'This will delete all $totalStorageStr of downloaded summaries and audio files from your device. You can download them again at any time.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: Colors.red),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Remove All'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await notifier.clearAllDownloads();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('All downloaded files cleared'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 2. Active Downloads Section
        if (activeTasks.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  'Downloading (${activeTasks.length})',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          ...activeTasks.map((task) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        task.title.isNotEmpty ? task.title : task.slug,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${(task.progress * 100).toInt()}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'Cancel Download',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => notifier.cancelDownload(task.slug),
                    ),
                  ],
                ),
                if (task.statusMessage != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    task.statusMessage!,
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: task.progress,
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          )),
          const SizedBox(height: 12),
        ],

        // 3. Failed Downloads Section
        if (failedTasks.isNotEmpty) ...[
          ...failedTasks.map((task) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.error.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: colorScheme.error, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title.isNotEmpty ? task.title : task.slug,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.error,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        task.error ?? 'Download failed',
                        style: TextStyle(fontSize: 11, color: colorScheme.error.withOpacity(0.8)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  tooltip: 'Dismiss',
                  onPressed: () => notifier.removeDownload(task.slug),
                ),
              ],
            ),
          )),
        ],

        // 4. Completed Downloads Section
        if (completedTasks.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Downloaded Books',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ...completedTasks.map((task) => _DownloadedBookCard(task: task)),
        ],
      ],
    );
  }
}

class _DownloadedBookCard extends ConsumerWidget {
  final DownloadTask task;

  const _DownloadedBookCard({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final notifier = ref.read(offlineDownloadsProvider.notifier);

    Widget buildCover() {
      if (task.localCoverPath != null && File(task.localCoverPath!).existsSync()) {
        return Image.file(
          File(task.localCoverPath!),
          width: 55,
          height: 80,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _coverPlaceholder(context),
        );
      }
      if (task.coverImageUrl != null && task.coverImageUrl!.isNotEmpty) {
        final resolved = resolveServerUrl(task.coverImageUrl!);
        return Image.network(
          resolved,
          width: 55,
          height: 80,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _coverPlaceholder(context),
        );
      }
      return _coverPlaceholder(context);
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/books/${task.slug}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: buildCover(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title.isNotEmpty ? task.title : task.slug,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (task.author.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            task.author,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                task.formattedSize,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (task.hasAudio)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.headphones, size: 12, color: colorScheme.primary),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Audio',
                                      style: TextStyle(fontSize: 11, color: colorScheme.primary, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            if (task.sectionsCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${task.sectionsCount} parts',
                                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    tooltip: 'Remove Download',
                    visualDensity: VisualDensity.compact,
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Remove Download?'),
                          content: Text('Remove offline files for "${task.title}" to free ${task.formattedSize}?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await notifier.removeDownload(task.slug);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Removed ${task.title} from offline storage'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    icon: const Icon(Icons.menu_book, size: 16),
                    label: const Text('Read Summary', style: TextStyle(fontSize: 12)),
                    onPressed: () => context.push('/books/${task.slug}/read'),
                  ),
                  if (task.hasAudio) ...[
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text('Listen Audio', style: TextStyle(fontSize: 12)),
                      onPressed: () => context.push('/books/${task.slug}/listen'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _coverPlaceholder(BuildContext context) {
    return Container(
      width: 55,
      height: 80,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.menu_book_rounded,
        color: Theme.of(context).colorScheme.onPrimaryContainer,
        size: 24,
      ),
    );
  }
}

enum _NotebookFilter { all, highlights, audioBookmarks }

class _NotebookBookGroup {
  final String slug;
  final String title;
  final String author;
  final String? coverUrl;
  final List<UserHighlight> highlights;
  final List<AudioBookmark> audioBookmarks;

  _NotebookBookGroup({
    required this.slug,
    required this.title,
    required this.author,
    this.coverUrl,
    required this.highlights,
    required this.audioBookmarks,
  });
}

class _NotebookTab extends ConsumerStatefulWidget {
  const _NotebookTab();

  @override
  ConsumerState<_NotebookTab> createState() => _NotebookTabState();
}

class _NotebookTabState extends ConsumerState<_NotebookTab> {
  _NotebookFilter _filter = _NotebookFilter.all;

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

  Future<void> _confirmDeleteHighlight(
    BuildContext context,
    WidgetRef ref,
    UserHighlight h,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Highlight?'),
        content: const Text(
          'Are you sure you want to remove this highlight from your notebook?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref.read(highlightRepositoryProvider).deleteHighlight(h.id);
        ref.invalidate(userHighlightsProvider);
        ref.invalidate(bookHighlightsProvider(h.bookSlug));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Highlight removed from Notebook'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }

  Future<void> _confirmDeleteAudioBookmark(
    BuildContext context,
    WidgetRef ref,
    AudioBookmark bm,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Audio Bookmark?'),
        content: Text(
          'Remove bookmark at ${bm.displayTimestamp} from your notebook?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref.read(audioBookmarkRepositoryProvider).deleteBookmark(bm.id);
        ref.invalidate(userAudioBookmarksProvider);
        ref.invalidate(bookAudioBookmarksProvider(bm.bookSlug));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Audio bookmark removed from Notebook'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete bookmark: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final highlightsAsync = ref.watch(userHighlightsProvider);
    final audioBookmarksAsync = ref.watch(userAudioBookmarksProvider);

    if (highlightsAsync.isLoading && audioBookmarksAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final highlights = highlightsAsync.valueOrNull ?? [];
    final audioBookmarks = audioBookmarksAsync.valueOrNull ?? [];

    if (highlights.isEmpty && audioBookmarks.isEmpty) {
      if (highlightsAsync.hasError && audioBookmarksAsync.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text(
                  'Failed to load notebook: ${highlightsAsync.error}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    ref.invalidate(userHighlightsProvider);
                    ref.invalidate(userAudioBookmarksProvider);
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      }

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
                'Highlight quotes and save timed audio bookmarks while reading or listening to build your personal knowledge base.',
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

    // Group items by book
    final Map<String, _NotebookBookGroup> groups = {};

    if (_filter == _NotebookFilter.all || _filter == _NotebookFilter.highlights) {
      for (final h in highlights) {
        final key = h.bookSlug.isNotEmpty
            ? h.bookSlug
            : (h.bookTitle.isNotEmpty ? h.bookTitle : 'unknown');
        final group = groups.putIfAbsent(
          key,
          () => _NotebookBookGroup(
            slug: h.bookSlug,
            title: h.bookTitle.isNotEmpty ? h.bookTitle : 'Unknown Book',
            author: h.bookAuthor,
            coverUrl: h.bookCoverUrl,
            highlights: [],
            audioBookmarks: [],
          ),
        );
        group.highlights.add(h);
      }
    }

    if (_filter == _NotebookFilter.all || _filter == _NotebookFilter.audioBookmarks) {
      for (final bm in audioBookmarks) {
        final key = bm.bookSlug.isNotEmpty
            ? bm.bookSlug
            : (bm.bookTitle.isNotEmpty ? bm.bookTitle : 'unknown');
        final group = groups.putIfAbsent(
          key,
          () => _NotebookBookGroup(
            slug: bm.bookSlug,
            title: bm.bookTitle.isNotEmpty ? bm.bookTitle : 'Unknown Book',
            author: bm.bookAuthor,
            coverUrl: bm.bookCoverUrl,
            highlights: [],
            audioBookmarks: [],
          ),
        );
        group.audioBookmarks.add(bm);
      }
    }

    final filteredGroups = groups.values
        .where((g) => g.highlights.isNotEmpty || g.audioBookmarks.isNotEmpty)
        .toList();

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(userHighlightsProvider);
        ref.invalidate(userAudioBookmarksProvider);
        await Future.wait([
          ref.read(userHighlightsProvider.future),
          ref.read(userAudioBookmarksProvider.future),
        ]);
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                FilterChip(
                  selected: _filter == _NotebookFilter.all,
                  label: Text('All (${highlights.length + audioBookmarks.length})'),
                  onSelected: (_) => setState(() => _filter = _NotebookFilter.all),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  selected: _filter == _NotebookFilter.highlights,
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.format_quote_rounded, size: 16),
                      const SizedBox(width: 4),
                      Text('Quotes (${highlights.length})'),
                    ],
                  ),
                  onSelected: (_) =>
                      setState(() => _filter = _NotebookFilter.highlights),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  selected: _filter == _NotebookFilter.audioBookmarks,
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.headphones_rounded, size: 16),
                      const SizedBox(width: 4),
                      Text('Audio Bookmarks (${audioBookmarks.length})'),
                    ],
                  ),
                  onSelected: (_) =>
                      setState(() => _filter = _NotebookFilter.audioBookmarks),
                ),
              ],
            ),
          ),

          if (filteredGroups.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _filter == _NotebookFilter.highlights
                        ? Icons.format_quote_rounded
                        : Icons.headphones_rounded,
                    size: 56,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _filter == _NotebookFilter.highlights
                        ? 'No Quotes Yet'
                        : 'No Audio Bookmarks Yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _filter == _NotebookFilter.highlights
                        ? 'Select and highlight text while reading summaries.'
                        : 'Tap the bookmark icon in the audio player during playback to save key moments.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () =>
                        setState(() => _filter = _NotebookFilter.all),
                    child: const Text('Show All Items'),
                  ),
                ],
              ),
            )
          else
            ...filteredGroups.map((group) {
              return Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                          if (group.coverUrl != null &&
                              group.coverUrl!.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(
                                group.coverUrl!,
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
                                  group.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (group.author.isNotEmpty)
                                  Text(
                                    group.author,
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
                          if (group.slug.isNotEmpty) ...[
                            IconButton(
                              icon: const Icon(Icons.psychology_outlined, size: 20),
                              tooltip: 'Recall Flashcards',
                              visualDensity: VisualDensity.compact,
                              onPressed: () =>
                                  context.push('/books/${group.slug}/flashcards'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.menu_book_rounded, size: 20),
                              tooltip: 'Read Summary',
                              visualDensity: VisualDensity.compact,
                              onPressed: () =>
                                  context.push('/books/${group.slug}/read'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.headphones_rounded, size: 20),
                              tooltip: 'Listen to Audio',
                              visualDensity: VisualDensity.compact,
                              onPressed: () =>
                                  context.push('/books/${group.slug}/listen'),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),

                      // Highlights (Quotes)
                      ...group.highlights.map((h) {
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
                                        onPressed: () =>
                                            _confirmDeleteHighlight(
                                          context,
                                          ref,
                                          h,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),

                      // Audio Bookmarks
                      ...group.audioBookmarks.map((bm) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border(
                              left: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 4,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primaryContainer,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.timer_outlined,
                                          size: 13,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimaryContainer,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          bm.displayTimestamp,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onPrimaryContainer,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (bm.sectionTitle != null &&
                                      bm.sectionTitle!.isNotEmpty)
                                    Expanded(
                                      child: Text(
                                        bm.sectionTitle!,
                                        style: TextStyle(
                                          fontSize: 12,
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
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                    ),
                                    tooltip: 'Delete Audio Bookmark',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () =>
                                        _confirmDeleteAudioBookmark(
                                      context,
                                      ref,
                                      bm,
                                    ),
                                  ),
                                ],
                              ),
                              if (bm.title.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  bm.title,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              if (bm.note.isNotEmpty) ...[
                                const SizedBox(height: 6),
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
                                          bm.note,
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
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: FilledButton.tonalIcon(
                                  style: FilledButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.play_circle_fill,
                                    size: 18,
                                  ),
                                  label: Text(
                                    'Play from ${bm.displayTimestamp}',
                                  ),
                                  onPressed: () {
                                    final sectionParam = bm.sectionOrder != null
                                        ? '&section=${bm.sectionOrder}'
                                        : '';
                                    context.push(
                                      '/books/${bm.bookSlug}/listen?pos=${bm.timestampSeconds}$sectionParam',
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _SpacesTab extends ConsumerStatefulWidget {
  const _SpacesTab();

  @override
  ConsumerState<_SpacesTab> createState() => _SpacesTabState();
}

class _SpacesTabState extends ConsumerState<_SpacesTab> {
  Color _hexToColor(String hex) {
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    }
    return const Color(0xFF3B82F6);
  }

  Future<void> _showCreateSpaceSheet() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String currentEmoji = '📚';
    String currentColor = '#3B82F6';
    bool currentPublic = false;
    bool isSaving = false;

    const emojis = ['📚', '💡', '🚀', '🧠', '🎯', '🌿', '🔥', '💎', '⚡', '📖', '💼', '🧘'];
    const colors = [
      '#3B82F6', '#10B981', '#8B5CF6', '#F59E0B', '#EF4444', '#06B6D4', '#EC4899', '#64748B'
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final theme = Theme.of(ctx);
          final colorScheme = theme.colorScheme;
          final keyboardInset = MediaQuery.of(ctx).viewInsets.bottom;

          return AnimatedPadding(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.only(bottom: keyboardInset),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Create Reading Space',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text('Space Name', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: titleCtrl,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'e.g. Morning Mindset, Tech & AI',
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text('Description (Optional)', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: descCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'What is this shelf about?',
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Icon Emoji', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 44,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: emojis.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (ctx, index) {
                            final e = emojis[index];
                            final sel = e == currentEmoji;
                            return InkWell(
                              onTap: () => setSheetState(() => currentEmoji = e),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: sel ? colorScheme.primary.withValues(alpha: 0.15) : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: sel ? colorScheme.primary : Colors.transparent, width: 2),
                                ),
                                child: Center(child: Text(e, style: const TextStyle(fontSize: 20))),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Theme Accent', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 38,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: colors.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (ctx, index) {
                            final hex = colors[index];
                            final sel = hex == currentColor;
                            final col = _hexToColor(hex);
                            return InkWell(
                              onTap: () => setSheetState(() => currentColor = hex),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: col,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: sel ? Colors.white : Colors.transparent, width: 2.5),
                                ),
                                child: sel ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      SwitchListTile.adaptive(
                        value: currentPublic,
                        onChanged: (val) => setSheetState(() => currentPublic = val),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Make Public & Shareable'),
                        subtitle: const Text('Anyone with your space link will be able to view and clone it.'),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final name = titleCtrl.text.trim();
                                  if (name.isEmpty) return;

                                  setSheetState(() => isSaving = true);
                                  try {
                                    final repo = ref.read(readingListRepositoryProvider);
                                    await repo.createReadingList(
                                      title: name,
                                      description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                                      emoji: currentEmoji,
                                      colorHex: currentColor,
                                      isPublic: currentPublic,
                                    );
                                    ref.invalidate(userReadingListsProvider);
                                    if (ctx.mounted) Navigator.of(ctx).pop();
                                  } catch (e) {
                                    setSheetState(() => isSaving = false);
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(content: Text('Failed to create space: $e'), backgroundColor: Colors.redAccent),
                                      );
                                    }
                                  }
                                },
                          child: isSaving
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator.adaptive(strokeWidth: 2))
                              : const Text('Create Space'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _shareSpace(UserReadingList space) {
    final shareUrl = 'https://blinkist.com/spaces/share/${space.shareToken}';
    Clipboard.setData(ClipboardData(text: shareUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Share link copied to clipboard!\n$shareUrl'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _deleteSpace(UserReadingList space) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Space?'),
        content: Text('Delete "${space.title}"? Your books will not be deleted from your general library.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final repo = ref.read(readingListRepositoryProvider);
    try {
      await repo.deleteReadingList(space.id);
      ref.invalidate(userReadingListsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted "${space.title}"'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete space: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final spacesAsync = ref.watch(userReadingListsProvider);

    return spacesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 40, color: colorScheme.error),
              const SizedBox(height: 12),
              Text('Failed to load reading spaces', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => ref.invalidate(userReadingListsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (spaces) {
        if (spaces.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(child: Text('📚', style: TextStyle(fontSize: 36))),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Curate Your Library',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create themed shelves like "Morning Mindset", "Leadership", or "Tech & AI". Add custom notes and share your spaces with teammates.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _showCreateSpaceSheet,
                    icon: const Icon(Icons.add),
                    label: const Text('Create Your First Space'),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(userReadingListsProvider);
            await ref.read(userReadingListsProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header action row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${spaces.length} ${spaces.length == 1 ? 'Reading Space' : 'Reading Spaces'}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _showCreateSpaceSheet,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New Space'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Spaces list
              ...spaces.map((space) {
                final spaceColor = _hexToColor(space.colorHex);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Material(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => context.push('/spaces/${space.id}'),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: spaceColor.withValues(alpha: 0.25),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Card banner
                            Container(
                              height: 60,
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                gradient: LinearGradient(
                                  colors: [
                                    spaceColor.withValues(alpha: 0.8),
                                    spaceColor.withValues(alpha: 0.3),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(space.emoji, style: const TextStyle(fontSize: 22)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      space.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, color: Colors.white),
                                    onSelected: (val) {
                                      if (val == 'share') _shareSpace(space);
                                      if (val == 'delete') _deleteSpace(space);
                                    },
                                    itemBuilder: (ctx) => [
                                      const PopupMenuItem(
                                        value: 'share',
                                        child: Row(
                                          children: [
                                            Icon(Icons.link, size: 18),
                                            SizedBox(width: 8),
                                            Text('Share Link'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                            SizedBox(width: 8),
                                            Text('Delete Space', style: TextStyle(color: Colors.redAccent)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Body details
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (space.description.isNotEmpty) ...[
                                    Text(
                                      space.description,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 10),
                                  ],

                                  Row(
                                    children: [
                                      // Meta stats chip
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: spaceColor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${space.itemsCount} ${space.itemsCount == 1 ? 'book' : 'books'} • ${space.totalEstimatedMinutes}m read',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: spaceColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: colorScheme.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          space.isPublic ? '🌐 Public' : '🔒 Private',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),

                                      // Preview Covers Stack
                                      if (space.previewCovers.isNotEmpty)
                                        SizedBox(
                                          height: 36,
                                          width: 24.0 + (space.previewCovers.take(4).length - 1) * 16.0,
                                          child: Stack(
                                            children: space.previewCovers
                                                .take(4)
                                                .toList()
                                                .asMap()
                                                .entries
                                                .map((entry) {
                                              final idx = entry.key;
                                              final coverUrl = resolveServerUrl(entry.value);
                                              return Positioned(
                                                left: idx * 16.0,
                                                child: Container(
                                                  width: 24,
                                                  height: 36,
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: Colors.white, width: 1),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black.withValues(alpha: 0.15),
                                                        blurRadius: 3,
                                                      ),
                                                    ],
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(3),
                                                    child: Image.network(
                                                      coverUrl,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (_, __, ___) => Container(
                                                        color: Colors.grey.shade400,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

