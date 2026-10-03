import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/networking/api_client.dart';
import '../../../../core/subscription/subscription_repository.dart';
import '../../explore/domain/catalog_models.dart';
import '../../library/data/library_repository.dart';
import '../../library/data/offline_downloads_service.dart';
import '../../reader/presentation/ask_book_ai_sheet.dart';
import '../../reader/presentation/audio_controller.dart';
import '../data/content_repository.dart';
import '../domain/book_models.dart';

class _CtaRow extends ConsumerWidget {
  final BookDetail book;
  final bool isLocked;
  final VoidCallback onUpgrade;

  const _CtaRow({
    required this.book,
    required this.isLocked,
    required this.onUpgrade,
  });

  void _log(String message) {
    debugPrint('[FullBookCTA] $message');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasAudio = book.sections.any((s) => s.audioUrl != null);
    final hasPdf =
        book.fullBookPdfUrl != null && book.fullBookPdfUrl!.isNotEmpty;
    final hasFullText = book.fullText.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isLocked) ...[
          FilledButton.icon(
            icon: const Icon(Icons.lock),
            label: const Text('Upgrade to Premium'),
            onPressed: onUpgrade,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.headphones),
            label: const Text('Listen Summary (Locked)'),
            onPressed: null,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.menu_book_outlined),
            label: const Text('Read Summary (Locked)'),
            onPressed: null,
          ),
        ] else ...[
          // Listen Summary (primary)
          FilledButton.icon(
            icon: const Icon(Icons.headphones),
            label: Text(hasAudio ? 'Listen Summary' : 'Audio Coming Soon'),
            onPressed: hasAudio && book.sections.isNotEmpty
                ? () => context.push('/books/${book.slug}/listen')
                : null,
          ),
          const SizedBox(height: 8),
          // Read Summary (secondary)
          OutlinedButton.icon(
            icon: const Icon(Icons.menu_book_outlined),
            label: const Text('Read Summary'),
            onPressed: book.sections.isNotEmpty
                ? () => context.push('/books/${book.slug}/read')
                : null,
          ),
          const SizedBox(height: 8),
          // Audio Queue CTA
          if (hasAudio && book.sections.isNotEmpty) ...[
            Builder(
              builder: (context) {
                final audioState = ref.watch(audioControllerProvider);
                final isInQueue = audioState.queue.any(
                  (b) => b.slug == book.slug,
                );
                final isCurrentPlaying = audioState.bookSlug == book.slug;

                return OutlinedButton.icon(
                  icon: Icon(
                    isCurrentPlaying
                        ? Icons.graphic_eq_rounded
                        : (isInQueue
                            ? Icons.playlist_add_check_rounded
                            : Icons.queue_music_rounded),
                    color: isCurrentPlaying
                        ? Theme.of(context).colorScheme.primary
                        : (isInQueue ? Colors.teal : null),
                  ),
                  label: Text(
                    isCurrentPlaying
                        ? 'Now Playing in Audio'
                        : (isInQueue
                            ? 'In Audio Queue'
                            : 'Add to Audio Queue'),
                    style: TextStyle(
                      color: isCurrentPlaying
                          ? Theme.of(context).colorScheme.primary
                          : (isInQueue ? Colors.teal : null),
                      fontWeight: (isCurrentPlaying || isInQueue)
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  onPressed: () {
                    if (isCurrentPlaying) {
                      context.push('/books/${book.slug}/listen');
                    } else if (isInQueue) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '"${book.title}" is already in your audio queue',
                          ),
                          action: SnackBarAction(
                            label: 'Open Player',
                            onPressed: () => context.push(
                              '/books/${audioState.bookSlug ?? book.slug}/listen',
                            ),
                          ),
                        ),
                      );
                    } else {
                      ref.read(audioControllerProvider.notifier).addToQueue(
                            QueuedBook(
                              id: book.id,
                              slug: book.slug,
                              title: book.title,
                              authorName: book.author.name,
                              coverImageUrl: book.coverImageUrl,
                              estimatedMinutes: book.estimatedReadTimeMinutes,
                              sections: book.sections,
                            ),
                          );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Added "${book.title}" to audio queue'),
                          action: SnackBarAction(
                            label: 'View Queue',
                            onPressed: () => context.push(
                              '/books/${audioState.bookSlug ?? book.slug}/listen',
                            ),
                          ),
                        ),
                      );
                    }
                  },
                );
              },
            ),
            const SizedBox(height: 8),
          ],
          // Ask Book AI (Gemini)
          OutlinedButton.icon(
            icon: const Icon(Icons.auto_awesome, color: Colors.amber),
            label: const Text('Ask Book AI (Gemini)'),
            onPressed: () => AskBookAiSheet.show(
              context,
              bookSlug: book.slug,
              bookTitle: book.title,
              authorName: book.author.name,
            ),
          ),
        ],
        const SizedBox(height: 8),
        // Read Full Book (tertiary text link)
        TextButton.icon(
          icon: const Icon(Icons.book_outlined),
          label: Text(hasPdf ? 'Open Full Book PDF' : 'Read Full Book'),
          onPressed: (hasPdf || hasFullText)
              ? () async {
                  _log(
                    'Tapped for slug=${book.slug} '
                    'hasPdf=$hasPdf hasFullText=$hasFullText '
                    'rawPdfUrl=${book.fullBookPdfUrl} '
                    'fullTextLength=${book.fullText.length}',
                  );

                  if (hasPdf) {
                    final resolvedPdfUrl = resolveServerUrl(
                      book.fullBookPdfUrl!,
                    );
                    _log('Resolved PDF URL=$resolvedPdfUrl');
                  }

                  if (!context.mounted) return;
                  _log(
                    'Navigating to internal full-book route for slug=${book.slug}',
                  );
                  context.push('/books/${book.slug}/full');
                }
              : null,
        ),
      ],
    );
  }
}

