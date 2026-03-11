import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/offline_downloads_service.dart';

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(offlineDownloadsProvider);

    if (downloads.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Library')),
        body: Center(
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
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Library')),
      body: ListView.builder(
        itemCount: downloads.length,
        itemBuilder: (context, index) {
          final slug = downloads.keys.elementAt(index);
          final task = downloads[slug]!;

          return ListTile(
            leading: const Icon(Icons.menu_book),
            title: Text(task.slug), // we don't store title in task currently
            subtitle: task.isCompleted
                ? const Text('Downloaded')
                : LinearProgressIndicator(value: task.progress),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                ref
                    .read(offlineDownloadsProvider.notifier)
                    .removeDownload(slug);
              },
            ),
            onTap: task.isCompleted
                ? () {
                    // Navigate to book details locally using the slug
                    context.push('/books/${task.slug}');
                  }
                : null,
          );
        },
      ),
    );
  }
}
