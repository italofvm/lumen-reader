import 'package:flutter/material.dart';
import 'package:epubx/epubx.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen_reader/features/settings/domain/providers/settings_providers.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lumen_reader/features/library/presentation/providers/library_providers.dart';
import '../widgets/reader_settings_sheet.dart';
import 'package:lumen_reader/features/reader/services/providers.dart';
import 'package:lumen_reader/features/reader/presentation/widgets/bookmarks_sheet.dart';
import 'package:lumen_reader/features/reader/presentation/widgets/reader_search_sheet.dart';
import 'package:lumen_reader/features/reader/presentation/widgets/ask_book_dialog.dart';
import 'package:lumen_reader/features/reader/presentation/widgets/ai_explanation_dialog.dart';
import 'package:lumen_reader/features/reader/presentation/widgets/ai_summary_dialog.dart';
import 'package:flutter_html/flutter_html.dart';

import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:path/path.dart' as p;

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

class _EpubFooter extends StatelessWidget {
  final int currentIndex;
  final int total;
  final String colorMode;
  final double maxWidth;

  const _EpubFooter({
    required this.currentIndex,
    required this.total,
    required this.colorMode,
    required this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final safeTotal = total <= 0 ? 1 : total;
    final page = (currentIndex + 1).clamp(1, safeTotal);
    final pct = ((page / safeTotal) * 100).clamp(0, 100).round();

    final isDark = colorMode == 'dark' || colorMode == 'midnight';
    final fg = isDark ? Colors.white70 : Colors.black54;
    final bg = isDark
        ? const Color(0xFF000000).withAlpha(120)
        : const Color(0xFFFFFFFF).withAlpha(160);

    return IgnorePointer(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$page/$safeTotal',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$pct%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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

class _EpubChapterView {
  final String title;
  final String html;
  final String? contentFileName;

  const _EpubChapterView({
    required this.title,
    required this.html,
    required this.contentFileName,
  });
}

class _EpubReaderScreenState extends ConsumerState<EpubReaderScreen> {
  Future<EpubBook>? _epubBookFuture;
  final PageController _pageController = PageController();
  final List<PageInfo> _virtualPages = [];
  int _currentPageIndex = 0;
  EpubBook? _loadedBook;
  List<_EpubChapterView> _chapterViews = const [];
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
    final chapters = _chapterViews;
    final hits = <ReaderSearchHit>[];

    // Keep consistent with pagination heuristic in _calculateVirtualPages.
    double charsPerPage = 1200 / (settings.fontSize / 16.0) / settings.zoom;
    if (charsPerPage < 200) charsPerPage = 200;

    for (int i = 0; i < chapters.length; i++) {
      final chapter = chapters[i];
      final html = _getSanitizedChapterHtml(i, chapter.html);
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
          title: chapter.title,
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
    out = out.replaceAll(RegExp(r'\[(\d{1,3})\]'), '');
    out = out.replaceAll(
      RegExp(r'<\s*sup\b[^>]*>[\s\S]*?<\s*/\s*sup\s*>', caseSensitive: false),
      '',
    );
    out = out.replaceAll(RegExp(r'\bdLivros\b', caseSensitive: false), '');

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

    String decoded = withBreaks
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");

    decoded = decoded.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
      final code = int.tryParse(m.group(1) ?? '');
      if (code == null) return '';
      return String.fromCharCode(code);
    });

    decoded = decoded.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
      final code = int.tryParse(m.group(1) ?? '', radix: 16);
      if (code == null) return '';
      return String.fromCharCode(code);
    });

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
        .replaceAll(RegExp(r'\[(\d{1,3})\]'), '')
        .replaceAll(RegExp(r'\bdLivros\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'^\s*\d{1,4}\s*$', multiLine: true), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
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
    out = out.replaceFirst(RegExp(r'^[\s\n]+'), '');
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
      _chapterViews = _buildChapterViews(book);
      _sanitizedChapterHtml.clear();
      _chapterPlainText.clear();
    });
    // Initial calculation (rough estimate before we have screen size)
    _initialCalculatePages(book);
    return book;
  }

