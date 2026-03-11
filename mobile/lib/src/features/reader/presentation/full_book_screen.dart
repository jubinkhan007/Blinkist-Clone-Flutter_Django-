import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../../../core/networking/api_client.dart';
import '../../book/data/content_repository.dart';
import 'reader_options_provider.dart';

class FullBookScreen extends ConsumerWidget {
  final String slug;

  const FullBookScreen({super.key, required this.slug});

  void _log(String message) {
    debugPrint('[FullBookScreen] $message');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(bookDetailProvider(slug));

    return bookAsync.when(
      data: (book) {
        final pdfUrl = book.fullBookPdfUrl;
        final hasPdf = pdfUrl != null && pdfUrl.isNotEmpty;
        final hasText = book.fullText.isNotEmpty;
        final resolvedPdfUrl = hasPdf ? resolveServerUrl(pdfUrl) : null;

        _log(
          'Loaded slug=${book.slug} title=${book.title} '
          'hasPdf=$hasPdf rawPdfUrl=$pdfUrl resolvedPdfUrl=$resolvedPdfUrl '
          'hasText=$hasText fullTextLength=${book.fullText.length}',
        );

        // Prefer the in-app text reader when available.
        // The PDF viewer remains available as an explicit alternate path.
        if (hasText) {
          _log('Routing to text reader for slug=${book.slug}');
          return _TextReaderView(book: book, ref: ref, pdfUrl: resolvedPdfUrl);
        }

        if (hasPdf) {
          _log('Routing to PDF reader for slug=${book.slug}');
          return _PdfReaderView(title: book.title, pdfUrl: resolvedPdfUrl!);
        }

        _log('No full-book asset available for slug=${book.slug}');
        return Scaffold(
          appBar: AppBar(title: Text(book.title)),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    book.isPremium ? Icons.lock_outline : Icons.book_outlined,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    book.isPremium
                        ? 'Full book is locked'
                        : 'Full book not available yet.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (book.isPremium) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Upgrade to Premium to read the full book.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () {
                        final uri = Uri(
                          path: '/paywall',
                          queryParameters: {
                            'slug': book.slug,
                            'title': book.title,
                          },
                        ).toString();
                        Navigator.of(context).pop();
                        GoRouter.of(context).push(uri);
                      },
                      icon: const Icon(Icons.star),
                      label: const Text('Upgrade to Premium'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}

// ── PDF reader ────────────────────────────────────────────────────────────────

class _PdfReaderView extends ConsumerStatefulWidget {
  final String title;
  final String pdfUrl;

  const _PdfReaderView({required this.title, required this.pdfUrl});

  @override
  ConsumerState<_PdfReaderView> createState() => _PdfReaderViewState();
}

class _PdfReaderViewState extends ConsumerState<_PdfReaderView> {
  final PdfViewerController _controller = PdfViewerController();
  int _currentPage = 1;
  int _totalPages = 0;
  bool _showToolbar = true;
  File? _pdfFile;
  String? _error;

  void _log(String message) {
    debugPrint('[PdfReaderView] $message');
  }

  @override
  void initState() {
    super.initState();
    _downloadPdfToLocalFile();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _log(
      'build title=${widget.title} url=${widget.pdfUrl} '
      'currentPage=$_currentPage totalPages=$_totalPages '
      'localFile=${_pdfFile?.path} error=$_error',
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _showToolbar
          ? AppBar(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_totalPages > 0)
                    Text(
                      'Page $_currentPage of $_totalPages',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.zoom_in),
                  onPressed: () => _controller.zoomLevel =
                      (_controller.zoomLevel + 0.25).clamp(0.75, 3.0),
                ),
                IconButton(
                  icon: const Icon(Icons.zoom_out),
                  onPressed: () => _controller.zoomLevel =
                      (_controller.zoomLevel - 0.25).clamp(0.75, 3.0),
                ),
              ],
            )
          : null,
      body: _buildBody(),
      bottomNavigationBar: _showToolbar && _totalPages > 0
          ? _PageJumpBar(
              controller: _controller,
              currentPage: _currentPage,
              totalPages: _totalPages,
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      _log('Rendering error UI: $_error');
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.black45, size: 48),
              const SizedBox(height: 16),
              const Text('Failed to load PDF inside the app'),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _error = null;
                    _pdfFile = null;
                  });
                  _downloadPdfToLocalFile();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_pdfFile == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Preparing secure PDF...'),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => setState(() => _showToolbar = !_showToolbar),
      child: Container(
        color: const Color(0xFFF4F1EA),
        child: SfPdfViewer.file(
          _pdfFile!,
          controller: _controller,
          pageLayoutMode: PdfPageLayoutMode.continuous,
          scrollDirection: PdfScrollDirection.vertical,
          canShowScrollHead: true,
          canShowScrollStatus: true,
          onPageChanged: (details) {
            _log(
              'onPageChanged old=${details.oldPageNumber} '
              'new=${details.newPageNumber}',
            );
            setState(() => _currentPage = details.newPageNumber);
          },
          onDocumentLoaded: (details) {
            _log(
              'onDocumentLoaded pages=${details.document.pages.count} '
              'file=${_pdfFile?.path} url=${widget.pdfUrl}',
            );
            setState(() => _totalPages = details.document.pages.count);
          },
          onDocumentLoadFailed: (details) {
            _log(
              'onDocumentLoadFailed description=${details.description} '
              'error=${details.error}',
            );
            setState(() => _error = 'Failed to render PDF: ${details.error}');
          },
        ),
      ),
    );
  }

  Future<void> _downloadPdfToLocalFile() async {
    _log('Downloading PDF into local app storage from ${widget.pdfUrl}');

    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = 'full_book_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final localFile = File('${tempDir.path}/$fileName');

      // Use a plain Dio (no baseUrl) since widget.pdfUrl is already an
      // absolute URL like http://localhost:8001/media/books/pdf/foo.pdf.
      // The app-level dioProvider prepends its baseUrl which corrupts the URL.
      final storage = ref.read(secureStorageProvider);
      final token = await storage.read(key: 'access_token');
      final plainDio = Dio();

      await plainDio.download(
        widget.pdfUrl,
        localFile.path,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          receiveTimeout: const Duration(seconds: 60),
          headers: token != null ? {'Authorization': 'Bearer $token'} : null,
        ),
      );

      final exists = await localFile.exists();
      final size = exists ? await localFile.length() : 0;
      _log(
        'Local PDF download complete path=${localFile.path} '
        'exists=$exists size=$size',
      );

      if (!exists || size < 100) {
        if (!mounted) return;
        setState(() {
          _error =
              'Downloaded file is empty or invalid (${size}B). '
              'Please check if the PDF was uploaded for this book.';
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _error = null;
        _pdfFile = localFile;
      });
    } on DioException catch (e) {
      _log(
        'Local PDF download failed '
        'status=${e.response?.statusCode} message=${e.message}',
      );
      if (!mounted) return;
      setState(() {
        _error = 'Download failed: ${e.response?.statusCode ?? e.message}';
      });
    } catch (e) {
      _log('Local PDF download threw $e');
      if (!mounted) return;
      setState(() {
        _error = 'Download failed: $e';
      });
    }
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
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, color: Colors.black87),
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
                activeColor: Colors.black87,
                inactiveColor: Colors.black26,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: Colors.black87),
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
  final String? pdfUrl;

  const _TextReaderView({required this.book, required this.ref, this.pdfUrl});

  void _log(String message) {
    debugPrint('[FullBookTextReader] $message');
  }

  @override
  Widget build(BuildContext context, WidgetRef r) {
    final readerOptions = r.watch(readerOptionsProvider);
    _log(
      'build title=${book.title} pdfUrl=$pdfUrl '
      'fullTextLength=${book.fullText.length}',
    );

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
        title: Text(
          book.title,
          style: TextStyle(color: fg, fontSize: 16),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (pdfUrl != null)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Open PDF',
              onPressed: () {
                _log('Opening in-app PDF viewer for $pdfUrl');
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        _PdfReaderView(title: book.title, pdfUrl: pdfUrl!),
                  ),
                );
              },
            ),
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
