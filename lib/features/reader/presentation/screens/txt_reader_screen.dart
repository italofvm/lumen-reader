import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen_reader/features/library/presentation/providers/library_providers.dart';
import 'package:lumen_reader/features/settings/domain/providers/settings_providers.dart';
import 'package:lumen_reader/features/reader/services/providers.dart';
import 'package:lumen_reader/features/reader/presentation/widgets/bookmarks_sheet.dart';

import '../widgets/reader_settings_sheet.dart';

class TxtReaderScreen extends ConsumerStatefulWidget {
  final String title;
  final String filePath;
  final Uint8List? fileBytes;

  const TxtReaderScreen({
    super.key,
    required this.title,
    required this.filePath,
    this.fileBytes,
  });

  @override
  ConsumerState<TxtReaderScreen> createState() => _TxtReaderScreenState();
}

class _TxtReaderScreenState extends ConsumerState<TxtReaderScreen> {
  final ScrollController _scrollController = ScrollController();
  String? _content;
  bool _restored = false;
  Timer? _saveDebounce;
  bool _isUiVisible = true;
  String? _bookId;

  Offset? _lastPointerDown;
  int? _lastPointerDownMs;

  Future<void> _pageScrollBy(double delta) async {
    if (!_scrollController.hasClients) return;
    final target = (_scrollController.offset + delta).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    await _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(_onScroll);
  }

  void _toggleFocusMode() {
    setState(() {
      _isUiVisible = !_isUiVisible;
    });
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final bytes = widget.fileBytes ?? await File(widget.filePath).readAsBytes();
      final text = utf8.decode(bytes, allowMalformed: true);
      if (!mounted) return;
      setState(() {
        _content = text;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _restorePosition();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _content = '';
      });
      _showSnackBar('Erro ao abrir TXT: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _onScroll() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 450), () {
      _saveProgress();
    });
  }

  void _restorePosition() {
    if (_restored) return;
    final libraryState = ref.read(libraryProvider);
    libraryState.whenData((books) {
      try {
        final book = books.firstWhere((b) => b.filePath == widget.filePath);
        _bookId = book.id;
        ref.read(readerSettingsProvider.notifier).setLastReadBookId(book.id);

        if (book.lastPosition != null) {
          final offset = double.tryParse(book.lastPosition!);
          if (offset != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                _scrollController.jumpTo(offset.clamp(
                  0,
                  _scrollController.position.maxScrollExtent,
                ));
              }
            });
          }
        }
      } catch (_) {}

      _restored = true;
    });
  }

  void _toggleBookmark(BuildContext context) {
    final bookId = _bookId;
    if (bookId == null) {
      _showSnackBar('Livro não encontrado na biblioteca.');
      return;
    }
    final offset = _scrollController.hasClients ? _scrollController.offset : 0.0;
    final label = 'Posição ${offset.toStringAsFixed(0)}';
    ref.read(bookmarkServiceProvider).addBookmark(
          bookId: bookId,
          label: label,
          position: offset.toStringAsFixed(2),
        );
    _showSnackBar('Marcador salvo: $label');
  }

  void _openBookmarks(BuildContext context) {
    final bookId = _bookId;
    if (bookId == null) {
      _showSnackBar('Livro não encontrado na biblioteca.');
      return;
    }
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => BookmarksSheet(
        bookId: bookId,
        title: widget.title,
        onSelect: (position) {
          final offset = double.tryParse(position);
          if (offset != null && _scrollController.hasClients) {
            _scrollController.jumpTo(
              offset.clamp(0, _scrollController.position.maxScrollExtent),
            );
          }
        },
      ),
    );
  }

  void _saveProgress() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final offset = _scrollController.offset;

    final progress = max <= 0 ? 0.0 : (offset / max).clamp(0.0, 1.0);

    final libraryState = ref.read(libraryProvider);
    libraryState.whenData((books) {
      try {
        final book = books.firstWhere((b) => b.filePath == widget.filePath);
        ref
            .read(libraryProvider.notifier)
            .updateBookPosition(book.id, offset.toStringAsFixed(2), progress);
      } catch (_) {}
    });
  }

  Color _bg(String colorMode) {
    switch (colorMode) {
      case 'sepia':
        return const Color(0xFFF4ECD8);
      case 'paper':
        return const Color(0xFFFAF9F6);
      case 'dark':
        return const Color(0xFF121212);
      case 'midnight':
        return Colors.black;
      default:
        return Colors.white;
    }
  }

  Color _fg(String colorMode) {
    switch (colorMode) {
      case 'dark':
      case 'midnight':
        return Colors.white.withOpacity(0.92);
      default:
        return const Color(0xFF1E1E2A);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(readerSettingsProvider);

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
                ),
                IconButton(
                  icon: const Icon(Icons.bookmark_border),
                  onPressed: () => _toggleBookmark(context),
                  onLongPress: () => _openBookmarks(context),
                ),
              ],
            )
          : null,
      body: Stack(
        children: [
          _content == null
              ? const Center(child: CircularProgressIndicator())
              : Container(
                  color: _bg(settings.colorMode),
                  child: SelectionArea(
                    child: Scrollbar(
                      controller: _scrollController,
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                        child: Text(
                          _content!,
                          style: TextStyle(
                            fontSize: settings.fontSize * settings.zoom,
                            height: settings.lineHeight,
                            color: _fg(settings.colorMode),
                            fontFamily: settings.fontFamily,
                          ),
                        ),
                      ),
                    ),
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

                final viewport = _scrollController.hasClients
                    ? _scrollController.position.viewportDimension
                    : MediaQuery.of(context).size.height;

                if (ratio <= 0.20) {
                  _pageScrollBy(-viewport * 0.92);
                  return;
                }
                if (ratio >= 0.80) {
                  _pageScrollBy(viewport * 0.92);
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
}
