import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/content_repository.dart';
import '../domain/book_models.dart';

class BookDetailScreen extends ConsumerWidget {
  final String slug;

  const BookDetailScreen({super.key, required this.slug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookDetailAsync = ref.watch(bookDetailProvider(slug));

    return Scaffold(
      body: bookDetailAsync.when(
        data: (book) => CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 300,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: book.coverImageUrl != null
                    ? Image.network(book.coverImageUrl!, fit: BoxFit.cover)
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
                    Text(
                      book.title,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
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
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          // Navigate to Reader.
                          // When implemented, it should fetch User Progress first and jump to 'current_section'.
                          // For now, jumping to the first section.
                          if (book.sections.isNotEmpty) {
                            context.push('/books/${book.slug}/read');
                          }
                        },
                        child: const Text('Read Now'),
                      ),
                    ),
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
                      ),
                    ),
                    const SizedBox(height: 48), // Padding at bottom
                  ],
                ),
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text('Error loading book: $error')),
      ),
    );
  }
}
