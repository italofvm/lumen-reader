import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen_reader/features/library/domain/entities/book.dart';
import 'package:lumen_reader/features/settings/domain/providers/settings_providers.dart';

class BookCover extends StatelessWidget {
  final Book book;
  final double width;
  final double height;

  const BookCover({
    super.key,
    required this.book,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(12);

    Widget placeholder() {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary.withAlpha((0.85 * 255).round()),
              Theme.of(context).colorScheme.tertiary.withAlpha((0.65 * 255).round()),
            ],
          ),
        ),
        child: Center(
          child: Icon(
            book.type == BookType.pdf
                ? Icons.picture_as_pdf_rounded
                : Icons.menu_book_rounded,
            color: Colors.white.withAlpha((0.92 * 255).round()),
            size: 34,
          ),
        ),
      );
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1B1F) : const Color(0xFFF2F3F7),
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(((isDark ? 0.35 : 0.12) * 255).round()),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: book.coverPath != null
          ? Image.file(
              File(book.coverPath!),
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              errorBuilder: (context, error, stackTrace) => placeholder(),
            )
          : placeholder(),
    );
  }
}

class BookCard extends ConsumerStatefulWidget {
  final Book book;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const BookCard({
    super.key,
    required this.book,
    required this.onDelete,
    required this.onTap,
  });

  @override
  ConsumerState<BookCard> createState() => _BookCardState();
}

class _BookCardState extends ConsumerState<BookCard> {
  bool _showDelete = false;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(readerSettingsProvider);
    final isWoodShelf = ref.watch(readerSettingsProvider).isWoodShelf;

    final glassBg = isWoodShelf
        ? Colors.black.withAlpha((0.44 * 255).round())
        : Colors.white.withAlpha((0.18 * 255).round());
    final glassBorder = isWoodShelf
        ? Colors.white.withAlpha((0.10 * 255).round())
        : Colors.white.withAlpha((0.18 * 255).round());

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E1E2A);
    final secondaryColor = isDark
        ? Colors.white.withAlpha((0.70 * 255).round())
        : const Color(0xFF6B6B7A);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onLongPress: () {
          setState(() {
            _showDelete = !_showDelete;
          });
        },
        onTap: () {
          if (_showDelete) {
            setState(() {
              _showDelete = false;
            });
            return;
          }
          widget.onTap();
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: BookCover(
                          book: widget.book,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                      if (isWoodShelf) ...[
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withAlpha((0.14 * 255).round()),
                                    Colors.black.withAlpha((0.60 * 255).round()),
                                  ],
                                  stops: const [0.55, 0.75, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 10,
                          right: 10,
                          bottom: 10,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: BackdropFilter(
                              filter: ui.ImageFilter.blur(
                                sigmaX: 14,
                                sigmaY: 14,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: glassBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: glassBorder,
                                    width: 0.7,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      widget.book.title,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.12,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black.withAlpha((0.45 * 255).round()),
                                            blurRadius: 12,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.book.author,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 11,
                                        height: 1.1,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withAlpha((0.82 * 255).round()),
                                        shadows: [
                                          Shadow(
                                            color: Colors.black.withAlpha((0.35 * 255).round()),
                                            blurRadius: 10,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (settings.showProgress) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                999,
                                              ),
                                              child: LinearProgressIndicator(
                                                value: widget.book.progress,
                                                backgroundColor: Colors.white
                                                    .withAlpha((0.18 * 255).round()),
                                                valueColor:
                                                    const AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                                minHeight: 3,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            '${(widget.book.progress * 100).toInt()}%',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        if (settings.showProgress)
                          Positioned(
                            left: 10,
                            bottom: 10,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: BackdropFilter(
                                filter: ui.ImageFilter.blur(
                                  sigmaX: 10,
                                  sigmaY: 10,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.black.withAlpha((0.35 * 255).round())
                                        : Colors.white.withAlpha((0.70 * 255).round()),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.white.withAlpha((0.10 * 255).round())
                                          : Colors.black.withAlpha((0.06 * 255).round()),
                                    ),
                                  ),
                                  child: Text(
                                    '${(widget.book.progress * 100).toInt()}%',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF1E1E2A),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                if (!isWoodShelf) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                    child: Text(
                      widget.book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                    child: Text(
                      widget.book.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.1,
                        fontWeight: FontWeight.w600,
                        color: secondaryColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Positioned(
              right: 6,
              top: 6,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: _showDelete
                    ? IconButton(
                        key: const ValueKey('delete'),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 34,
                          minHeight: 34,
                        ),
                        icon: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.red.withAlpha((0.92 * 255).round()),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha((0.20 * 255).round()),
                                blurRadius: 10,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                        onPressed: widget.onDelete,
                      )
                    : const SizedBox(
                        key: ValueKey('empty'),
                        width: 34,
                        height: 34,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