  List<_EpubChapterView> _flattenChapters(
    EpubBook book,
    List<EpubChapter> chapters, {
    String? parentTitle,
  }) {
    final out = <_EpubChapterView>[];

    for (int i = 0; i < chapters.length; i++) {
      final ch = chapters[i];
      final rawTitle = (ch.Title ?? '').trim();
      final baseTitle = rawTitle.isNotEmpty
          ? rawTitle
          : (parentTitle ?? 'Capítulo ${i + 1}');

      final title = (parentTitle != null && rawTitle.isNotEmpty && parentTitle.trim().isNotEmpty)
          ? '${parentTitle.trim()} · ${rawTitle.trim()}'
          : baseTitle;

      final html = _extractChapterHtml(book, ch);
      final hasHtml = html.trim().isNotEmpty;
      final contentFileName = (ch.ContentFileName ?? '').trim().isNotEmpty
          ? ch.ContentFileName!.trim()
          : null;

      final subs = ch.SubChapters;
      final hasSubChapters = subs != null && subs.isNotEmpty;

      if (hasSubChapters) {
        out.addAll(_flattenChapters(book, subs, parentTitle: title));
        continue;
      }
      if (hasHtml) {
        out.add(
          _EpubChapterView(
            title: title,
            html: _inlineImagesInHtml(book, html, contentFileName: contentFileName),
            contentFileName: contentFileName,
          ),
        );
      }
    }

    return out;
  }

  List<_EpubChapterView> _buildChapterViews(EpubBook book) {
    final chapters = book.Chapters ?? const <EpubChapter>[];
    if (chapters.isNotEmpty) {
      final flattened = _flattenChapters(book, chapters);
      if (flattened.isNotEmpty) return flattened;

      // Fallback: still show top-level nodes if flattening produced nothing.
      return List.generate(chapters.length, (i) {
        final ch = chapters[i];
        final html = _extractChapterHtml(book, ch);
        final contentFileName = (ch.ContentFileName ?? '').trim().isNotEmpty
            ? ch.ContentFileName!.trim()
            : null;
        final title = (ch.Title?.trim().isNotEmpty ?? false)
            ? ch.Title!.trim()
            : 'Capítulo ${i + 1}';
        return _EpubChapterView(
          title: title,
          html: _inlineImagesInHtml(book, html, contentFileName: contentFileName),
          contentFileName: contentFileName,
        );
      });
    }

    final dynamic content = book.Content;
    final dynamic htmlMapDyn = content?.Html;
    if (htmlMapDyn is Map) {
      final entries = htmlMapDyn.entries
          .where((e) => e.value is String)
          .map((e) => MapEntry(e.key.toString(), e.value as String))
          .where((e) => e.value.trim().isNotEmpty)
          .toList()
        ..sort((a, b) => a.key.compareTo(b.key));

      if (entries.isNotEmpty) {
        return List.generate(entries.length, (i) {
          final key = entries[i].key;
          final title = key.split('/').last;
          return _EpubChapterView(
            title: title,
            html: _inlineImagesInHtml(book, entries[i].value, contentFileName: key),
            contentFileName: key,
          );
        });
      }
    }

    return const [];
  }

  String _extractChapterHtml(EpubBook book, EpubChapter chapter) {
    final direct = chapter.HtmlContent;
    if (direct != null && direct.trim().isNotEmpty) return direct;

    // Try to resolve by file name (EPUB3 often stores content in Content.Html map).
    final fileName = (chapter.ContentFileName ?? '').trim();
    if (fileName.isNotEmpty) {
      final dynamic content = book.Content;
      final dynamic htmlMapDyn = content?.Html;
      if (htmlMapDyn is Map) {
        String? pickByKey(Object? key) {
          if (key == null) return null;
          final v = htmlMapDyn[key];
          if (v is String && v.trim().isNotEmpty) return v;
          return null;
        }

        final exact = pickByKey(fileName);
        if (exact != null) return exact;

        final normalized = fileName.replaceAll('\\', '/').replaceFirst('./', '');
        final exactNorm = pickByKey(normalized);
        if (exactNorm != null) return exactNorm;

        // Some EPUBs store paths like "Text/ch001.xhtml" while ContentFileName is just "ch001.xhtml".
        final base = normalized.split('/').last;
        for (final entry in htmlMapDyn.entries) {
          final k = entry.key?.toString() ?? '';
          if (k == normalized || k.endsWith('/$normalized')) {
            final v = entry.value;
            if (v is String && v.trim().isNotEmpty) return v;
          }
        }
        for (final entry in htmlMapDyn.entries) {
          final k = entry.key?.toString() ?? '';
          if (k.isNotEmpty && (k == base || k.endsWith('/$base'))) {
            final v = entry.value;
            if (v is String && v.trim().isNotEmpty) return v;
          }
        }
      }
    }

    return '';
  }

