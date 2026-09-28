import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/networking/api_client.dart';
import '../../../../core/subscription/subscription_repository.dart';
import '../../explore/domain/catalog_models.dart';
import '../../library/data/library_repository.dart';
import '../../library/data/offline_downloads_service.dart';
import '../data/content_repository.dart';
import '../domain/book_models.dart';

class _CtaRow extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
                      ? Image.network(resolvedCoverUrl, fit: BoxFit.cover)
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
                        Row(
                          children: [
                            if (downloadTask == null)
                              TextButton.icon(
                                onPressed: () {
                                  ref
                                      .read(offlineDownloadsProvider.notifier)
                                      .startDownload(book);
                                },
                                icon: const Icon(Icons.download),
                                label: const Text('Download for offline'),
                              )
                            else if (downloadTask.isCompleted)
                              const Chip(
                                avatar: Icon(Icons.check_circle, size: 16),
                                label: Text('Available Offline'),
                              )
                            else
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Downloading...'),
                                    const SizedBox(height: 4),
                                    LinearProgressIndicator(
                                      value: downloadTask.progress,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
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