class BookDetailScreen extends ConsumerWidget {
  final String slug;

  const BookDetailScreen({super.key, required this.slug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookDetailAsync = ref.watch(bookDetailProvider(slug));
    final subscriptionAsync = ref.watch(subscriptionInfoProvider);
    final hasPremiumAccess = subscriptionAsync.maybeWhen(
      data: (sub) => sub?.isPremium ?? false,
      orElse: () => false,
    );
    final downloads = ref.watch(offlineDownloadsProvider);
    final downloadTask = downloads[slug];
    final savedState = ref.watch(savedBooksProvider);

    return Scaffold(
      body: bookDetailAsync.when(
        data: (book) {
          final saved = savedState[book.slug] ?? book.isSaved;
          final isLocked = book.isPremium && !hasPremiumAccess && !book.isDailyFree;
          final coverUrl = book.coverImageUrl?.trim();
          final resolvedCoverUrl = (coverUrl == null || coverUrl.isEmpty)
              ? null
              : resolveServerUrl(coverUrl);
          final paywallUri = Uri(
            path: '/paywall',
            queryParameters: {'slug': book.slug, 'title': book.title},
          ).toString();

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                actions: [
                  IconButton(
                    tooltip: 'Ask AI about this book',
                    icon: const Icon(Icons.auto_awesome),
                    onPressed: () => AskBookAiSheet.show(
                      context,
                      bookSlug: book.slug,
                      bookTitle: book.title,
                      authorName: book.author.name,
                    ),
                  ),
                  IconButton(
                    tooltip: saved ? 'Remove bookmark' : 'Save book',
                    icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
                    onPressed: () => _toggleSaved(
                      context,
                      ref,
                      Book(
                        id: book.id,
                        title: book.title,
                        subtitle: book.subtitle,
                        slug: book.slug,
                        author: book.author,
                        categories: book.categories,
                        coverImageUrl: book.coverImageUrl,
                        estimatedReadTimeMinutes: book.estimatedReadTimeMinutes,
                        isPremium: book.isPremium,
                        isSaved: saved,
                        isDailyFree: book.isDailyFree,
                      ),
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: resolvedCoverUrl != null
                      ? (resolvedCoverUrl.startsWith('file://')
                          ? Image.file(
                              File(Uri.parse(resolvedCoverUrl).toFilePath()),
                              fit: BoxFit.cover,
                            )
                          : Image.network(
                              resolvedCoverUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                              ),
                            ))
                      : Container(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                        ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              book.title,
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (book.isPremium)
                            Padding(
                              padding: const EdgeInsets.only(left: 8, top: 6),
                              child: Chip(
                                label: Text(
                                  book.isDailyFree
                                      ? 'Free Today ⭐'
                                      : (isLocked ? 'Premium 🔒' : 'Premium'),
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (book.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          book.subtitle,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                      if (book.isDailyFree && !hasPremiumAccess) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withOpacity(0.4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.bolt_rounded,
                                color: Colors.orange,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Free Blink of the Day — full summary unlocked today!',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.timer_outlined, size: 16),
                          const SizedBox(width: 4),
                          Text('${book.estimatedReadTimeMinutes} min'),
                          const SizedBox(width: 16),
                          const Icon(Icons.menu_book, size: 16),
                          const SizedBox(width: 4),
                          Text('${book.sections.length} insights'),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _CtaRow(
                        book: book,
                        isLocked: isLocked,
                        onUpgrade: () => context.push(paywallUri),
                      ),
                      if (!isLocked) ...[
                        const SizedBox(height: 16),
                        _DownloadStatusWidget(book: book, task: downloadTask),
                      ],
                      const SizedBox(height: 32),
                      Text(
                        'What\'s it about?',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(book.description),
                      const SizedBox(height: 24),
                      Text(
                        'What you will learn',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(book.whatYouWillLearn),
                      const SizedBox(height: 32),
                      Text(
                        'Contents',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      ...book.sections.map(
                        (section) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            child: Text('${section.order}'),
                          ),
                          title: Text(section.title),
                          trailing: section.durationSeconds > 0
                              ? Text(
                                  '${(section.durationSeconds / 60).ceil()} min',
                                  style: Theme.of(context).textTheme.bodySmall,
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 48), // Padding at bottom
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text('Error loading book: $error')),
      ),
    );
  }
}

Future<void> _toggleSaved(
  BuildContext context,
  WidgetRef ref,
  Book book,
) async {
  try {
    await ref.read(savedBooksProvider.notifier).toggle(book);
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not update saved books: $error')),
    );
  }
}

class _DownloadStatusWidget extends ConsumerWidget {
  final BookDetail book;
  final DownloadTask? task;

  const _DownloadStatusWidget({
    required this.book,
    required this.task,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final notifier = ref.read(offlineDownloadsProvider.notifier);

    // 1. Idle / Not downloaded yet
    if (task == null || task!.status == DownloadStatus.idle) {
      final audioCount = book.sections.where((s) => s.audioUrl != null && s.audioUrl!.isNotEmpty).length;
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cloud_download_outlined, color: colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Available for Offline',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    audioCount > 0 ? 'Full summary + audio ($audioCount chapters)' : 'Full summary text',
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: () => notifier.startDownload(book),
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Download'),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ],
        ),
      );
    }

    // 2. Downloading in progress
    if (task!.status == DownloadStatus.downloading) {
      final percentInt = (task!.progress * 100).toInt();
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    value: task!.progress > 0 ? task!.progress : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    task!.statusMessage ?? 'Downloading offline content...',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '$percentInt%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Cancel Download',
                  icon: const Icon(Icons.close, size: 18),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => notifier.cancelDownload(book.slug),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: task!.progress,
                minHeight: 6,
              ),
            ),
          ],
        ),
      );
    }

    // 3. Failed / Error state
    if (task!.status == DownloadStatus.failed) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: colorScheme.errorContainer.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.error.withOpacity(0.4)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: colorScheme.error, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Download Failed',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    task!.error ?? 'Connection interrupted',
                    style: TextStyle(fontSize: 11, color: colorScheme.error.withOpacity(0.8)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => notifier.startDownload(book),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // 4. Completed / Available offline
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1B5E20).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.3)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Color(0xFF2E7D32),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Downloaded for Offline',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF1B5E20),
                  ),
                ),
                Text(
                  'Saved to device • ${task!.formattedSize}',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Download Options',
            icon: Icon(Icons.more_vert, size: 18, color: colorScheme.onSurfaceVariant),
            onSelected: (value) async {
              if (value == 'delete') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Remove Download?'),
                    content: Text('Remove offline files for "${book.title}" to free ${task!.formattedSize} of storage?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
                    ],
                  ),
                );
                if (confirm == true) {
                  await notifier.removeDownload(book.slug);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Removed ${book.title} from offline storage')),
                    );
                  }
                }
              } else if (value == 'redownload') {
                await notifier.removeDownload(book.slug);
                await notifier.startDownload(book);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'redownload',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 18),
                    SizedBox(width: 8),
                    Text('Re-download'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete Download', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
