import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen_reader/features/library/domain/entities/book.dart';
import 'package:lumen_reader/features/library/presentation/widgets/book_list_tile.dart';

class BookSearchDelegate extends SearchDelegate<Book?> {
  final List<Book> books;
  final WidgetRef ref;

  BookSearchDelegate({required this.books, required this.ref});

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    final results = books.where((book) {
      final searchLower = query.toLowerCase();
      return book.title.toLowerCase().contains(searchLower) ||
          book.author.toLowerCase().contains(searchLower);
    }).toList();

    if (results.isEmpty) {
      return const Center(child: Text('Nenhum livro encontrado.'));
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final book = results[index];
        return BookListTile(
          book: book,
          onTap: () {
            close(context, book);
          },
          onDelete: () {
            // No delete from search for now to keep it simple,
            // but we could implement if needed
          },
        );
      },
    );
  }
}
