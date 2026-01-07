import 'package:flutter/material.dart';
import 'package:epubx/epubx.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen_reader/features/settings/domain/providers/settings_providers.dart';
import 'package:lumen_reader/features/library/presentation/providers/library_providers.dart';
import '../widgets/reader_settings_sheet.dart';
import 'package:lumen_reader/features/reader/services/providers.dart';
import 'package:lumen_reader/features/reader/presentation/widgets/bookmarks_sheet.dart';
import 'package:lumen_reader/features/reader/presentation/widgets/reader_search_sheet.dart';
import 'package:lumen_reader/features/reader/presentation/widgets/ask_book_dialog.dart';

import 'package:flutter/services.dart';

class EpubReaderScreen extends ConsumerStatefulWidget {
  final String title;
  final String filePath;
  final Uint8List? fileBytes; // Support for Web/Memory

  const EpubReaderScreen({
    super.key,
    required this.title,
    required this.filePath,
    this.fileBytes,
  });

  @override
  ConsumerState<EpubReaderScreen> createState() => _EpubReaderScreenState();
}

class PageInfo {
  final int chapterIndex;
  final int pageIndexInSection;
  final String title;

  PageInfo({
    required this.chapterIndex,
    required this.pageIndexInSection,
    required this.title,
  });
}

class _EpubReaderScreenState extends ConsumerState<EpubReaderScreen> {
  Future<EpubBook>? _epubBookFuture;
  final PageController _pageController = PageController();
  final List<PageInfo> _virtualPages = [];
  int _currentPageIndex = 0;
  EpubBook? _loadedBook;
  bool _isCalculating = false;
  final Map<int, String> _sanitizedChapterHtml = {};
  final Map<int, String> _chapterPlainText = {};
  bool _isUiVisible = true;
  String? _bookId;

  double? _lastFontSize;
  double? _lastZoom;

  ProviderSubscription<(double, double)>? _settingsSub;

  Offset? _lastPointerDown;
  int? _lastPointerDownMs;

  @override
  void initState() {
    super.initState();
    _epubBookFuture = _loadEpub();

    _settingsSub = ref.listenManual(
      readerSettingsProvider.select((s) => (s.fontSize, s.zoom)),
      (previous, next) {
        final (fontSize, zoom) = next;
        if (_lastFontSize == fontSize && _lastZoom == zoom) return;
        _lastFontSize = fontSize;
        _lastZoom = zoom;

        if (_loadedBook != null) {
          _virtualPages.clear();
          setState(() {});
        }
      },
    );
  }

  @override
  void dispose() {
    _settingsSub?.close();
    super.dispose();
  }

