import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen_reader/features/library/domain/entities/book.dart';
import 'package:lumen_reader/features/settings/domain/providers/settings_providers.dart';

class BookListTile extends ConsumerWidget {
  final Book book;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const BookListTile({
    super.key,
    required this.book,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(readerSettingsProvider);

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: SizedBox(
        width: 50,
        height: 70,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((0.1 * 255).round()),
                    blurRadius: 4,
                    offset: const Offset(1, 1),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: book.coverPath != null
                  ? Image.file(
                      File(book.coverPath!),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Icon(
                            book.type == BookType.pdf
                                ? Icons.picture_as_pdf
                                : Icons.menu_book,
                            color: Theme.of(context).primaryColor,
                            size: 24,
                          ),
                        );
                      },
                    )
                  : Center(
                      child: Icon(
                        book.type == BookType.pdf
                            ? Icons.picture_as_pdf
                            : Icons.menu_book,
                        color: Theme.of(context).primaryColor,
                        size: 24,
                      ),
                    ),
            ),
          ],
        ),
      ),
      title: Text(
        book.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            book.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          if (settings.showProgress) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: book.progress,
                      backgroundColor: Colors.grey[200],
                      color: Theme.of(context).primaryColor,
                      minHeight: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(book.progress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
        onPressed: onDelete,
      ),
    );
  }
}
