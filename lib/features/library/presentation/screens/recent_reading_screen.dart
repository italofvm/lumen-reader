import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen_reader/features/library/domain/entities/book.dart';
import 'package:lumen_reader/features/library/presentation/providers/library_providers.dart';
import 'package:lumen_reader/features/library/presentation/widgets/book_card.dart';
import 'package:lumen_reader/features/reader/presentation/screens/epub_reader_screen.dart';
import 'package:lumen_reader/features/reader/presentation/screens/pdf_reader_screen.dart';
import 'package:lumen_reader/features/reader/presentation/screens/txt_reader_screen.dart';

class RecentReadingScreen extends ConsumerWidget {
  const RecentReadingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryState = ref.watch(libraryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Lista Recente')),
      body: libraryState.when(
        data: (books) {
          final sortedBooks = List<Book>.from(books)
            ..sort((a, b) => b.lastRead.compareTo(a.lastRead));

          if (sortedBooks.isEmpty ||
              sortedBooks.every(
                (b) => b.lastRead == DateTime.fromMillisecondsSinceEpoch(0),
              )) {
            return const Center(child: Text('Nenhum livro lido recentemente.'));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.6,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: sortedBooks.length,
            itemBuilder: (context, index) {
              final book = sortedBooks[index];
              if (book.lastRead == DateTime.fromMillisecondsSinceEpoch(0)) {
                return const SizedBox(); // Skip unread
              }

              return BookCard(
                book: book,
                onTap: () => _openBook(context, book),
                onDelete: () {
                  // Start delete
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Remover livro?'),
                      content: const Text(
                        'Tem certeza que deseja remover este livro da biblioteca?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: () {
                            ref
                                .read(libraryProvider.notifier)
                                .removeBook(book.id);
                            Navigator.of(ctx).pop();
                          },
                          child: const Text('Remover'),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erro: $err')),
      ),
    );
  }

  void _openBook(BuildContext context, Book book) {
    switch (book.type) {
      case BookType.pdf:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                PdfReaderScreen(title: book.title, filePath: book.filePath),
          ),
        );
        return;
      case BookType.epub:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                EpubReaderScreen(title: book.title, filePath: book.filePath),
          ),
        );
        return;
      case BookType.txt:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                TxtReaderScreen(title: book.title, filePath: book.filePath),
          ),
        );
        return;
      case BookType.mobi:
      case BookType.fb2:
      case BookType.azw3:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Formato "${book.type.name.toUpperCase()}" ainda não tem leitor dedicado. Em breve!',
            ),
          ),
        );
        return;
    }
  }
}
