import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widget_previews.dart';
import 'package:lumen_reader/features/library/presentation/screens/library_screen.dart';
import 'package:lumen_reader/features/library/presentation/providers/library_providers.dart';
import 'package:lumen_reader/features/library/domain/entities/book.dart';
import 'package:lumen_reader/features/library/domain/entities/pdf_book.dart';

// This is an experimental feature of Flutter 3.35+
// It allows seeing widgets in a dedicated sidebar/previewer in the IDE.

import 'package:lumen_reader/features/settings/presentation/screens/settings_screen.dart';

@Preview()
Widget libraryScreenPreview() {
  return ProviderScope(
    overrides: [libraryProvider.overrideWith((ref) => LibraryNotifierMock())],
    child: const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LibraryScreen(),
    ),
  );
}

@Preview()
Widget settingsScreenPreview() {
  return const ProviderScope(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SettingsScreen(),
    ),
  );
}

class LibraryNotifierMock extends StateNotifier<AsyncValue<List<Book>>>
    implements LibraryNotifier {
  LibraryNotifierMock() : super(const AsyncValue.loading()) {
    loadBooks();
  }

  @override
  Future<void> loadBooks() async {
    state = AsyncValue.data([
      PdfBook(
        id: '1',
        title: 'Exemplo de Livro PDF',
        author: 'Autor Teste',
        filePath: '/tmp/test.pdf',
        lastRead: DateTime.now(),
      ),
      PdfBook(
        id: '2',
        title: 'Outro Livro de Teste',
        author: 'Design Moderno',
        filePath: '/tmp/test2.pdf',
        lastRead: DateTime.now(),
      ),
    ]);
  }

  @override
  Future<void> importBook(Book book) async {}

  @override
  Future<void> removeBook(String bookId) async {}

  @override
  Future<void> clearAll() async {}

  @override
  Future<void> clearCoversCache() async {}

  @override
  Future<void> updateBookPosition(
    String bookId,
    String position,
    double progress,
  ) async {}

  // Dummy implementations for private fields if needed,
  // but since we inherit/implement we just need the public API.
}
