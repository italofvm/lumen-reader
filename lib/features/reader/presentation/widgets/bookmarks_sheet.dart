import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen_reader/features/reader/services/bookmark_service.dart';
import 'package:lumen_reader/features/reader/services/providers.dart';

class BookmarksSheet extends ConsumerStatefulWidget {
  final String bookId;
  final String title;
  final void Function(String position) onSelect;

  const BookmarksSheet({
    super.key,
    required this.bookId,
    required this.title,
    required this.onSelect,
  });

  @override
  ConsumerState<BookmarksSheet> createState() => _BookmarksSheetState();
}

class _BookmarksSheetState extends ConsumerState<BookmarksSheet> {
  late Future<List<ReaderBookmark>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(bookmarkServiceProvider).listBookmarks(widget.bookId);
  }

  void _refresh() {
    setState(() {
      _future = ref.read(bookmarkServiceProvider).listBookmarks(widget.bookId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(bookmarkServiceProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Marcadores',
                    style: Theme.of(context).textTheme.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text(
              widget.title,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<ReaderBookmark>>(
              future: _future,
              builder: (context, snapshot) {
                final bookmarks = snapshot.data ?? const <ReaderBookmark>[];

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (bookmarks.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'Nenhum marcador salvo ainda.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ),
                  );
                }

                return Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: bookmarks.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final b = bookmarks[index];
                      return ListTile(
                        title: Text(b.label),
                        subtitle: Text(
                          'Salvo em ${b.createdAt.toLocal()}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          widget.onSelect(b.position);
                        },
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            await service.removeBookmark(
                              bookId: widget.bookId,
                              bookmarkId: b.id,
                            );
                            _refresh();
                          },
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
