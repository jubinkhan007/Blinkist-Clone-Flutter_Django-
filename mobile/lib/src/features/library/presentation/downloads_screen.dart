import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../explore/domain/catalog_models.dart';
import '../../home/presentation/home_screen.dart';
import '../data/library_repository.dart';
import '../data/offline_downloads_service.dart';

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(offlineDownloadsProvider);
    final savedBooksAsync = ref.watch(libraryBooksProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Library'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'My Books'),
              Tab(text: 'Downloads'),
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
