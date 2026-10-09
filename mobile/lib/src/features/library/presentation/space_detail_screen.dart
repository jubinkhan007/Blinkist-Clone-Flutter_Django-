import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/networking/api_client.dart';
import '../../explore/domain/catalog_models.dart';
import '../data/reading_list_repository.dart';
import '../domain/reading_list_models.dart';

class SpaceDetailScreen extends ConsumerStatefulWidget {
  final int? spaceId;
  final String? token;
  final String? shareToken;

  const SpaceDetailScreen({
    super.key,
    this.spaceId,
    this.token,
    this.shareToken,
  });

  @override
  ConsumerState<SpaceDetailScreen> createState() => _SpaceDetailScreenState();
}

class _SpaceDetailScreenState extends ConsumerState<SpaceDetailScreen> {
  bool _isCloning = false;
  List<UserReadingListItem>? _localItems;

  Color _hexToColor(String hex) {
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    }
    return const Color(0xFF3B82F6);
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

  Future<void> _cloneSpace(UserReadingList space) async {
    if (_isCloning) return;
    setState(() => _isCloning = true);

    final repo = ref.read(readingListRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final cloned = await repo.cloneSharedReadingList(space.shareToken);
      ref.invalidate(userReadingListsProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Saved "${cloned.title}" to your spaces!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (mounted) {
        context.pushReplacement('/spaces/${cloned.id}');
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to save space: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCloning = false);
      }
    }
  }

