import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/networking/api_client.dart';
import '../../book/data/content_repository.dart';
import '../../reader/presentation/audio_controller.dart';
import '../domain/collection_models.dart';

class CollectionDetailScreen extends ConsumerWidget {
  final String slug;

  const CollectionDetailScreen({super.key, required this.slug});

  Color _parseColor(String? hex, {Color fallback = const Color(0xFF0284C7)}) {
    if (hex == null || hex.isEmpty) return fallback;
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      final val = int.tryParse('FF$clean', radix: 16);
      if (val != null) return Color(val);
    } else if (clean.length == 8) {
      final val = int.tryParse(clean, radix: 16);
      if (val != null) return Color(val);
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collectionAsync = ref.watch(collectionDetailProvider(slug));
    final theme = Theme.of(context);

    return collectionAsync.when(
      data: (collection) => _CollectionView(collection: collection),
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => Scaffold(
        appBar: AppBar(title: const Text('Collection')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Could not load collection: $e',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.refresh(collectionDetailProvider(slug)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CollectionView extends ConsumerWidget {
  final CollectionDetail collection;

  const _CollectionView({required this.collection});

  Color _parseColor(String? hex, {Color fallback = const Color(0xFF0284C7)}) {
    if (hex == null || hex.isEmpty) return fallback;
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      final val = int.tryParse('FF$clean', radix: 16);
      if (val != null) return Color(val);
    } else if (clean.length == 8) {
      final val = int.tryParse(clean, radix: 16);
      if (val != null) return Color(val);
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accentColor = _parseColor(collection.colorHex);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero Header Sliver
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Gradient Background
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accentColor,
                          Color.lerp(accentColor, Colors.black, 0.5)!,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  if (collection.bannerImageUrl != null)
                    Opacity(
                      opacity: 0.25,
                      child: Image.network(
                        resolveServerUrl(collection.bannerImageUrl!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  // Scrim overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.8),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  // Header content
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Pills row
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.bolt_rounded,
                                    size: 14,
                                    color: Colors.amberAccent,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${collection.targetDurationDays}-Day Challenge',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.menu_book_rounded,
                                    size: 14,
                                    color: Colors.white70,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${collection.booksCount} books • ~${collection.totalEstimatedMinutes} min',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          collection.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                        if (collection.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            collection.subtitle,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Main body content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress Card
                  _buildProgressCard(context, ref, accentColor),
                  const SizedBox(height: 16),

                  // Curriculum Description
                  if (collection.description.isNotEmpty) ...[
                    Text(
                      'About This Curriculum',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      collection.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  Text(
                    'Step-by-Step Learning Path',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // Curriculum items list
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = collection.items[index];
                  final isLast = index == collection.items.length - 1;
                  return _CurriculumItemCard(
                    item: item,
                    accentColor: accentColor,
                    isLast: isLast,
                  );
                },
                childCount: collection.items.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(
    BuildContext context,
    WidgetRef ref,
    Color accentColor,
  ) {
    final theme = Theme.of(context);
    final completed = collection.completedBooksCount;
    final total = collection.booksCount;
    final percent = (collection.progressPercent / 100.0).clamp(0.0, 1.0);
    final isDone = total > 0 && completed >= total;

    String motivation;
    if (isDone) {
      motivation =
          '🎉 Congratulations! You have completed all books in this collection.';
    } else if (completed > 0) {
      motivation =
          '🔥 Keep up the momentum! Finish the next book to build your habit.';
    } else {
      motivation =
          '🚀 Start Day 1 to build this skill. One summary a day leads to mastery.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isDone
                    ? Icons.emoji_events_rounded
                    : Icons.trending_up_rounded,
                color: isDone ? Colors.amber : accentColor,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'Collection Progress',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '$completed of $total books (${(percent * 100).toInt()}%)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDone ? Colors.green : accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                isDone ? Colors.green : accentColor,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            motivation,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: collection.items.isEmpty
                  ? null
                  : () {
                      final firstUncompleted = collection.items.firstWhere(
                        (item) => !item.isCompleted,
                        orElse: () => collection.items.first,
                      );
                      final firstIndex = collection.items.indexOf(
                        firstUncompleted,
                      );
                      final remaining = collection.items
                          .sublist(firstIndex + 1)
                          .map(
                            (item) => QueuedBook(
                              id: item.book.id,
                              slug: item.book.slug,
                              title: item.book.title,
                              authorName: item.book.author.name,
                              coverImageUrl: item.book.coverImageUrl,
                              estimatedMinutes:
                                  item.book.estimatedReadTimeMinutes,
                            ),
                          )
                          .toList();

                      if (remaining.isNotEmpty) {
                        ref
                            .read(audioControllerProvider.notifier)
                            .addBundleToQueue(remaining);
                      }

                      context.push(
                        '/books/${firstUncompleted.book.slug}/listen',
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Playing "${firstUncompleted.book.title}" • ${remaining.length} more in bundle queued for continuous audio',
                          ),
                        ),
                      );
                    },
              icon: const Icon(Icons.playlist_play_rounded, size: 22),
              label: Text(
                completed > 0 && completed < total
                    ? 'Resume Bundle Audio (${completed + 1}/$total)'
                    : 'Play Bundle Continuous Audio',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurriculumItemCard extends StatelessWidget {
  final CollectionItem item;
  final Color accentColor;
  final bool isLast;

  const _CurriculumItemCard({
    required this.item,
    required this.accentColor,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final book = item.book;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isCompleted
              ? Colors.green.withOpacity(0.5)
              : theme.colorScheme.outlineVariant.withOpacity(0.6),
          width: item.isCompleted ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step Header / Note
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: item.isCompleted
                  ? Colors.green.withOpacity(0.08)
                  : accentColor.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: item.isCompleted ? Colors.green : accentColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Step ${item.order}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.note.isNotEmpty ? item.note : book.title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: item.isCompleted
                          ? Colors.green.shade800
                          : theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (item.isCompleted) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green,
                    size: 18,
                  ),
                ],
              ],
            ),
          ),

          // Book Details Row
          InkWell(
            onTap: () => context.push('/books/${book.slug}'),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Book Cover
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 54,
                      height: 80,
                      child: book.coverImageUrl != null
                          ? Image.network(
                              resolveServerUrl(book.coverImageUrl!),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: theme.colorScheme.surfaceContainerHighest,
                                child: const Icon(Icons.book, size: 28),
                              ),
                            )
                          : Container(
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: const Icon(Icons.book, size: 28),
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Title, Author & CTAs
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          book.author.name,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 13,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${book.estimatedReadTimeMinutes} min summary',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Action Buttons: Read & Listen
                        Row(
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: const Icon(Icons.auto_stories, size: 14),
                              label: const Text('Read', style: TextStyle(fontSize: 12)),
                              onPressed: () => context.push('/books/${book.slug}/read'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                backgroundColor: accentColor,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.headphones, size: 14),
                              label: const Text('Listen', style: TextStyle(fontSize: 12)),
                              onPressed: () => context.push('/books/${book.slug}/listen'),
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
        ],
      ),
    );
  }
}
