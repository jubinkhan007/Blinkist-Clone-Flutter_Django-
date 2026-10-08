import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../book/data/content_repository.dart';
import '../../progress/data/progress_repository.dart';
import '../domain/highlight_models.dart';
import '../data/highlight_repository.dart';
import 'ask_book_ai_sheet.dart';
import 'audio_controller.dart';
import 'quote_card_dialog.dart';
import 'reader_options_provider.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  final String slug;

  const ReaderScreen({super.key, required this.slug});

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  bool _restoredProgress = false;
  final List<TapGestureRecognizer> _recognizers = [];

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _restoreProgress({
    required int bookId,
    required List<dynamic> sections,
  }) async {
    if (_restoredProgress || sections.isEmpty) {
      return;
    }
    _restoredProgress = true;

    try {
      final progress = await ref
          .read(progressRepositoryProvider)
          .getBookProgress(bookId);
      final savedSectionId = progress.currentSectionId;
      if (savedSectionId == null) {
        return;
      }

      final targetIndex = sections.indexWhere(
        (section) => section.id == savedSectionId,
      );
      if (targetIndex <= 0) {
        return;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients) {
          return;
        }
        _pageController.jumpToPage(targetIndex);
        setState(() => _currentIndex = targetIndex);
      });
    } catch (error) {
      debugPrint('Could not restore reading progress: $error');
    }
  }

  Color _getHighlightColor(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'green':
        return const Color(0xFF81C784).withOpacity(0.35);
      case 'blue':
        return const Color(0xFF64B5F6).withOpacity(0.35);
      case 'pink':
        return const Color(0xFFF06292).withOpacity(0.35);
      case 'yellow':
      default:
        return const Color(0xFFFFD54F).withOpacity(0.40);
    }
  }

  Color _getHighlightSolidColor(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'green':
        return const Color(0xFF2E7D32);
      case 'blue':
        return const Color(0xFF1976D2);
      case 'pink':
        return const Color(0xFFC2185B);
      case 'yellow':
      default:
        return const Color(0xFFF57F17);
    }
  }

  Future<void> _quickHighlight({
    required String color,
    required String selectedText,
    required dynamic book,
    required dynamic section,
  }) async {
    final trimmed = selectedText.trim();
    if (trimmed.isEmpty) return;

    try {
      await ref.read(highlightRepositoryProvider).createHighlight(
            bookSlug: book.slug,
            sectionId: section.id,
            selectedText: trimmed,
            note: '',
            color: color,
          );
      ref.invalidate(bookHighlightsProvider(book.slug));
      ref.invalidate(userHighlightsProvider);

      if (mounted) {
        final colorName = color[0].toUpperCase() + color.substring(1);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Highlighted in $colorName! Tap it to attach a note.'),
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'Add Note',
              onPressed: () {
                _showHighlightModal(
                  context,
                  book: book,
                  section: section,
                  selectedText: trimmed,
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save highlight: $e')),
        );
      }
    }
  }

  void _showHighlightModal(
    BuildContext context, {
    required dynamic book,
    required dynamic section,
    required String selectedText,
  }) {
    String selectedColor = 'yellow';
    final noteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Highlight Passage',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border(
                    left: BorderSide(
                      color: _getHighlightColor(selectedColor).withOpacity(1.0),
                      width: 4,
                    ),
                  ),
                ),
                child: Text(
                  selectedText.trim(),
                  style:
                      const TextStyle(fontStyle: FontStyle.italic, fontSize: 13),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Highlight Color',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _colorOption('yellow', const Color(0xFFFFD54F), selectedColor,
                      (c) => setModalState(() => selectedColor = c)),
                  const SizedBox(width: 12),
                  _colorOption('green', const Color(0xFF81C784), selectedColor,
                      (c) => setModalState(() => selectedColor = c)),
                  const SizedBox(width: 12),
                  _colorOption('blue', const Color(0xFF64B5F6), selectedColor,
                      (c) => setModalState(() => selectedColor = c)),
                  const SizedBox(width: 12),
                  _colorOption('pink', const Color(0xFFF06292), selectedColor,
                      (c) => setModalState(() => selectedColor = c)),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                decoration: InputDecoration(
                  hintText: 'Add an optional note or thought...',
                  hintStyle: const TextStyle(fontSize: 13),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.bookmark_add_rounded, size: 18),
                  label: const Text('Save Highlight'),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    try {
                      await ref
                          .read(highlightRepositoryProvider)
                          .createHighlight(
                            bookSlug: book.slug,
                            sectionId: section.id,
                            selectedText: selectedText.trim(),
                            note: noteController.text.trim(),
                            color: selectedColor,
                          );
                      ref.invalidate(bookHighlightsProvider(book.slug));
                      ref.invalidate(userHighlightsProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Highlight saved to My Notebook!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Could not save highlight: $e')),
                        );
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHighlightDetailModal(
    BuildContext context, {
    required UserHighlight highlight,
    required dynamic book,
    required dynamic section,
  }) {
    String currentColor = highlight.color;
    final noteController = TextEditingController(text: highlight.note);
    bool isEditingNote = highlight.note.trim().isEmpty;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _getHighlightSolidColor(currentColor),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Highlight & Margin Note',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _getHighlightColor(currentColor),
                  borderRadius: BorderRadius.circular(12),
                  border: Border(
                    left: BorderSide(
                      color: _getHighlightSolidColor(currentColor),
                      width: 4,
                    ),
                  ),
                ),
                child: Text(
                  highlight.selectedText.trim(),
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    fontSize: 14,
                    height: 1.5,
                  ),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Highlight Color:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  Row(
                    children: [
                      for (final c in ['yellow', 'green', 'blue', 'pink']) ...[
                        GestureDetector(
                          onTap: () async {
                            setModalState(() => currentColor = c);
                            try {
                              await ref
                                  .read(highlightRepositoryProvider)
                                  .updateHighlight(id: highlight.id, color: c);
                              ref.invalidate(bookHighlightsProvider(widget.slug));
                              ref.invalidate(userHighlightsProvider);
                            } catch (e) {
                              debugPrint('Failed to update color: $e');
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: _getHighlightSolidColor(c),
                              shape: BoxShape.circle,
                              border: currentColor == c
                                  ? Border.all(color: Colors.black87, width: 2.5)
                                  : null,
                            ),
                            child: currentColor == c
                                ? const Icon(Icons.check, size: 16, color: Colors.white)
                                : null,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Margin Note 📝',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              if (isEditingNote) ...[
                TextField(
                  controller: noteController,
                  autofocus: highlight.note.trim().isEmpty,
                  decoration: InputDecoration(
                    hintText: 'Write your thoughts, reflections, or action items...',
                    hintStyle: const TextStyle(fontSize: 13),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Save Note'),
                    onPressed: () async {
                      final newNote = noteController.text.trim();
                      try {
                        await ref
                            .read(highlightRepositoryProvider)
                            .updateHighlight(id: highlight.id, note: newNote);
                        ref.invalidate(bookHighlightsProvider(widget.slug));
                        ref.invalidate(userHighlightsProvider);
                        setModalState(() => isEditingNote = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Margin note updated!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Could not save note: $e')),
                          );
                        }
                      }
                    },
                  ),
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withOpacity(0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.notes_rounded, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          noteController.text.trim(),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () => setModalState(() => isEditingNote = true),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.palette_outlined, size: 16),
                      label: const Text('Quote Card'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        QuoteCardDialog.show(
                          context,
                          quoteText: highlight.selectedText,
                          bookTitle: book.title,
                          bookAuthor: book.author.name,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: highlight.selectedText));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Copied quote to clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (dCtx) => AlertDialog(
                          title: const Text('Remove Highlight?'),
                          content: const Text(
                            'Are you sure you want to delete this highlight and its margin note?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dCtx, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              onPressed: () => Navigator.pop(dCtx, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true && ctx.mounted) {
                        Navigator.pop(ctx);
                        try {
                          await ref
                              .read(highlightRepositoryProvider)
                              .deleteHighlight(highlight.id);
                          ref.invalidate(bookHighlightsProvider(widget.slug));
                          ref.invalidate(userHighlightsProvider);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Highlight deleted.'),
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
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChapterNotesSheet(
    BuildContext context,
    List<UserHighlight> chapterHighlights,
    dynamic book,
    dynamic section,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chapter Notes & Highlights',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        section.title,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 24),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: chapterHighlights.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, idx) {
                    final h = chapterHighlights[idx];
                    return InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        _showHighlightDetailModal(
                          context,
                          highlight: h,
                          book: book,
                          section: section,
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _getHighlightColor(h.color),
                          borderRadius: BorderRadius.circular(12),
                          border: Border(
                            left: BorderSide(
                              color: _getHighlightSolidColor(h.color),
                              width: 4,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              h.selectedText.trim(),
                              style: const TextStyle(
                                fontStyle: FontStyle.italic,
                                fontSize: 13,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (h.note.trim().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.notes_rounded,
                                      size: 14,
                                      color: Colors.black87,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        h.note.trim(),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 2,
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
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _colorOption(
    String name,
    Color color,
    String current,
    ValueChanged<String> onSelect,
  ) {
    final isSelected = name == current;
    return GestureDetector(
      onTap: () => onSelect(name),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border:
              isSelected ? Border.all(color: Colors.black87, width: 2.5) : null,
        ),
        child: isSelected
            ? const Icon(Icons.check, size: 18, color: Colors.black87)
            : null,
      ),
    );
  }

  TextSpan _buildHighlightedTextSpan({
    required BuildContext context,
    required dynamic book,
    required dynamic section,
    required String fullText,
    required List<UserHighlight> sectionHighlights,
    required TextStyle baseStyle,
  }) {
    _disposeRecognizers();

    if (sectionHighlights.isEmpty) {
      return TextSpan(text: fullText, style: baseStyle);
    }

    final List<Map<String, dynamic>> occurrences = [];
    for (final h in sectionHighlights) {
      final query = h.selectedText.trim();
      if (query.isEmpty) continue;
      int start = 0;
      while ((start = fullText.indexOf(query, start)) != -1) {
        occurrences.add({
          'start': start,
          'end': start + query.length,
          'highlight': h,
        });
        start += query.length;
      }
    }

    if (occurrences.isEmpty) {
      return TextSpan(text: fullText, style: baseStyle);
    }

    occurrences.sort((a, b) => (a['start'] as int).compareTo(b['start'] as int));

    final List<TextSpan> spans = [];
    int currentIndex = 0;

    for (final occ in occurrences) {
      final start = occ['start'] as int;
      final end = occ['end'] as int;
      final h = occ['highlight'] as UserHighlight;

      if (start < currentIndex) {
        continue;
      }

      if (start > currentIndex) {
        spans.add(TextSpan(
          text: fullText.substring(currentIndex, start),
          style: baseStyle,
        ));
      }

      final recognizer = TapGestureRecognizer()
        ..onTap = () => _showHighlightDetailModal(
              context,
              highlight: h,
              book: book,
              section: section,
            );
      _recognizers.add(recognizer);

      spans.add(TextSpan(
        text: fullText.substring(start, end),
        recognizer: recognizer,
        style: baseStyle.copyWith(
          backgroundColor: _getHighlightColor(h.color),
          decoration: h.note.trim().isNotEmpty ? TextDecoration.underline : null,
          decorationColor: _getHighlightSolidColor(h.color),
          decorationStyle: TextDecorationStyle.dotted,
        ),
      ));

      if (h.note.trim().isNotEmpty) {
        spans.add(TextSpan(
          text: ' 📝',
          recognizer: recognizer,
          style: TextStyle(
            fontSize: (baseStyle.fontSize ?? 16) * 0.75,
          ),
        ));
      }

      currentIndex = end;
    }

    if (currentIndex < fullText.length) {
      spans.add(TextSpan(
        text: fullText.substring(currentIndex),
        style: baseStyle,
      ));
    }

    return TextSpan(children: spans, style: baseStyle);
  }

  void _showTypographyModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Typography Settings',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              const Text('Font Size'),
              Consumer(
                builder: (context, ref, child) {
                  final options = ref.watch(readerOptionsProvider);
                  return Slider(
                    value: options.fontSize,
                    min: 12.0,
                    max: 32.0,
                    divisions: 10,
                    onChanged: (val) => ref
                        .read(readerOptionsProvider.notifier)
                        .updateFontSize(val),
                  );
                },
              ),
              const SizedBox(height: 16),
              const Text('Theme'),
              Consumer(
                builder: (context, ref, child) {
                  final options = ref.watch(readerOptionsProvider);
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ChoiceChip(
                        label: const Text('Light'),
                        selected: options.theme == 'light',
                        onSelected: (_) => ref
                            .read(readerOptionsProvider.notifier)
                            .updateTheme('light'),
                      ),
                      ChoiceChip(
                        label: const Text('Dark'),
                        selected: options.theme == 'dark',
                        onSelected: (_) => ref
                            .read(readerOptionsProvider.notifier)
                            .updateTheme('dark'),
                      ),
                      ChoiceChip(
                        label: const Text('Sepia'),
                        selected: options.theme == 'sepia',
                        onSelected: (_) => ref
                            .read(readerOptionsProvider.notifier)
                            .updateTheme('sepia'),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookAsync = ref.watch(bookDetailProvider(widget.slug));
    final sectionsAsync = ref.watch(summarySectionsProvider(widget.slug));
    final readerOptions = ref.watch(readerOptionsProvider);
    final audioController = ref.read(audioControllerProvider.notifier);
    final highlightsAsync = ref.watch(bookHighlightsProvider(widget.slug));
    final highlights = highlightsAsync.valueOrNull ?? [];

    // Apply basic thematic background based on settings
    Color backgroundColor = Theme.of(context).colorScheme.surface;
    Color textColor = Theme.of(context).colorScheme.onSurface;

    if (readerOptions.theme == 'dark') {
      backgroundColor = const Color(0xFF121212);
      textColor = Colors.white70;
    } else if (readerOptions.theme == 'sepia') {
      backgroundColor = const Color(0xFFF4ECD8);
      textColor = const Color(0xFF5b4636);
    }

    return sectionsAsync.when(
      data: (sections) => Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textColor),
          actions: [
            bookAsync.maybeWhen(
              data: (book) {
                final hasAnyAudio = sections.any(
                  (s) => (s.audioUrl?.trim().isNotEmpty ?? false),
                );
                return IconButton(
                  tooltip: 'Listen while reading',
                  icon: const Icon(Icons.headphones),
                  onPressed: hasAnyAudio && sections.isNotEmpty
                      ? () => audioController.loadBook(
                          bookId: book.id,
                          bookSlug: book.slug,
                          bookTitle: book.title,
                          sections: sections,
                          startIndex: _currentIndex,
                          autoPlay: true,
                        )
                      : null,
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
            bookAsync.maybeWhen(
              data: (book) {
                final currentSection = (_currentIndex < sections.length)
                    ? sections[_currentIndex]
                    : null;
                return IconButton(
                  tooltip: 'Ask AI about this book',
                  icon: const Icon(Icons.auto_awesome),
                  onPressed: () => AskBookAiSheet.show(
                    context,
                    bookSlug: book.slug,
                    bookTitle: book.title,
                    authorName: book.author.name,
                    currentSectionSlug: currentSection?.slug,
                    currentSectionTitle: currentSection?.title,
                  ),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
            IconButton(
              icon: const Icon(Icons.text_fields),
              onPressed: () => _showTypographyModal(context, ref),
            ),
          ],
        ),
        body: bookAsync.when(
          data: (book) {
            if (sections.isEmpty) {
              return Center(
                child: Text(
                  'No content available.',
                  style: TextStyle(color: textColor),
                ),
              );
            }

            _restoreProgress(bookId: book.id, sections: sections);

            return Column(
              children: [
                // Progress Bar
                LinearProgressIndicator(
                  value: (_currentIndex + 1) / sections.length,
                  backgroundColor: textColor.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _currentIndex = index);

                      try {
                        final section = sections[index];
                        ref
                            .read(progressRepositoryProvider)
                            .markSectionRead(book.id, section.id);
                      } catch (e) {
                        debugPrint('Could not update reading progress: $e');
                      }
                    },
                    itemCount: sections.length,
                    itemBuilder: (context, index) {
                      final section = sections[index];
                      final isContentLocked = section.content == null;

                      if (isContentLocked) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.lock_outline,
                                  size: 64,
                                  color: textColor.withOpacity(0.4),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  section.title,
                                  style: TextStyle(
                                    fontSize: readerOptions.fontSize * 1.3,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'This content is available for premium users only.',
                                  style: TextStyle(
                                    fontSize: readerOptions.fontSize,
                                    color: textColor.withOpacity(0.6),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                FilledButton.icon(
                                  onPressed: () => context.push(
                                    Uri(
                                      path: '/paywall',
                                      queryParameters: {
                                        'slug': book.slug,
                                        'title': book.title,
                                      },
                                    ).toString(),
                                  ),
                                  icon: const Icon(Icons.star),
                                  label: const Text('Upgrade to Premium'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24.0,
                          vertical: 32.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              section.title,
                              style: TextStyle(
                                fontSize: readerOptions.fontSize * 1.5,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                                fontFamily: readerOptions.fontFamily,
                              ),
                            ),
                            Builder(
                              builder: (context) {
                                final sectionHighlights = highlights
                                    .where((h) =>
                                        h.sectionId == section.id ||
                                        section.content!
                                            .contains(h.selectedText.trim()))
                                    .toList();
                                final noteCount = sectionHighlights
                                    .where((h) => h.note.trim().isNotEmpty)
                                    .length;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (sectionHighlights.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      InkWell(
                                        onTap: () => _showChapterNotesSheet(
                                          context,
                                          sectionHighlights,
                                          book,
                                          section,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            border: Border.all(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withValues(alpha: 0.25),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.edit_note,
                                                size: 16,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '${sectionHighlights.length} ${sectionHighlights.length == 1 ? 'highlight' : 'highlights'}${noteCount > 0 ? ' · $noteCount notes' : ''}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(
                                                Icons.chevron_right,
                                                size: 14,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 24),
                                    SelectableText.rich(
                                      _buildHighlightedTextSpan(
                                        context: context,
                                        book: book,
                                        section: section,
                                        fullText: section.content!,
                                        sectionHighlights: sectionHighlights,
                                        baseStyle: TextStyle(
                                          fontSize: readerOptions.fontSize,
                                          height: 1.6,
                                          color: textColor,
                                          fontFamily: readerOptions.fontFamily,
                                        ),
                                      ),
                                      contextMenuBuilder:
                                          (context, editableTextState) {
                                        final textEditingValue =
                                            editableTextState.textEditingValue;
                                        final selectedText = textEditingValue
                                            .selection
                                            .textInside(textEditingValue.text);
                                        final buttonItems = editableTextState
                                            .contextMenuButtonItems;

                                        if (selectedText.trim().isNotEmpty) {
                                          buttonItems.insertAll(0, [
                                            ContextMenuButtonItem(
                                              label: '🟡',
                                              onPressed: () {
                                                editableTextState.hideToolbar();
                                                _quickHighlight(
                                                  color: 'yellow',
                                                  selectedText: selectedText,
                                                  book: book,
                                                  section: section,
                                                );
                                              },
                                            ),
                                            ContextMenuButtonItem(
                                              label: '🟢',
                                              onPressed: () {
                                                editableTextState.hideToolbar();
                                                _quickHighlight(
                                                  color: 'green',
                                                  selectedText: selectedText,
                                                  book: book,
                                                  section: section,
                                                );
                                              },
                                            ),
                                            ContextMenuButtonItem(
                                              label: '🔵',
                                              onPressed: () {
                                                editableTextState.hideToolbar();
                                                _quickHighlight(
                                                  color: 'blue',
                                                  selectedText: selectedText,
                                                  book: book,
                                                  section: section,
                                                );
                                              },
                                            ),
                                            ContextMenuButtonItem(
                                              label: '🌸',
                                              onPressed: () {
                                                editableTextState.hideToolbar();
                                                _quickHighlight(
                                                  color: 'pink',
                                                  selectedText: selectedText,
                                                  book: book,
                                                  section: section,
                                                );
                                              },
                                            ),
                                            ContextMenuButtonItem(
                                              label: 'Note 📝',
                                              onPressed: () {
                                                editableTextState.hideToolbar();
                                                _showHighlightModal(
                                                  context,
                                                  book: book,
                                                  section: section,
                                                  selectedText: selectedText,
                                                );
                                              },
                                            ),
                                            ContextMenuButtonItem(
                                              label: 'Quote Card 🎨',
                                              onPressed: () {
                                                editableTextState.hideToolbar();
                                                QuoteCardDialog.show(
                                                  context,
                                                  quoteText: selectedText,
                                                  bookTitle: book.title,
                                                  bookAuthor: book.author.name,
                                                );
                                              },
                                            ),
                                          ]);
                                        }

                                        return AdaptiveTextSelectionToolbar
                                            .buttonItems(
                                          anchors: editableTextState
                                              .contextMenuAnchors,
                                          buttonItems: buttonItems,
                                        );
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                            if (index == sections.length - 1) ...[
                              const SizedBox(height: 32),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                      .withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      size: 38,
                                      color: Colors.green,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Summary Complete! 🎉',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Strengthen your retention with 3-minute active recall flashcards.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: textColor.withValues(alpha: 0.75),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    FilledButton.icon(
                                      icon: const Icon(Icons.psychology_outlined),
                                      label: const Text('Test Your Knowledge 🧠'),
                                      onPressed: () => context.push(
                                        '/books/${widget.slug}/flashcards',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 48),
                            ] else ...[
                              const SizedBox(height: 48),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Text(
              'Failed to load text.',
              style: TextStyle(color: textColor),
            ),
          ),
        ),
        bottomNavigationBar: bookAsync.maybeWhen(
          data: (book) => Consumer(
            builder: (context, ref, _) {
              final audioState = ref.watch(audioControllerProvider);
              final audioController = ref.read(
                audioControllerProvider.notifier,
              );

              final isThisBook =
                  audioState.bookSlug == book.slug &&
                  audioState.totalSections > 0;
              final duration = audioState.duration ?? Duration.zero;
              final progress = duration.inMilliseconds > 0
                  ? (audioState.currentPosition.inMilliseconds /
                            duration.inMilliseconds)
                        .clamp(0.0, 1.0)
                  : 0.0;

              return Container(
                color: backgroundColor,
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isThisBook) ...[
                        const Divider(height: 1),
                        LinearProgressIndicator(
                          value: progress,
                          minHeight: 2,
                          backgroundColor: textColor.withOpacity(0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                tooltip: audioState.isPlaying
                                    ? 'Pause'
                                    : 'Play',
                                icon: Icon(
                                  audioState.isPlaying
                                      ? Icons.pause_circle
                                      : Icons.play_circle,
                                ),
                                iconSize: 40,
                                onPressed: audioState.isLoading
                                    ? null
                                    : audioController.togglePlayPause,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      audioState.bookTitle ?? book.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: textColor.withOpacity(0.8),
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      audioState.currentSectionTitle ?? 'Audio',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: textColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (audioState.errorMessage != null)
                                      Text(
                                        audioState.errorMessage!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: Colors.orange),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Previous',
                                icon: const Icon(Icons.skip_previous),
                                onPressed: audioController.skipPrevious,
                              ),
                              IconButton(
                                tooltip: 'Next',
                                icon: const Icon(Icons.skip_next),
                                onPressed: audioController.skipNext,
                              ),
                              IconButton(
                                tooltip: 'Open player',
                                icon: const Icon(Icons.open_in_full),
                                onPressed: () =>
                                    context.push('/books/${book.slug}/listen'),
                              ),
                              IconButton(
                                tooltip: 'Stop',
                                icon: const Icon(Icons.close),
                                onPressed: () =>
                                    audioController.stop(clearQueue: true),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        const Divider(height: 1),
                      ],
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.arrow_back),
                              label: const Text('Previous'),
                              onPressed: _currentIndex > 0
                                  ? () => _pageController.previousPage(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      curve: Curves.easeInOut,
                                    )
                                  : null,
                            ),
                            Text(
                              '${_currentIndex + 1} of ${sections.length}',
                              style: TextStyle(color: textColor),
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.arrow_forward),
                              label: const Text('Next'),
                              // If it's the last section, maybe change label to "Finish"
                              onPressed: _currentIndex < sections.length - 1
                                  ? () => _pageController.nextPage(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      curve: Curves.easeInOut,
                                    )
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          orElse: () => null,
        ),
      ),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => Scaffold(
        body: Center(child: Text('Failed to load sections: $error')),
      ),
    );
  }
}
