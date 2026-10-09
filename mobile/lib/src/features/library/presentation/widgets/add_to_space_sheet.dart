import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../explore/domain/catalog_models.dart';
import '../../data/reading_list_repository.dart';
import '../../domain/reading_list_models.dart';

class AddToSpaceSheet extends ConsumerStatefulWidget {
  final Book book;

  const AddToSpaceSheet({
    super.key,
    required this.book,
  });

  static Future<void> show(BuildContext context, {required Book book}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddToSpaceSheet(book: book),
    );
  }

  @override
  ConsumerState<AddToSpaceSheet> createState() => _AddToSpaceSheetState();
}

class _AddToSpaceSheetState extends ConsumerState<AddToSpaceSheet> {
  bool _isCreatingNew = false;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  String _selectedEmoji = '📚';
  String _selectedColorHex = '#3B82F6';
  bool _isPublic = false;
  bool _isSaving = false;
  final Set<int> _pendingToggles = {};

  static const List<String> _emojis = [
    '📚', '💡', '🚀', '🧠', '🎯', '🌿', '🔥', '💎', '⚡', '📖', '💼', '🧘'
  ];

  static const List<String> _colorOptions = [
    '#3B82F6', // Blue
    '#10B981', // Green
    '#8B5CF6', // Purple
    '#F59E0B', // Amber
    '#EF4444', // Red
    '#06B6D4', // Cyan
    '#EC4899', // Pink
    '#64748B', // Slate
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Color _hexToColor(String hex) {
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    }
    return const Color(0xFF3B82F6);
  }

  Future<void> _toggleSpaceMembership(UserReadingList space, bool isCurrentlyMember) async {
    if (_pendingToggles.contains(space.id)) return;

    setState(() {
      _pendingToggles.add(space.id);
    });

    final repo = ref.read(readingListRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (isCurrentlyMember) {
        await repo.removeBookFromReadingList(space.id, widget.book.slug);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Removed from "${space.title}"'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        await repo.addBookToReadingList(space.id, widget.book.slug);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Added to "${space.title}"'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      ref.invalidate(bookMembershipsProvider(widget.book.slug));
      ref.invalidate(userReadingListsProvider);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to update space: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _pendingToggles.remove(space.id);
        });
      }
    }
  }

  Future<void> _handleCreateAndAdd() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() {
      _isSaving = true;
    });

    final repo = ref.read(readingListRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final newList = await repo.createReadingList(
        title: title,
        description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        emoji: _selectedEmoji,
        colorHex: _selectedColorHex,
        isPublic: _isPublic,
      );

      await repo.addBookToReadingList(newList.id, widget.book.slug);

      ref.invalidate(userReadingListsProvider);
      ref.invalidate(bookMembershipsProvider(widget.book.slug));

      messenger.showSnackBar(
        SnackBar(
          content: Text('Created "${newList.title}" and added "${widget.book.title}"'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );

      if (mounted) {
        setState(() {
          _isCreatingNew = false;
          _titleController.clear();
          _descController.clear();
          _isSaving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to create space: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.82;

    final spacesAsync = ref.watch(userReadingListsProvider);
    final membershipAsync = ref.watch(bookMembershipsProvider(widget.book.slug));

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 20,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Sheet header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isCreatingNew ? 'Create New Space' : 'Add to Space',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.book.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isCreatingNew)
                      TextButton(
                        onPressed: () => setState(() => _isCreatingNew = false),
                        child: const Text('Cancel'),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Close',
                      ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Content body
              Flexible(
                child: _isCreatingNew
                    ? _buildCreateSpaceForm(theme, colorScheme)
                    : _buildSpacesList(theme, colorScheme, spacesAsync, membershipAsync),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpacesList(
    ThemeData theme,
    ColorScheme colorScheme,
    AsyncValue<List<UserReadingList>> spacesAsync,
    AsyncValue<ReadingListMembership> membershipAsync,
  ) {
    return spacesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator.adaptive()),
      ),
      error: (err, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: colorScheme.error, size: 36),
              const SizedBox(height: 10),
              Text(
                'Could not load reading spaces',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
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
        final memberListIds = membershipAsync.value?.listIds ?? const [];

        return Column(
          children: [
            Expanded(
              child: spaces.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '📚',
                              style: const TextStyle(fontSize: 48),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No Reading Spaces Yet',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Create curated collections like "Morning Mindset" or "Tech & AI" to organize your reads.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: spaces.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (ctx, index) {
                        final space = spaces[index];
                        final isMember = memberListIds.contains(space.id);
                        final isPending = _pendingToggles.contains(space.id);
                        final spaceColor = _hexToColor(space.colorHex);

                        return Material(
                          color: isMember
                              ? spaceColor.withValues(alpha: 0.08)
                              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: isPending
                                ? null
                                : () => _toggleSpaceMembership(space, isMember),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  // Emoji & Color Badge
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: spaceColor.withValues(alpha: 0.16),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: spaceColor.withValues(alpha: 0.3),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        space.emoji,
                                        style: const TextStyle(fontSize: 22),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // Space metadata
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          space.title,
                                          style: theme.textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${space.itemsCount} ${space.itemsCount == 1 ? 'book' : 'books'} ${space.isPublic ? '• 🌐 Public' : '• 🔒 Private'}',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Checkmark indicator
                                  if (isPending)
                                    const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                                    )
                                  else
                                    Icon(
                                      isMember
                                          ? Icons.check_circle_rounded
                                          : Icons.radio_button_unchecked_rounded,
                                      color: isMember ? spaceColor : colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                                      size: 26,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // "+ Create New Space" action bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.tonalIcon(
                  onPressed: () => setState(() => _isCreatingNew = true),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create New Space'),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCreateSpaceForm(ThemeData theme, ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title input
          Text(
            'Space Name',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _titleController,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'e.g. Leadership Reads, Mindset, Tech & AI',
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),

          const SizedBox(height: 16),

          // Description input
          Text(
            'Description (Optional)',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _descController,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'A short note about the theme of this space...',
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),

          const SizedBox(height: 18),

          // Emoji selector
          Text(
            'Icon Emoji',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _emojis.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, index) {
                final emoji = _emojis[index];
                final isSelected = emoji == _selectedEmoji;
                return InkWell(
                  onTap: () => setState(() => _selectedEmoji = emoji),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colorScheme.primary.withValues(alpha: 0.15)
                          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? colorScheme.primary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 18),

          // Color palette selector
          Text(
            'Theme Accent',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _colorOptions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (ctx, index) {
                final hex = _colorOptions[index];
                final isSelected = hex == _selectedColorHex;
                final col = _hexToColor(hex);

                return InkWell(
                  onTap: () => setState(() => _selectedColorHex = hex),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: col,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: col.withValues(alpha: 0.5),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Public toggle
          SwitchListTile.adaptive(
            value: _isPublic,
            onChanged: (val) => setState(() => _isPublic = val),
            contentPadding: EdgeInsets.zero,
            title: const Text('Make Public & Shareable'),
            subtitle: Text(
              _isPublic
                  ? 'Anyone with the space link can view and save this list'
                  : 'Only you can view this space',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _isSaving ? null : _handleCreateAndAdd,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    )
                  : const Text('Create Space & Add Book'),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