  String _inlineImagesInHtml(
    EpubBook book,
    String html, {
    required String? contentFileName,
  }) {
    final out = html;
    if (out.trim().isEmpty) return out;

    final dynamic content = book.Content;
    final Map? images = content?.Images is Map ? content!.Images as Map : null;
    final Map? allFiles = content?.AllFiles is Map ? content!.AllFiles as Map : null;
    if (images == null && allFiles == null) return out;

    String normalizeKey(String key) {
      var k = key.replaceAll('\\', '/');
      k = Uri.decodeFull(k);
      while (k.startsWith('./')) {
        k = k.substring(2);
      }
      return p.posix.normalize(k);
    }

    String? baseDir;
    if (contentFileName != null && contentFileName.trim().isNotEmpty) {
      final normalized = normalizeKey(contentFileName);
      final dir = p.posix.dirname(normalized);
      baseDir = dir == '.' ? '' : dir;
    }

    List<int>? getBytesForHref(String href) {
      final normalizedHref = normalizeKey(href);
      final candidates = <String>{
        normalizedHref,
        href,
        Uri.decodeFull(href),
      };
      if (baseDir != null && baseDir.isNotEmpty) {
        candidates.add(p.posix.normalize(p.posix.join(baseDir, normalizedHref)));
        candidates.add(p.posix.normalize(p.posix.join(baseDir, href)));
      }

      // Some epubs store resources under folders and references may omit them.
      final basename = p.posix.basename(normalizedHref);
      candidates.add(basename);

      dynamic pick(Map? map, String key) {
        if (map == null) return null;
        return map[key];
      }

      for (final c in candidates) {
        final key = normalizeKey(c);
        final vImg = pick(images, key) ?? pick(images, c);
        if (vImg != null) {
          final bytes = (vImg as dynamic).Content;
          if (bytes is List<int> && bytes.isNotEmpty) return bytes;
        }
        final vAll = pick(allFiles, key) ?? pick(allFiles, c);
        if (vAll != null) {
          final bytes = (vAll as dynamic).Content;
          if (bytes is List<int> && bytes.isNotEmpty) return bytes;
        }
      }

      // Last resort: scan by endsWith.
      if (images != null) {
        for (final entry in images.entries) {
          final k = entry.key?.toString() ?? '';
          if (k.isEmpty) continue;
          final nk = normalizeKey(k);
          if (nk == normalizedHref || nk.endsWith('/$normalizedHref') || nk.endsWith('/$basename')) {
            final bytes = (entry.value as dynamic).Content;
            if (bytes is List<int> && bytes.isNotEmpty) return bytes;
          }
        }
      }
      if (allFiles != null) {
        for (final entry in allFiles.entries) {
          final k = entry.key?.toString() ?? '';
          if (k.isEmpty) continue;
          final nk = normalizeKey(k);
          if (nk == normalizedHref || nk.endsWith('/$normalizedHref') || nk.endsWith('/$basename')) {
            final bytes = (entry.value as dynamic).Content;
            if (bytes is List<int> && bytes.isNotEmpty) return bytes;
          }
        }
      }
      return null;
    }

    String mimeFromPath(String path) {
      final ext = p.extension(path).toLowerCase();
      switch (ext) {
        case '.jpg':
        case '.jpeg':
          return 'image/jpeg';
        case '.png':
          return 'image/png';
        case '.gif':
          return 'image/gif';
        case '.svg':
        case '.svgz':
          return 'image/svg+xml';
        case '.bmp':
          return 'image/bmp';
        case '.webp':
          return 'image/webp';
        default:
          return 'application/octet-stream';
      }
    }

    // Replace <img ... src="..."> and <image ... href="..."> (SVG use-case)
    final pattern = RegExp(
      r'(<(img|image)\b[^>]*?\s(?:src|href)=)(["\"])(.*?)(\3)',
      caseSensitive: false,
    );

    return out.replaceAllMapped(pattern, (m) {
      final prefix = m.group(1) ?? '';
      final quote = m.group(3) ?? '"';
      final raw = (m.group(4) ?? '').trim();
      if (raw.isEmpty) return m.group(0) ?? '';

      final src = raw.split('#').first;
      if (src.startsWith('data:') || src.startsWith('http://') || src.startsWith('https://')) {
        return m.group(0) ?? '';
      }

      final bytes = getBytesForHref(src);
      if (bytes == null || bytes.isEmpty) {
        return m.group(0) ?? '';
      }

      final mime = mimeFromPath(src);
      final b64 = base64Encode(bytes);
      final dataUri = 'data:$mime;base64,$b64';
      return '$prefix$quote$dataUri$quote';
    });
  }

