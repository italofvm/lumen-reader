import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../widgets/ai_explanation_dialog.dart';
import '../widgets/ai_summary_dialog.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen_reader/features/settings/domain/providers/settings_providers.dart';
import 'package:lumen_reader/features/library/presentation/providers/library_providers.dart';
import '../widgets/reader_settings_sheet.dart';
import 'package:lumen_reader/features/reader/services/providers.dart';
import 'package:lumen_reader/features/reader/presentation/widgets/bookmarks_sheet.dart';
import 'package:lumen_reader/features/reader/presentation/widgets/reader_search_sheet.dart';

class PdfReaderScreen extends ConsumerStatefulWidget {
  final String title;
  final String filePath;
  final Uint8List? fileBytes; // Support for Web/Memory

  const PdfReaderScreen({
    super.key,
    required this.title,
    required this.filePath,
    this.fileBytes,
  });

  @override
  ConsumerState<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends ConsumerState<PdfReaderScreen> {
  final PdfViewerController _pdfViewerController = PdfViewerController();
  String _selectedText = '';
  int _totalPages = 0;
  bool _isInitialized = false;
  bool _isUiVisible = true;
  String? _bookId;
  PdfDocument? _searchDocument;

  double? _lastAppliedZoom;

  ProviderSubscription<double>? _zoomSub;

  Offset? _lastPointerDown;
  int? _lastPointerDownMs;

  void _goToPreviousPage() {
    final current = _pdfViewerController.pageNumber;
    if (current <= 1) return;
    _pdfViewerController.jumpToPage(current - 1);
  }

  void _goToNextPage() {
    final current = _pdfViewerController.pageNumber;
    if (_totalPages > 0 && current >= _totalPages) return;
    _pdfViewerController.jumpToPage(current + 1);
  }

  void _showAIExplanation(BuildContext context) {
    if (_selectedText.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AIExplanationDialog(selectedText: _selectedText),
      );
    } else {
      _showSimpleSnackBar(context, 'Selecione um texto para explicar.');
    }
  }

  Future<List<ReaderSearchHit>> _searchInPdf(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    final PdfDocument doc;
    if (_searchDocument != null) {
      doc = _searchDocument!;
    } else {
      final Uint8List bytes;
      if (widget.fileBytes != null) {
        bytes = widget.fileBytes!;
      } else {
        bytes = await File(widget.filePath).readAsBytes();
      }
      doc = PdfDocument(inputBytes: bytes);
      _searchDocument = doc;
    }

    final extractor = PdfTextExtractor(doc);
    final hits = <ReaderSearchHit>[];

    final pageCount = doc.pages.count;
    for (int i = 0; i < pageCount; i++) {
      final text = extractor.extractText(startPageIndex: i, endPageIndex: i);
      if (text.isEmpty) continue;

      final lower = text.toLowerCase();
      final idx = lower.indexOf(q);
      if (idx < 0) continue;

      final start = (idx - 40).clamp(0, text.length);
      final end = (idx + q.length + 60).clamp(0, text.length);
      final snippet = text.substring(start, end).replaceAll(RegExp(r'\s+'), ' ');

      hits.add(
        ReaderSearchHit(
          title: 'Página ${i + 1}',
          subtitle: snippet,
          targetIndex: i + 1,
        ),
      );

      if (hits.length >= 40) break;
    }

    return hits;
  }