  Future<void> _removeBook(UserReadingList space, Book book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from Space?'),
        content: Text('Remove "${book.title}" from this space?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    final repo = ref.read(readingListRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await repo.removeBookFromReadingList(space.id, book.slug);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Removed "${book.title}" from space'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _invalidateSelf(space);
      ref.invalidate(bookMembershipsProvider(book.slug));
      ref.invalidate(userReadingListsProvider);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to remove book: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _reorderItems(UserReadingList space, int oldIndex, int newIndex) async {
    final messenger = ScaffoldMessenger.of(context);
    final items = List<UserReadingListItem>.from(_localItems ?? space.items);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final moved = items.removeAt(oldIndex);
    items.insert(newIndex, moved);

    setState(() {
      _localItems = items;
    });

    final repo = ref.read(readingListRepositoryProvider);
    final slugs = items.map((i) => i.book.slug).toList();

    try {
      await repo.reorderReadingList(space.id, slugs);
      _invalidateSelf(space);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to update order: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
      setState(() {
        _localItems = space.items;
      });
    }
  }

  Future<void> _showEditSpaceDialog(UserReadingList space) async {
    final titleCtrl = TextEditingController(text: space.title);
    final descCtrl = TextEditingController(text: space.description);
    String currentEmoji = space.emoji;
    String currentColor = space.colorHex;
    bool currentPublic = space.isPublic;

    const emojis = ['📚', '💡', '🚀', '🧠', '🎯', '🌿', '🔥', '💎', '⚡', '📖', '💼', '🧘'];
    const colors = [
      '#3B82F6', '#10B981', '#8B5CF6', '#F59E0B', '#EF4444', '#06B6D4', '#EC4899', '#64748B'
    ];

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Space'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Space Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                const Text('Emoji', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: emojis.map((e) {
                    final sel = e == currentEmoji;
                    return InkWell(
                      onTap: () => setDialogState(() => currentEmoji = e),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: sel ? Theme.of(ctx).colorScheme.primaryContainer : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: sel ? Theme.of(ctx).colorScheme.primary : Colors.grey.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 20)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Color Accent', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: colors.map((c) {
                    final sel = c == currentColor;
                    final col = _hexToColor(c);
                    return InkWell(
                      onTap: () => setDialogState(() => currentColor = c),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: col,
                          shape: BoxShape.circle,
                          border: Border.all(color: sel ? Colors.white : Colors.transparent, width: 2.5),
                        ),
                        child: sel ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Make Public'),
                  value: currentPublic,
                  onChanged: (val) => setDialogState(() => currentPublic = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (updated == true && titleCtrl.text.trim().isNotEmpty) {
      final repo = ref.read(readingListRepositoryProvider);
      try {
        await repo.updateReadingList(
          space.id,
          title: titleCtrl.text.trim(),
          description: descCtrl.text.trim(),
          emoji: currentEmoji,
          colorHex: currentColor,
          isPublic: currentPublic,
        );
        _invalidateSelf(space);
        ref.invalidate(userReadingListsProvider);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update space: $e'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  Future<void> _deleteSpace(UserReadingList space) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Space?'),
        content: Text('Are you sure you want to delete "${space.title}"? This cannot be undone.'),
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

    if (!mounted || confirmed != true) return;

    final repo = ref.read(readingListRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await repo.deleteReadingList(space.id);
      ref.invalidate(userReadingListsProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Deleted "${space.title}"'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (mounted) {
        context.pop();
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to delete space: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _invalidateSelf(UserReadingList space) {
    if (widget.shareToken != null) {
      ref.invalidate(sharedReadingListProvider(widget.shareToken!));
    }
    if (widget.spaceId != null) {
      ref.invalidate(readingListDetailProvider((id: widget.spaceId!, token: widget.token)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final AsyncValue<UserReadingList> spaceAsync;
    if (widget.shareToken != null && widget.shareToken!.isNotEmpty) {
      spaceAsync = ref.watch(sharedReadingListProvider(widget.shareToken!));
    } else if (widget.spaceId != null) {
      spaceAsync = ref.watch(readingListDetailProvider((id: widget.spaceId!, token: widget.token)));
    } else {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Invalid space identifier')),
      );
    }

    return spaceAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator.adaptive()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(title: const Text('Reading Space')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline_rounded, size: 48, color: colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  'Cannot access this space',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'This space may be private, deleted, or requires a valid share link.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () => context.pop(),
                  child: const Text('Back to Library'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (space) {
        final spaceColor = _hexToColor(space.colorHex);
        final items = _localItems ?? space.items;

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // Custom styled SliverAppBar
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: spaceColor.withValues(alpha: 0.85),
                foregroundColor: Colors.white,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.share_outlined),
                    tooltip: 'Share Space',
                    onPressed: () => _shareSpace(space),
                  ),
                  if (space.isOwner)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (val) {
                        if (val == 'edit') _showEditSpaceDialog(space);
                        if (val == 'share') _shareSpace(space);
                        if (val == 'delete') _deleteSpace(space);
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 20),
                              SizedBox(width: 10),
                              Text('Edit Space'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'share',
                          child: Row(
                            children: [
                              Icon(Icons.link_rounded, size: 20),
                              SizedBox(width: 10),
                              Text('Copy Share Link'),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                              SizedBox(width: 10),
                              Text('Delete Space', style: TextStyle(color: Colors.redAccent)),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          spaceColor,
                          spaceColor.withValues(alpha: 0.7),
                          colorScheme.surface,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: Text(space.emoji, style: const TextStyle(fontSize: 32)),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    space.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    space.ownerName != null
                                        ? 'Curated by ${space.ownerName}'
                                        : 'Personal Collection',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.85),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (space.description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            space.description,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 10),
                        // Metadata stats row
                        Wrap(
                          spacing: 8,
                          children: [
                            _buildBadgeChip(
                              icon: Icons.book_rounded,
                              label: '${items.length} ${items.length == 1 ? 'book' : 'books'}',
                            ),
                            if (space.totalEstimatedMinutes > 0)
                              _buildBadgeChip(
                                icon: Icons.schedule_rounded,
                                label: '${space.totalEstimatedMinutes} mins',
                              ),
                            _buildBadgeChip(
                              icon: space.isPublic ? Icons.public_rounded : Icons.lock_outline_rounded,
                              label: space.isPublic ? 'Public' : 'Private',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Non-owner save banner
              if (!space.isOwner)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: spaceColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: spaceColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Curated by ${space.ownerName ?? "another reader"}',
                                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Save this space to your library to track reading progress.',
                                  style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: _isCloning ? null : () => _cloneSpace(space),
                            icon: _isCloning
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                                  )
                                : const Icon(Icons.bookmark_add_rounded, size: 18),
                            label: const Text('Save Space'),
                            style: FilledButton.styleFrom(
                              backgroundColor: spaceColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Drag reorder hint (owner only, 2+ books)
              if (space.isOwner && items.length > 1)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                    child: Row(
                      children: [
                        Icon(Icons.swap_vert_rounded, size: 16, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text(
                          'Long press and drag to reorder books',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Items content
              if (items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.menu_book_rounded, size: 56, color: colorScheme.outline),
                          const SizedBox(height: 14),
                          Text(
                            'This Space is Empty',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            space.isOwner
                                ? 'Add books while exploring or reading using the "Add to Space" button.'
                                : 'No books have been added to this space yet.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                          if (space.isOwner) ...[
                            const SizedBox(height: 16),
                            FilledButton.tonal(
                              onPressed: () => context.go('/explore'),
                              child: const Text('Browse Books'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                )
              else if (space.isOwner)
                SliverReorderableList(
                  itemCount: items.length,
                  onReorder: (oldIndex, newIndex) => _reorderItems(space, oldIndex, newIndex),
                  itemBuilder: (ctx, index) {
                    final item = items[index];
                    return ReorderableDelayedDragStartListener(
                      key: ValueKey(item.id),
                      index: index,
                      child: _buildBookListItem(theme, colorScheme, space, item, isOwner: true),
                    );
                  },
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, index) {
                      final item = items[index];
                      return _buildBookListItem(theme, colorScheme, space, item, isOwner: false);
                    },
                    childCount: items.length,
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBadgeChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildBookListItem(
    ThemeData theme,
    ColorScheme colorScheme,
    UserReadingList space,
    UserReadingListItem item, {
    required bool isOwner,
  }) {
    final book = item.book;
    final coverUrl = book.coverImageUrl?.trim();
    final resolvedCover = (coverUrl != null && coverUrl.isNotEmpty) ? resolveServerUrl(coverUrl) : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/books/${book.slug}'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Book Cover
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 54,
                    height: 80,
                    color: colorScheme.surfaceContainerHighest,
                    child: resolvedCover != null
                        ? Image.network(
                            resolvedCover,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.book, size: 28, color: Colors.grey),
                          )
                        : const Icon(Icons.book, size: 28, color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 14),

                // Book Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        book.author.name,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.schedule, size: 13, color: colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            '${book.estimatedReadTimeMinutes} min',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (book.categories.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              '• ${book.categories.first.name}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (item.note.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.notes_rounded, size: 13, color: colorScheme.primary),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  item.note,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Trailing actions
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isOwner)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        color: colorScheme.onSurfaceVariant,
                        tooltip: 'Remove from space',
                        onPressed: () => _removeBook(space, book),
                      ),
                    if (isOwner)
                      const Icon(Icons.drag_indicator_rounded, size: 20, color: Colors.grey)
                    else
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                        color: colorScheme.onSurfaceVariant,
                        onPressed: () => context.push('/books/${book.slug}'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