  void _initialCalculatePages(EpubBook book) {
    if (_chapterViews.isEmpty) return;
    _virtualPages.clear();
    for (int i = 0; i < _chapterViews.length; i++) {
      final chapter = _chapterViews[i];
      // Rough estimate: 1 page per chapter until we measure properly
      _virtualPages.add(
        PageInfo(
          chapterIndex: i,
          pageIndexInSection: 0,
          title: chapter.title,
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

    final chapters = _chapterViews;
    final newList = <PageInfo>[];

    // For now, let's use a more granular estimate while we don't have a reliable height-based splitter.
    // Real pagination requires rendering. For "Moon+ Reader" feel,
    // we ideally want to know how many "screens" are in a chapter.

    // Improved Estimate:
    // Roughly 800-1200 characters per "page" depending on font size.
    for (int i = 0; i < chapters.length; i++) {
      final chapter = chapters[i];
      final plainText = _getChapterPlainText(i, chapter.html);
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
            title: chapter.title,
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
    final chapters = _chapterViews;
    if (page.chapterIndex < 0 || page.chapterIndex >= chapters.length) return '';

    final chapter = chapters[page.chapterIndex];
    final plainText = _getChapterPlainText(
      page.chapterIndex,
      chapter.html,
    );
    if (plainText.trim().isEmpty) return '';

    double charsPerPage = 1200 / (settings.fontSize / 16.0) / settings.zoom;
    if (charsPerPage < 200) charsPerPage = 200;
    final pageSize = charsPerPage.floor();
    final startRaw = page.pageIndexInSection * pageSize;
    final slice = _sliceByWordBoundary(plainText, startRaw, pageSize);
    return slice.isNotEmpty ? slice : plainText;
  }

  void _summarizeCurrent(BuildContext context) {
    final ctxText = _getAskContext();
    if (ctxText.trim().isEmpty) {
      _showSimpleSnackBar(
        context,
        'Não foi possível obter texto desta página. Tente virar a página ou aguarde o carregamento do capítulo.',
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AISummaryDialog(
        title: widget.title,
        content: ctxText,
      ),
    );
  }

  void _explainCurrent(BuildContext context) {
    final ctxText = _getAskContext();
    if (ctxText.trim().isEmpty) {
      _showSimpleSnackBar(
        context,
        'Não foi possível obter texto desta página. Tente virar a página ou aguarde o carregamento do capítulo.',
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AIExplanationDialog(selectedText: ctxText),
    );
  }

  Future<void> _promptTranslateOrDefine(BuildContext context) async {
    final controller = TextEditingController();
    final term = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Traduzir / Definir'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Palavra ou frase',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );

    controller.dispose();
    final t = term?.trim() ?? '';
    if (!context.mounted) return;
    if (t.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AISummaryDialog(
        title: 'Traduzir/Definir',
        content:
            'Traduza para português (se necessário) e explique de forma simples, com exemplos de uso, o texto: "$t"',
      ),
    );
  }

  void _askBook(BuildContext context) {
    final ctxText = _getAskContext();
    if (ctxText.trim().isEmpty) {
      _showSimpleSnackBar(
        context,
        'Não foi possível obter texto desta página. Tente virar a página ou aguarde o carregamento do capítulo.',
      );
      return;
    }

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
                  icon: const Icon(Icons.summarize),
                  onPressed: () => _summarizeCurrent(context),
                  tooltip: 'Resumir trecho',
                ),
                IconButton(
                  icon: const Icon(Icons.psychology),
                  onPressed: () => _explainCurrent(context),
                  tooltip: 'Explicar trecho',
                ),
                IconButton(
                  icon: const Icon(Icons.translate),
                  onPressed: () => _promptTranslateOrDefine(context),
                  tooltip: 'Traduzir/Definir',
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
              final chapters = _chapterViews;

              if (chapters.isEmpty) {
                return const Center(child: Text('Livro sem capítulos.'));
              }

              final settings = ref.watch(readerSettingsProvider);

              return LayoutBuilder(
                builder: (context, constraints) {
                  if (_virtualPages.length <= _chapterViews.length) {
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
    _EpubChapterView chapter,
    PageInfo page,
    BoxConstraints constraints,
    dynamic settings,
  ) {
    final plainText = _getChapterPlainText(
      page.chapterIndex,
      chapter.html,
    );

    final bgColor = _getBackgroundColor(settings.colorMode);
    final textColor = _getTextColor(settings.colorMode);
    final isPaperLike = settings.colorMode == 'paper' || settings.colorMode == 'sepia';
    final maxWidth = isPaperLike ? 560.0 : double.infinity;

    final sanitizedHtml = _getSanitizedChapterHtml(page.chapterIndex, chapter.html);
    final shouldFallbackToHtml = plainText.trim().length < 80 &&
        sanitizedHtml.trim().isNotEmpty;

    if (plainText.trim().isEmpty || shouldFallbackToHtml) {
      if (sanitizedHtml.trim().isNotEmpty) {
        final htmlData = sanitizedHtml.contains('<html')
            ? sanitizedHtml
            : '<div>$sanitizedHtml</div>';
        final body = Container(
          color: bgColor,
          alignment: Alignment.topCenter,
          child: SafeArea(
            top: !_isUiVisible,
            bottom: true,
            left: false,
            right: false,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    isPaperLike ? 26 : 18,
                    _isUiVisible ? 16 : 28,
                    isPaperLike ? 26 : 18,
                    52,
                  ),
                  child: Html(
                    data: htmlData,
                    style: {
                      'body': Style(
                        margin: Margins.zero,
                        padding: HtmlPaddings.zero,
                        fontSize: FontSize(settings.fontSize * settings.zoom),
                        lineHeight: LineHeight(settings.lineHeight),
                        textAlign: TextAlign.justify,
                        color: textColor,
                        fontFamily: settings.fontFamily,
                        backgroundColor: bgColor,
                      ),
                      '*': Style(
                        textAlign: TextAlign.justify,
                        color: textColor,
                        fontFamily: settings.fontFamily,
                      ),
                    },
                  ),
                ),
              ),
            ),
          ),
        );

        return Stack(
          children: [
            body,
            if (_virtualPages.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 8,
                child: _EpubFooter(
                  currentIndex: _currentPageIndex,
                  total: _virtualPages.length,
                  colorMode: settings.colorMode,
                  maxWidth: maxWidth,
                ),
              ),
          ],
        );
      }

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'Não foi possível renderizar este trecho do EPUB.\nTente abrir outra parte do livro.',
            style: TextStyle(
              color: textColor,
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
      isPaperLike ? 26 : 18,
      _isUiVisible ? 16 : 28,
      isPaperLike ? 26 : 18,
      52,
    );

    final pageText = _cleanPageText(slice.isNotEmpty ? slice : plainText);

    final body = Container(
      color: bgColor,
      alignment: Alignment.topCenter,
      child: SafeArea(
        top: !_isUiVisible,
        bottom: true,
        left: false,
        right: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SingleChildScrollView(
              padding: contentPadding,
              child: SelectionArea(
                child: _buildBookText(
                  pageText,
                  settings,
                  textColor,
                  isPaperLike,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return Stack(
      children: [
        body,
        if (_virtualPages.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: 8,
            child: _EpubFooter(
              currentIndex: _currentPageIndex,
              total: _virtualPages.length,
              colorMode: settings.colorMode,
              maxWidth: maxWidth,
            ),
          ),
      ],
    );
  }

  Widget? _buildDrawer() {
    if (_loadedBook == null || _chapterViews.isEmpty) return null;

    return Drawer(
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Sumário',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _chapterViews.length,
              itemBuilder: (context, index) {
                final chapter = _chapterViews[index];
                final selected = _virtualPages.isNotEmpty &&
                    _virtualPages[_currentPageIndex].chapterIndex == index;
                return ListTile(
                  dense: true,
                  selected: selected,
                  selectedTileColor:
                      Theme.of(context).colorScheme.primary.withAlpha(18),
                  title: Text(
                    chapter.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
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

  TextStyle _readerTextStyle(ReaderSettingsState settings) {
    final family = settings.fontFamily.trim().isEmpty
        ? 'Merriweather'
        : settings.fontFamily.trim();
    try {
      return GoogleFonts.getFont(
        family,
        fontSize: settings.fontSize * settings.zoom,
        height: settings.lineHeight,
        color: _getTextColor(settings.colorMode),
      );
    } catch (_) {
      return TextStyle(
        fontSize: settings.fontSize * settings.zoom,
        height: settings.lineHeight,
        color: _getTextColor(settings.colorMode),
        fontFamily: family,
      );
    }
  }

  String _cleanPageText(String text) {
    var t = text;

    t = t
        .replaceAll(RegExp(r'\[(\d{1,3})\]'), '')
        .replaceAll(RegExp(r'\b\w+_epub\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bdLivros\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'^\s*\d{1,4}\s*$', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*[•–—-]\s*$', multiLine: true), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    return t;
  }

  bool _isQuoteParagraph(String p) {
    final t = p.trimLeft();
    if (t.isEmpty) return false;
    if (t.startsWith('“') || t.startsWith('"') || t.startsWith('\'')) {
      return true;
    }
    if (t.startsWith('—') || t.startsWith('–')) return true;
    return false;
  }

  Widget _buildBookText(
    String text,
    ReaderSettingsState settings,
    Color textColor,
    bool isPaperLike,
  ) {
    final style = _readerTextStyle(settings).copyWith(color: textColor);
    TextStyle quoteStyle;
    try {
      quoteStyle = GoogleFonts.getFont(
        'Lora',
        fontSize: style.fontSize,
        height: style.height,
        color: style.color,
        fontStyle: FontStyle.italic,
      );
    } catch (_) {
      quoteStyle = style.copyWith(
        fontStyle: FontStyle.italic,
        fontFamily: 'serif',
      );
    }
    final indent = isPaperLike ? '\u2003\u2003' : '\u2003';

    final rawParas = text
        .replaceAll('\r', '')
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((p) => p.isNotEmpty)
        .toList(growable: false);

    if (rawParas.isEmpty) {
      return Text(
        'Sem conteúdo para exibir.',
        style: style,
        textAlign: TextAlign.justify,
      );
    }

    final quoteBg = isPaperLike
        ? const Color(0xFF000000).withAlpha(14)
        : Colors.white.withAlpha(10);
    final quoteBorder = isPaperLike
        ? const Color(0xFF000000).withAlpha(30)
        : Colors.white.withAlpha(30);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < rawParas.length; i++) ...[
          if (_isQuoteParagraph(rawParas[i]))
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: quoteBg,
                borderRadius: BorderRadius.circular(12),
                border: Border(
                  left: BorderSide(color: quoteBorder, width: 3),
                ),
              ),
              child: SelectableText(
                rawParas[i],
                style: quoteStyle,
                textAlign: TextAlign.justify,
              ),
            )
          else
            SelectableText(
              '${i == 0 ? '' : indent}${rawParas[i]}',
              style: style,
              textAlign: TextAlign.justify,
            ),
          const SizedBox(height: 10),
        ],
      ],
    );
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