  void _openSearch(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => ReaderSearchSheet(
        title: 'Buscar no PDF',
        search: _searchInPdf,
        onNavigate: (page) {
          _pdfViewerController.jumpToPage(page);
        },
      ),
    );
  }

  Future<void> _showPageSummary(BuildContext context) async {
    final int pageNumber = _pdfViewerController.pageNumber;
    _showSimpleSnackBar(context, 'Extraindo texto da página $pageNumber...');

    try {
      final Uint8List bytes;
      if (widget.fileBytes != null) {
        bytes = widget.fileBytes!;
      } else {
        bytes = await File(widget.filePath).readAsBytes();
      }

      final PdfDocument document = PdfDocument(inputBytes: bytes);
      final String pageText = PdfTextExtractor(document).extractText(
        startPageIndex: pageNumber - 1,
        endPageIndex: pageNumber - 1,
      );
      document.dispose();

      if (!context.mounted) return;

      showDialog(
        context: context,
        builder: (context) => AISummaryDialog(
          title: 'Página $pageNumber',
          content: pageText.isNotEmpty
              ? pageText
              : 'Conteúdo da página $pageNumber do livro ${widget.title}',
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      _showSimpleSnackBar(context, 'Erro ao extrair texto: $e');
    }
  }

  void _showSimpleSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showSmartDictionary(BuildContext context) {
    if (_selectedText.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AISummaryDialog(
          title: 'Dicionário Inteligente: $_selectedText',
          content:
              'Defina e dê exemplos de uso para a palavra ou termo: "$_selectedText"',
        ),
      );
    } else {
      _showSimpleSnackBar(context, 'Selecione uma palavra para o dicionário.');
    }
  }

  void _toggleBookmark(BuildContext context) {
    final bookId = _bookId;
    if (bookId == null) {
      _showSimpleSnackBar(context, 'Livro não encontrado na biblioteca.');
      return;
    }
    final page = _pdfViewerController.pageNumber;
    ref.read(bookmarkServiceProvider).addBookmark(
          bookId: bookId,
          label: 'Página $page',
          position: page.toString(),
        );
    _showSimpleSnackBar(context, 'Marcador salvo: Página $page');
  }

  void _openBookmarks(BuildContext context) {
    final bookId = _bookId;
    if (bookId == null) {
      _showSimpleSnackBar(context, 'Livro não encontrado na biblioteca.');
      return;
    }
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => BookmarksSheet(
        bookId: bookId,
        title: widget.title,
        onSelect: (position) {
          final page = int.tryParse(position);
          if (page != null) {
            _pdfViewerController.jumpToPage(page);
          }
        },
      ),
    );
  }

  void _toggleFocusMode() {
    setState(() {
      _isUiVisible = !_isUiVisible;
    });
  }

  @override
  void initState() {
    super.initState();
    _zoomSub = ref.listenManual(
      readerSettingsProvider.select((s) => s.zoom),
      (previous, next) {
        if (_lastAppliedZoom == next) return;
        _lastAppliedZoom = next;
        if (_pdfViewerController.zoomLevel != next) {
          _pdfViewerController.zoomLevel = next;
        }
      },
    );
  }

  @override
  void dispose() {
    _zoomSub?.close();
    try {
      _searchDocument?.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isUiVisible
          ? AppBar(
              title: Text(widget.title),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings_display),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const ReaderSettingsSheet(),
                    );
                  },
                  tooltip: 'Ajustes de Leitura',
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _openSearch(context),
                  tooltip: 'Buscar no livro',
                ),
                IconButton(
                  icon: const Icon(Icons.summarize),
                  onPressed: () => _showPageSummary(context),
                  tooltip: 'Resumir Página',
                ),
                IconButton(
                  icon: const Icon(Icons.psychology),
                  onPressed: () => _showAIExplanation(context),
                  tooltip: 'Explicar seleção com IA',
                ),
                IconButton(
                  icon: const Icon(Icons.translate),
                  onPressed: () => _showSmartDictionary(context),
                  tooltip: 'Dicionário Inteligente',
                ),
                IconButton(
                  icon: const Icon(Icons.bookmark_border),
                  onPressed: () => _toggleBookmark(context),
                  onLongPress: () => _openBookmarks(context),
                  tooltip: 'Marcar Página',
                ),
              ],
            )
          : null,
      body: Stack(
        children: [
          _buildReaderBody(),
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (e) {
                _lastPointerDown = e.localPosition;
                _lastPointerDownMs = DateTime.now().millisecondsSinceEpoch;
              },
              onPointerUp: (e) {
                if (_selectedText.trim().isNotEmpty) return;

                // Only treat as a tap (not a swipe/drag).
                final down = _lastPointerDown;
                final downMs = _lastPointerDownMs;
                _lastPointerDown = null;
                _lastPointerDownMs = null;
                if (down == null || downMs == null) return;
                final dt = DateTime.now().millisecondsSinceEpoch - downMs;
                final dx = (e.localPosition.dx - down.dx).abs();
                final dy = (e.localPosition.dy - down.dy).abs();
                if (dt > 260 || dx > 18 || dy > 18) return;

                final width = MediaQuery.of(context).size.width;
                final ratio = e.localPosition.dx / width;

                if (ratio <= 0.20) {
                  _goToPreviousPage();
                  return;
                }
                if (ratio >= 0.80) {
                  _goToNextPage();
                  return;
                }

                _toggleFocusMode();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReaderBody() {
    final settings = ref.watch(readerSettingsProvider);
    _lastAppliedZoom ??= settings.zoom;

    Widget reader = widget.fileBytes != null
        ? SfPdfViewer.memory(
            widget.fileBytes!,
            controller: _pdfViewerController,
            scrollDirection: settings.isHorizontal
                ? PdfScrollDirection.horizontal
                : PdfScrollDirection.vertical,
            enableTextSelection: true,
            onDocumentLoaded: (PdfDocumentLoadedDetails details) {
              setState(() {
                _totalPages = details.document.pages.count;
              });
              _restorePosition();
            },
            onPageChanged: (PdfPageChangedDetails details) {
              if (_isInitialized) {
                _saveProgress(details.newPageNumber);
              }
            },
            onTextSelectionChanged: (PdfTextSelectionChangedDetails details) {
              if (details.selectedText != null) {
                setState(() {
                  _selectedText = details.selectedText!;
                });
              }
            },
          )
        : SfPdfViewer.file(
            File(widget.filePath),
            controller: _pdfViewerController,
            scrollDirection: settings.isHorizontal
                ? PdfScrollDirection.horizontal
                : PdfScrollDirection.vertical,
            enableTextSelection: true,
            onDocumentLoaded: (PdfDocumentLoadedDetails details) {
              setState(() {
                _totalPages = details.document.pages.count;
              });
              _restorePosition();
            },
            onPageChanged: (PdfPageChangedDetails details) {
              if (_isInitialized) {
                _saveProgress(details.newPageNumber);
              }
            },
            onTextSelectionChanged: (PdfTextSelectionChangedDetails details) {
              if (details.selectedText != null) {
                setState(() {
                  _selectedText = details.selectedText!;
                });
              }
            },
          );

    // Apply Page Turn Animation (built-in in SfPdfViewer if SinglePage mode)
    // For now we keep default.

    // Apply Color Mode Filter
    if (settings.colorMode == 'sepia') {
      return ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          0.90,
          0.05,
          0.05,
          0,
          0,
          0.05,
          0.85,
          0.05,
          0,
          0,
          0.05,
          0.05,
          0.70,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: reader,
      );
    } else if (settings.colorMode == 'dark' ||
        settings.colorMode == 'midnight') {
      return ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          -1,
          0,
          0,
          0,
          255,
          0,
          -1,
          0,
          0,
          255,
          0,
          0,
          -1,
          0,
          255,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: reader,
      );
    } else if (settings.colorMode == 'paper') {
      return ColorFiltered(
        colorFilter: const ColorFilter.mode(
          Color(0xFFFAF9F6),
          BlendMode.multiply,
        ),
        child: reader,
      );
    }

    return reader;
  }

  void _restorePosition() {
    final libraryState = ref.read(libraryProvider);
    libraryState.whenData((books) {
      try {
        final book = books.firstWhere((b) => b.filePath == widget.filePath);
        _bookId = book.id;
        if (book.lastPosition != null) {
          final page = int.parse(book.lastPosition!);
          _pdfViewerController.jumpToPage(page);
        }
      } catch (_) {}
      _isInitialized = true;
    });

    // Mark as last read
    libraryState.whenData((books) {
      try {
        final book = books.firstWhere((b) => b.filePath == widget.filePath);
        ref.read(readerSettingsProvider.notifier).setLastReadBookId(book.id);
      } catch (_) {}
    });
  }

  void _saveProgress(int page) {
    if (_totalPages == 0) return;
    final progress = page / _totalPages;

    final libraryState = ref.read(libraryProvider);
    libraryState.whenData((books) {
      try {
        final book = books.firstWhere((b) => b.filePath == widget.filePath);
        ref
            .read(libraryProvider.notifier)
            .updateBookPosition(book.id, page.toString(), progress);
      } catch (_) {}
    });
  }
}
