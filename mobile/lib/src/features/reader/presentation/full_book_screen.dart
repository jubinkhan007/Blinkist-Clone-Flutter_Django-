import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../../../core/networking/api_client.dart';
import '../../book/data/content_repository.dart';
import 'reader_options_provider.dart';

class FullBookScreen extends ConsumerWidget {
  final String slug;

  const FullBookScreen({super.key, required this.slug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(bookDetailProvider(slug));

    return bookAsync.when(
      data: (book) {
        final pdfUrl = book.fullBookPdfUrl;

        if (pdfUrl != null && pdfUrl.isNotEmpty) {
          return _PdfReaderView(
            title: book.title,
            pdfUrl: resolveServerUrl(pdfUrl),
          );
        }

        if (book.fullText.isNotEmpty) {
          return _TextReaderView(book: book, ref: ref);
        }

        return Scaffold(
          appBar: AppBar(title: Text(book.title)),
          body: const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.book_outlined, size: 64),
                  SizedBox(height: 16),
                  Text(
                    'Full book not available yet.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}

// ── PDF reader ────────────────────────────────────────────────────────────────

class _PdfReaderView extends StatefulWidget {
  final String title;
  final String pdfUrl;

  const _PdfReaderView({required this.title, required this.pdfUrl});

  @override
  State<_PdfReaderView> createState() => _PdfReaderViewState();
}

class _PdfReaderViewState extends State<_PdfReaderView> {
  final PdfViewerController _controller = PdfViewerController();
  int _currentPage = 1;
  int _totalPages = 0;
  bool _showToolbar = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF424242),
      appBar: _showToolbar
          ? AppBar(
              backgroundColor: Colors.black87,
              iconTheme: const IconThemeData(color: Colors.white),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_totalPages > 0)
                    Text(
                      'Page $_currentPage of $_totalPages',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12),
                    ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.zoom_in, color: Colors.white),
                  onPressed: () => _controller.zoomLevel =
                      (_controller.zoomLevel + 0.25).clamp(0.75, 3.0),
                ),
                IconButton(
                  icon: const Icon(Icons.zoom_out, color: Colors.white),
                  onPressed: () => _controller.zoomLevel =
                      (_controller.zoomLevel - 0.25).clamp(0.75, 3.0),
                ),
              ],
            )
          : null,
      body: GestureDetector(
        onTap: () => setState(() => _showToolbar = !_showToolbar),
        child: SfPdfViewer.network(
          widget.pdfUrl,
          controller: _controller,
          pageLayoutMode: PdfPageLayoutMode.continuous,
          scrollDirection: PdfScrollDirection.vertical,
          canShowScrollHead: true,
          canShowScrollStatus: true,
          onPageChanged: (PdfPageChangedDetails details) {
            setState(() => _currentPage = details.newPageNumber);
          },
          onDocumentLoaded: (PdfDocumentLoadedDetails details) {
            setState(() => _totalPages = details.document.pages.count);
          },
          onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to load PDF: ${details.error}')),
            );
          },
        ),
      ),
      bottomNavigationBar: _showToolbar && _totalPages > 0
          ? _PageJumpBar(
              controller: _controller,
              currentPage: _currentPage,
              totalPages: _totalPages,
            )
          : null,
    );
  }
}

class _PageJumpBar extends StatelessWidget {
  final PdfViewerController controller;
  final int currentPage;
  final int totalPages;

  const _PageJumpBar({
    required this.controller,
    required this.currentPage,
    required this.totalPages,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, color: Colors.white),
              onPressed: currentPage > 1
                  ? () => controller.previousPage()
                  : null,
            ),
            Expanded(
              child: Slider(
                value: currentPage.toDouble(),
                min: 1,
                max: totalPages.toDouble(),
                onChanged: (val) => controller.jumpToPage(val.round()),
                activeColor: Colors.white,
                inactiveColor: Colors.white30,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: Colors.white),
              onPressed: currentPage < totalPages
                  ? () => controller.nextPage()
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Plain text fallback reader ────────────────────────────────────────────────

class _TextReaderView extends ConsumerWidget {
  final dynamic book;
  final WidgetRef ref;

  const _TextReaderView({required this.book, required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef r) {
    final readerOptions = r.watch(readerOptionsProvider);

    Color bg = Theme.of(context).colorScheme.surface;
    Color fg = Theme.of(context).colorScheme.onSurface;
    if (readerOptions.theme == 'dark') {
      bg = const Color(0xFF121212);
      fg = Colors.white70;
    } else if (readerOptions.theme == 'sepia') {
      bg = const Color(0xFFF4ECD8);
      fg = const Color(0xFF5b4636);
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: fg),
        title: Text(book.title,
            style: TextStyle(color: fg, fontSize: 16),
            overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.text_fields),
            onPressed: () => _showTypographyModal(context, r),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Text(
          book.fullText,
          style: TextStyle(
            fontSize: readerOptions.fontSize,
            height: 1.7,
            color: fg,
            fontFamily: readerOptions.fontFamily,
          ),
        ),
      ),
    );
  }

  void _showTypographyModal(BuildContext context, WidgetRef r) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Typography', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            const Text('Font Size'),
            Consumer(
              builder: (context, ref, _) {
                final options = ref.watch(readerOptionsProvider);
                return Slider(
                  value: options.fontSize,
                  min: 12,
                  max: 32,
                  divisions: 10,
                  onChanged: (val) => ref
                      .read(readerOptionsProvider.notifier)
                      .updateFontSize(val),
                );
              },
            ),
            const SizedBox(height: 8),
            Consumer(
              builder: (context, ref, _) {
                final options = ref.watch(readerOptionsProvider);
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final t in ['light', 'dark', 'sepia'])
                      ChoiceChip(
                        label: Text(t[0].toUpperCase() + t.substring(1)),
                        selected: options.theme == t,
                        onSelected: (_) => ref
                            .read(readerOptionsProvider.notifier)
                            .updateTheme(t),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
