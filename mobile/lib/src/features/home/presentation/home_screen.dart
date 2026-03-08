import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/networking/api_client.dart';
import '../../book/data/content_repository.dart';
import '../../explore/domain/catalog_models.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeFeedAsync = ref.watch(homeFeedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('For You'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () =>
                context.push('/explore'), // Assuming GoRouter setup
          ),
        ],
      ),
      body: homeFeedAsync.when(
        data: (feed) => RefreshIndicator(
          onRefresh: () => ref.refresh(homeFeedProvider.future),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              if (feed.continueReading.isNotEmpty)
                _buildRail(
                  context,
                  'Continue Reading',
                  feed.continueReading,
                ), // Note: Need a specific model for continue reading later
              _buildRail(context, 'Featured', feed.featured),
              _buildRail(context, 'Recommended', feed.recommended),
              _buildRail(context, 'Recently Added', feed.recentlyAdded),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Could not load your feed'),
              TextButton(
                onPressed: () => ref.refresh(homeFeedProvider),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRail(BuildContext context, String title, List<dynamic> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 240, // Fixed height for standard book cards
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final item = items[index];
              if (item is Book) {
                return BookCard(book: item);
              }
              return const SizedBox.shrink();
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class BookCard extends StatelessWidget {
  final Book book;

  const BookCard({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    final coverUrl = book.coverImageUrl?.trim();
    final resolvedCoverUrl = (coverUrl == null || coverUrl.isEmpty)
        ? null
        : resolveServerUrl(coverUrl);

    return GestureDetector(
      onTap: () => context.push('/books/${book.slug}'),
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: resolvedCoverUrl != null
                    ? Image.network(
                        resolvedCoverUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          child: const Icon(
                            Icons.book,
                            size: 48,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : Container(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        child: const Icon(
                          Icons.book,
                          size: 48,
                          color: Colors.grey,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              book.title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              book.author.name,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