  Future<List<ReaderSearchHit>> _searchInEpub(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    final book = _loadedBook;
    if (book == null) return [];

    final settings = ref.read(readerSettingsProvider);
    final chapters = book.Chapters ?? const <EpubChapter>[];
    final hits = <ReaderSearchHit>[];

    // Keep consistent with pagination heuristic in _calculateVirtualPages.
    double charsPerPage = 1200 / (settings.fontSize / 16.0) / settings.zoom;
    if (charsPerPage < 200) charsPerPage = 200;

    for (int i = 0; i < chapters.length; i++) {
      final chapter = chapters[i];
      final html = _getSanitizedChapterHtml(i, chapter.HtmlContent ?? '');
      final text = html
          .replaceAll(RegExp(r'<[^>]*>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (text.isEmpty) continue;

      final lower = text.toLowerCase();
      final idx = lower.indexOf(q);
      if (idx < 0) continue;

      final start = (idx - 40).clamp(0, text.length);
      final end = (idx + q.length + 60).clamp(0, text.length);
      final snippet = text.substring(start, end);

      final estimatedPages = (text.length / charsPerPage).ceil();
      final actualPages = estimatedPages > 0 ? estimatedPages : 1;
      final pageInChapter = ((idx / text.length) * actualPages)
          .floor()
          .clamp(0, actualPages - 1);

      final globalIndex = _virtualPages.indexWhere(
        (p) => p.chapterIndex == i && p.pageIndexInSection == pageInChapter,
      );

      hits.add(
        ReaderSearchHit(
          title: chapter.Title ?? 'Capítulo ${i + 1}',
          subtitle: snippet,
          targetIndex: globalIndex >= 0 ? globalIndex : 0,
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
        title: 'Buscar no EPUB',
        search: _searchInEpub,
        onNavigate: (index) {
          if (index >= 0 && index < _virtualPages.length) {
            _pageController.jumpToPage(index);
          }
        },
      ),
    );
  }

  String _sanitizeHtml(String html) {
    var out = html;

    // Remove some common watermark/ads patterns from pirated conversions.
    // Keeping it intentionally conservative to avoid breaking real content.
    final patterns = <RegExp>[
      RegExp(r'Converted\s+by\s+convertEpub', caseSensitive: false),
      RegExp(r'\bdLivros\b', caseSensitive: false),
      RegExp(r'\bBaixe\s+Livros\b', caseSensitive: false),
      RegExp(r'\{\s*Baixe\s+Livros[^}]*\}', caseSensitive: false),
      RegExp(r'<(p|div)[^>]*>\s*Converted\s+by\s+convertEpub\s*</\1>',
          caseSensitive: false),
    ];

    for (final r in patterns) {
      out = out.replaceAll(r, '');
    }

    return out;
  }

  String _getSanitizedChapterHtml(int chapterIndex, String html) {
    final cached = _sanitizedChapterHtml[chapterIndex];
    if (cached != null) return cached;
    final sanitized = _sanitizeHtml(html);
    _sanitizedChapterHtml[chapterIndex] = sanitized;
    return sanitized;
  }

  String _getChapterPlainText(int chapterIndex, String html) {
    final cached = _chapterPlainText[chapterIndex];
    if (cached != null) return cached;

    final sanitized = _getSanitizedChapterHtml(chapterIndex, html);

    // First, add newlines for common block-level tags so paragraphs don't collapse.
    final withBreaks = sanitized
        .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<\s*/\s*p\s*>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<\s*p\b[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<\s*/\s*div\s*>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<\s*div\b[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<\s*/\s*li\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<\s*li\b[^>]*>', caseSensitive: false), '• ')
        .replaceAll(
          RegExp(r'<\s*/\s*(h1|h2|h3|h4|h5|h6)\s*>', caseSensitive: false),
          '\n\n',
        )
        .replaceAll(
          RegExp(r'<\s*(h1|h2|h3|h4|h5|h6)\b[^>]*>', caseSensitive: false),
          '\n',
        );

    // Some EPUBs embed HTML as escaped entities (&lt;p&gt;...&lt;/p&gt;).
    // Decode basic entities first, then strip tags again.
    String decoded = withBreaks
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");

    // Decode numeric entities like &#160; (non-breaking space)
    decoded = decoded.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
      final code = int.tryParse(m.group(1) ?? '');
      if (code == null) return '';
      return String.fromCharCode(code);
    });

    // Decode hex entities like &#xA0;
    decoded = decoded.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
      final code = int.tryParse(m.group(1) ?? '', radix: 16);
      if (code == null) return '';
      return String.fromCharCode(code);
    });

    // Remove soft hyphen which breaks words visually in text mode.
    decoded = decoded.replaceAll('\u00ad', '');

    final text = decoded
        .replaceAll(RegExp(r'<script[^>]*>[\s\S]*?<\/script>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?<\/style>', caseSensitive: false), ' ')
        // Removing inline tags should NOT introduce spaces (some EPUBs wrap each letter in <span>).
        // Block-level spacing is handled earlier in `withBreaks`.
        .replaceAll(RegExp(r'<[^>]*>'), '')
        // Normalize whitespace but preserve paragraph breaks.
        .replaceAll(RegExp(r'[ \t\f\v]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll(RegExp(r' *\n *'), '\n')
        .trim();
    _chapterPlainText[chapterIndex] = text;
    return text;
  }

  String _sliceByWordBoundary(String text, int startRaw, int pageSize) {
    if (text.isEmpty) return '';
    final maxLen = text.length;
    int start = startRaw.clamp(0, maxLen);
    int end = (start + pageSize).clamp(0, maxLen);

    bool isWs(int codeUnit) =>
        codeUnit == 0x20 || codeUnit == 0x0A || codeUnit == 0x0D || codeUnit == 0x09;

    // Avoid starting in the middle of a word.
    if (start > 0 && start < maxLen && !isWs(text.codeUnitAt(start))) {
      final backLimit = (start - 40).clamp(0, start);
      for (int i = start; i > backLimit; i--) {
        if (isWs(text.codeUnitAt(i - 1))) {
          start = i;
          break;
        }
      }
    }

    // Avoid ending in the middle of a word.
    if (end > 0 && end < maxLen && !isWs(text.codeUnitAt(end - 1))) {
      final forwardLimit = (end + 40).clamp(end, maxLen);
      for (int i = end; i < forwardLimit; i++) {
        if (isWs(text.codeUnitAt(i))) {
          end = i;
          break;
        }
      }
    }

    if (start >= end) return '';

    var out = text.substring(start, end).trim();
    // Avoid huge top blank areas caused by paragraph breaks at the start of the slice.
    out = out.replaceFirst(RegExp(r'^\n+'), '');
    // Compact excessive blank lines inside the slice.
    out = out.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return out.trim();
  }

  Future<EpubBook> _loadEpub() async {
    final Uint8List bytes;
    if (widget.fileBytes != null) {
      bytes = widget.fileBytes!;
    } else {
      bytes = await File(widget.filePath).readAsBytes();
    }

    final book = await EpubReader.readBook(bytes);
    setState(() {
      _loadedBook = book;
    });
    // Initial calculation (rough estimate before we have screen size)
    _initialCalculatePages(book);
    return book;
  }

  void _initialCalculatePages(EpubBook book) {
    if (book.Chapters == null) return;
    _virtualPages.clear();
    for (int i = 0; i < book.Chapters!.length; i++) {
      final chapter = book.Chapters![i];
      // Rough estimate: 1 page per chapter until we measure properly
      _virtualPages.add(
        PageInfo(
          chapterIndex: i,
          pageIndexInSection: 0,
          title: chapter.Title ?? 'Capítulo ${i + 1}',
        ),
      );
    }
    setState(() {});
  }

  // This will be called when we have the actual screen size
  void _calculateVirtualPages(
    EpubBook book,
    double viewportHeight,
    double fontSize,
    double zoom,
  ) {
    if (_isCalculating) return;
    _isCalculating = true;

    final chapters = book.Chapters ?? [];
    final newList = <PageInfo>[];

    // For now, let's use a more granular estimate while we don't have a reliable height-based splitter.
    // Real pagination requires rendering. For "Moon+ Reader" feel,
    // we ideally want to know how many "screens" are in a chapter.

    // Improved Estimate:
    // Roughly 800-1200 characters per "page" depending on font size.
    for (int i = 0; i < chapters.length; i++) {
      final chapter = chapters[i];
      final plainText = _getChapterPlainText(i, chapter.HtmlContent ?? '');
      final rawTextLen = plainText.length;

      // Base chars per page at 16pt font
      double charsPerPage = 1200 / (fontSize / 16.0) / zoom;
      if (charsPerPage < 200) charsPerPage = 200;

      final estimatedPages = (rawTextLen / charsPerPage).ceil();
      final actualPages = estimatedPages > 0 ? estimatedPages : 1;

      for (int p = 0; p < actualPages; p++) {
        newList.add(
          PageInfo(
            chapterIndex: i,
            pageIndexInSection: p,
            title: chapter.Title ?? 'Capítulo ${i + 1}',
          ),
        );
      }
    }

    setState(() {
      _virtualPages.clear();
      _virtualPages.addAll(newList);
      _isCalculating = false;
    });

    _restorePosition();
  }

  void _showSimpleSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _toggleBookmark(BuildContext context) {
    final bookId = _bookId;
    if (bookId == null) {
      _showSimpleSnackBar(context, 'Livro não encontrado na biblioteca.');
      return;
    }
    final index = _currentPageIndex;
    final label = 'Página ${index + 1}';
    ref.read(bookmarkServiceProvider).addBookmark(
          bookId: bookId,
          label: label,
          position: index.toString(),
        );
    _showSimpleSnackBar(context, 'Marcador salvo: $label');
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
          final index = int.tryParse(position);
          if (index != null) {
            _pageController.jumpToPage(index);
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

  void _goToPreviousPage() {
    if (_virtualPages.isEmpty) return;
    if (_currentPageIndex <= 0) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _goToNextPage() {
    if (_virtualPages.isEmpty) return;
    if (_currentPageIndex >= _virtualPages.length - 1) return;
    _pageController.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  String _getAskContext() {
    if (_loadedBook == null) return '';
    if (_virtualPages.isEmpty) return '';
    if (_currentPageIndex < 0 || _currentPageIndex >= _virtualPages.length) {
      return '';
    }

    final settings = ref.read(readerSettingsProvider);
    final page = _virtualPages[_currentPageIndex];
    final chapters = _loadedBook!.Chapters ?? const <EpubChapter>[];
    if (page.chapterIndex < 0 || page.chapterIndex >= chapters.length) return '';

    final chapter = chapters[page.chapterIndex];
    final plainText = _getChapterPlainText(
      page.chapterIndex,
      chapter.HtmlContent ?? '',
    );
    if (plainText.trim().isEmpty) return '';

    double charsPerPage = 1200 / (settings.fontSize / 16.0) / settings.zoom;
    if (charsPerPage < 200) charsPerPage = 200;
    final pageSize = charsPerPage.floor();
    final startRaw = page.pageIndexInSection * pageSize;
    final slice = _sliceByWordBoundary(plainText, startRaw, pageSize);
    return slice.isNotEmpty ? slice : plainText;
  }

  void _askBook(BuildContext context) {
    final ctxText = _getAskContext();
    if (ctxText.trim().isEmpty) return;

    String sourceLabel = 'EPUB';
    if (_virtualPages.isNotEmpty &&
        _currentPageIndex >= 0 &&
        _currentPageIndex < _virtualPages.length) {
      final p = _virtualPages[_currentPageIndex];
      sourceLabel = 'Capítulo ${p.chapterIndex + 1}, página ${p.pageIndexInSection + 1}';
    }

    showDialog(
      context: context,
      builder: (ctx) => AskBookDialog(
        title: widget.title,
        contextText: ctxText,
        sourceLabel: sourceLabel,
      ),
    );
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
                  icon: const Icon(Icons.question_answer),
                  onPressed: () => _askBook(context),
                  tooltip: 'Pergunte ao livro',
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
      drawer: _isUiVisible ? _buildDrawer() : null,
      body: Stack(
        children: [
          KeyboardListener(
            focusNode: FocusNode()..requestFocus(),
            onKeyEvent: (event) {
              if (event is KeyDownEvent) {
                if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                  _goToNextPage();
                } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  _goToPreviousPage();
                }
              }
            },
            child: FutureBuilder<EpubBook>(
          future: _epubBookFuture,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final book = snapshot.data!;
              final chapters = book.Chapters ?? [];

              if (chapters.isEmpty) {
                return const Center(child: Text('Livro sem capítulos.'));
              }

              final settings = ref.watch(readerSettingsProvider);

              return LayoutBuilder(
                builder: (context, constraints) {
                  if (_virtualPages.length <= (book.Chapters?.length ?? 0)) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _calculateVirtualPages(
                        book,
                        constraints.maxHeight,
                        settings.fontSize,
                        settings.zoom,
                      );
                    });
                  }

                  return PageView.builder(
                    controller: _pageController,
                    allowImplicitScrolling: true,
                    scrollDirection: settings.isHorizontal
                        ? Axis.horizontal
                        : Axis.vertical,
                    itemCount: _virtualPages.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPageIndex = index;
                      });
                      _saveProgress(index);
                    },
                    itemBuilder: (context, index) {
                      final page = _virtualPages[index];
                      final chapter = chapters[page.chapterIndex];

                      final child = RepaintBoundary(
                        child: _buildPageContent(
                          chapter,
                          page,
                          constraints,
                          settings,
                        ),
                      );

                      if (settings.pageTransition == 'slide') {
                        return child;
                      }

                      return AnimatedBuilder(
                        animation: _pageController,
                        builder: (context, child) {
                          double value = 0.0;
                          if (_pageController.position.haveDimensions) {
                            value = _pageController.page! - index;
                          } else {
                            // First build, no info yet
                            value = (_currentPageIndex - index).toDouble();
                          }

                          if (settings.pageTransition == 'fade') {
                            final opacity = (1 - value.abs()).clamp(0.0, 1.0);
                            return Opacity(opacity: opacity, child: child);
                          } else if (settings.pageTransition == 'none') {
                            // Shows nothing until it's the current page
                            final isVisible = value.abs() < 0.5;
                            return Visibility(
                              visible: isVisible,
                              maintainState: true,
                              child: child!,
                            );
                          } else if (settings.pageTransition == 'stack') {
                            // Stack effect: page slides only when it's the incoming one (value > 0)
                            // or outgoing one (value < 0).
                            // But for a true stack, the bottom page should stay fixed.
                            double translation = 0.0;
                            if (value > 0) {
                              // Page to the right (incoming)
                              translation = value;
                            } else {
                              // Page to the left (current/outgoing) - stays in place but can fade out slightly
                              translation = 0.0;
                            }

                            return Opacity(
                              opacity: (1 - (value.abs() * 0.5)).clamp(
                                0.5,
                                1.0,
                              ),
                              child: FractionalTranslation(
                                translation: settings.isHorizontal
                                    ? Offset(translation, 0)
                                    : Offset(0, translation),
                                child: child!,
                              ),
                            );
                          }

                          return child!;
                        },
                        child: child,
                      );
                    },
                  );
                },
              );
            } else if (snapshot.hasError) {
              return Center(child: Text('Erro: ${snapshot.error}'));
            }
            return const Center(child: CircularProgressIndicator());
          },
          ),
        ),
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (e) {
                _lastPointerDown = e.localPosition;
                _lastPointerDownMs = DateTime.now().millisecondsSinceEpoch;
              },
              onPointerUp: (e) {
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

  Widget _buildPageContent(
    EpubChapter chapter,
    PageInfo page,
    BoxConstraints constraints,
    dynamic settings,
  ) {
    final plainText = _getChapterPlainText(
      page.chapterIndex,
      chapter.HtmlContent ?? '',
    );

    if (plainText.trim().isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'Conteúdo não disponível para este capítulo.',
            style: TextStyle(
              color: _getTextColor(settings.colorMode),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    double charsPerPage = 1200 / (settings.fontSize / 16.0) / settings.zoom;
    if (charsPerPage < 200) charsPerPage = 200;

    final pageSize = charsPerPage.floor();
    final startRaw = page.pageIndexInSection * pageSize;
    final slice = _sliceByWordBoundary(plainText, startRaw, pageSize);

    final contentPadding = EdgeInsets.fromLTRB(
      18,
      _isUiVisible ? 16 : 28,
      18,
      24,
    );

    return Container(
      color: _getBackgroundColor(settings.colorMode),
      alignment: Alignment.topLeft,
      child: SafeArea(
        top: !_isUiVisible,
        bottom: true,
        left: false,
        right: false,
        child: Padding(
          padding: contentPadding,
          child: SelectionArea(
            child: Text(
              slice.isNotEmpty ? slice : plainText,
              style: TextStyle(
                fontSize: settings.fontSize * settings.zoom,
                height: settings.lineHeight,
                color: _getTextColor(settings.colorMode),
                fontFamily: settings.fontFamily,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget? _buildDrawer() {
    if (_loadedBook == null || _loadedBook!.Chapters == null) return null;

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Center(
              child: Text(
                'Sumário',
                style: TextStyle(
                  fontSize: 24,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _loadedBook!.Chapters!.length,
              itemBuilder: (context, index) {
                final chapter = _loadedBook!.Chapters![index];
                return ListTile(
                  title: Text(chapter.Title ?? 'Capítulo ${index + 1}'),
                  selected:
                      _virtualPages.isNotEmpty &&
                      _virtualPages[_currentPageIndex].chapterIndex == index,
                  onTap: () {
                    // Find the first virtual page for this chapter
                    final firstPage = _virtualPages.indexWhere(
                      (p) => p.chapterIndex == index,
                    );
                    if (firstPage != -1) {
                      _pageController.jumpToPage(firstPage);
                    }
                    Navigator.pop(context); // Close drawer
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getBackgroundColor(String mode) {
    switch (mode) {
      case 'sepia':
        return const Color(0xFFF4ECD8);
      case 'paper':
        return const Color(0xFFFAF9F6);
      case 'dark':
        return const Color(0xFF1E1E2A);
      case 'midnight':
        return Colors.black;
      default:
        return Colors.white;
    }
  }

  Color _getTextColor(String mode) {
    switch (mode) {
      case 'sepia':
        return const Color(0xFF5B4636);
      case 'dark':
        return Colors.white70;
      case 'midnight':
        return Colors.white;
      default:
        return Colors.black87;
    }
  }

  void _restorePosition() {
    final libraryState = ref.read(libraryProvider);
    libraryState.whenData((books) {
      try {
        final book = books.firstWhere((b) => b.filePath == widget.filePath);
        _bookId = book.id;
        if (book.lastPosition != null) {
          final index = int.parse(book.lastPosition!);
          _pageController.jumpToPage(index);
        }
      } catch (_) {}
    });

    // Mark as last read
    libraryState.whenData((books) {
      try {
        final book = books.firstWhere((b) => b.filePath == widget.filePath);
        ref.read(readerSettingsProvider.notifier).setLastReadBookId(book.id);
      } catch (_) {}
    });
  }

  void _saveProgress(int index) {
    if (_virtualPages.isEmpty) return;
    final progress = index / (_virtualPages.length - 1);

    final libraryState = ref.read(libraryProvider);
    libraryState.whenData((books) {
      try {
        final book = books.firstWhere((b) => b.filePath == widget.filePath);
        ref
            .read(libraryProvider.notifier)
            .updateBookPosition(book.id, index.toString(), progress);
      } catch (_) {}
    });
  }
}
