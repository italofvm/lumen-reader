import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen_reader/core/utils/book_utils.dart';
import '../../data/datasources/library_local_datasource_impl.dart';
import '../../data/repositories/library_repository_impl.dart';
import '../../domain/entities/book.dart';
import '../../domain/entities/pdf_book.dart';
import '../../domain/entities/epub_book.dart';
import '../../domain/entities/mobi_book.dart';
import '../../domain/entities/other_book.dart';
import '../../domain/usecases/add_book.dart';
import '../../domain/usecases/get_books.dart';
import '../../domain/usecases/remove_book.dart';
import '../../domain/usecases/clear_library.dart';

// Data Sources
final libraryLocalDataSourceProvider = Provider(
  (ref) => LibraryLocalDataSourceImpl(),
);

// Repositories
final libraryRepositoryProvider = Provider(
  (ref) => LibraryRepositoryImpl(
    localDataSource: ref.watch(libraryLocalDataSourceProvider),
  ),
);

// Use Cases
final getBooksUseCaseProvider = Provider(
  (ref) => GetBooks(ref.watch(libraryRepositoryProvider)),
);
final addBookUseCaseProvider = Provider(
  (ref) => AddBook(ref.watch(libraryRepositoryProvider)),
);
final removeBookUseCaseProvider = Provider(
  (ref) => RemoveBook(ref.watch(libraryRepositoryProvider)),
);
final clearLibraryUseCaseProvider = Provider(
  (ref) => ClearLibrary(ref.watch(libraryRepositoryProvider)),
);

// State Notifier Provider for the Library State
final libraryProvider =
    StateNotifierProvider<LibraryNotifier, AsyncValue<List<Book>>>((ref) {
      return LibraryNotifier(
        getBooks: ref.watch(getBooksUseCaseProvider),
        addBook: ref.watch(addBookUseCaseProvider),
        removeBook: ref.watch(removeBookUseCaseProvider),
        clearLibrary: ref.watch(clearLibraryUseCaseProvider),
      );
    });

class LibraryNotifier extends StateNotifier<AsyncValue<List<Book>>> {
  final GetBooks _getBooks;
  final AddBook _addBook;
  final RemoveBook _removeBook;
  final ClearLibrary _clearLibrary;

  LibraryNotifier({
    required GetBooks getBooks,
    required AddBook addBook,
    required RemoveBook removeBook,
    required ClearLibrary clearLibrary,
  }) : _getBooks = getBooks,
       _addBook = addBook,
       _removeBook = removeBook,
       _clearLibrary = clearLibrary,
       super(const AsyncValue.loading()) {
    loadBooks();
  }

  bool _isRepairingCovers = false;

  Future<void> loadBooks() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _getBooks());
    final books = state.asData?.value;
    if (books != null) {
      _repairMissingCoversInBackground(books);
    }
  }

  void _repairMissingCoversInBackground(List<Book> books) {
    if (_isRepairingCovers) return;
    _isRepairingCovers = true;

    Future<void>(() async {
      try {
        // Limit per run to avoid heavy CPU/IO spikes.
        const maxToRepair = 6;
        int repaired = 0;

        for (final book in books) {
          if (repaired >= maxToRepair) break;
          if (book.type != BookType.pdf && book.type != BookType.epub) continue;

          final coverPath = book.coverPath;
          final hasCoverFile =
              coverPath != null && coverPath.trim().isNotEmpty && File(coverPath).existsSync();
          if (hasCoverFile) continue;

          // If the book file is missing, skip.
          if (!File(book.filePath).existsSync()) continue;

          String? newCover;
          if (book.type == BookType.pdf) {
            newCover = await BookUtils.extractPdfCover(book.filePath, book.id);
          } else if (book.type == BookType.epub) {
            newCover = await BookUtils.extractEpubCover(book.filePath, book.id);
          }

          if (newCover == null || newCover.trim().isEmpty) continue;

          await (_getBooks as dynamic).repository.updateCoverPath(book.id, newCover);
          _updateCoverInState(book.id, newCover);
          repaired++;
        }
      } catch (_) {
        // Intentionally ignore errors to avoid breaking library load.
      } finally {
        _isRepairingCovers = false;
      }
    });
  }

  void _updateCoverInState(String bookId, String coverPath) {
    final current = state.asData?.value;
    if (current == null) return;

    final updated = current.map((b) {
      if (b.id != bookId) return b;

      if (b is PdfBook) {
        return PdfBook(
          id: b.id,
          title: b.title,
          author: b.author,
          filePath: b.filePath,
          coverPath: coverPath,
          progress: b.progress,
          lastPosition: b.lastPosition,
          lastRead: b.lastRead,
        );
      }

      if (b is EpubBook) {
        return EpubBook(
          id: b.id,
          title: b.title,
          author: b.author,
          filePath: b.filePath,
          coverPath: coverPath,
          progress: b.progress,
          lastPosition: b.lastPosition,
          lastRead: b.lastRead,
        );
      }

      if (b is MobiBook) {
        return MobiBook(
          id: b.id,
          title: b.title,
          author: b.author,
          filePath: b.filePath,
          coverPath: coverPath,
          progress: b.progress,
          lastPosition: b.lastPosition,
          lastRead: b.lastRead,
        );
      }

      if (b is OtherBook) {
        return OtherBook(
          id: b.id,
          title: b.title,
          author: b.author,
          filePath: b.filePath,
          coverPath: coverPath,
          type: b.type,
          progress: b.progress,
          lastPosition: b.lastPosition,
          lastRead: b.lastRead,
        );
      }

      return b;
    }).toList();

    state = AsyncValue.data(updated);
  }

  Future<void> importBook(Book book) async {
    await _addBook(book);
    await loadBooks();
  }

  Future<void> removeBook(String bookId) async {
    await _removeBook(bookId);
    await loadBooks();
  }

  Future<void> clearAll() async {
    await _clearLibrary();
    await loadBooks();
  }

  Future<void> updateBookPosition(
    String bookId,
    String position,
    double progress,
  ) async {
    await (_getBooks as dynamic).repository.updatePosition(bookId, position, progress);
    _updatePositionInState(bookId, position, progress);
  }

  void _updatePositionInState(String bookId, String position, double progress) {
    final current = state.asData?.value;
    if (current == null) return;

    final now = DateTime.now();

    final updated = current.map((b) {
      if (b.id != bookId) return b;

      if (b is PdfBook) {
        return PdfBook(
          id: b.id,
          title: b.title,
          author: b.author,
          filePath: b.filePath,
          coverPath: b.coverPath,
          progress: progress,
          lastPosition: position,
          lastRead: now,
        );
      }

      if (b is EpubBook) {
        return EpubBook(
          id: b.id,
          title: b.title,
          author: b.author,
          filePath: b.filePath,
          coverPath: b.coverPath,
          progress: progress,
          lastPosition: position,
          lastRead: now,
        );
      }

      if (b is MobiBook) {
        return MobiBook(
          id: b.id,
          title: b.title,
          author: b.author,
          filePath: b.filePath,
          coverPath: b.coverPath,
          progress: progress,
          lastPosition: position,
          lastRead: now,
        );
      }

      if (b is OtherBook) {
        return OtherBook(
          id: b.id,
          title: b.title,
          author: b.author,
          filePath: b.filePath,
          coverPath: b.coverPath,
          type: b.type,
          progress: progress,
          lastPosition: position,
          lastRead: now,
        );
      }

      return b;
    }).toList();

    state = AsyncValue.data(updated);
  }

  Future<void> clearCoversCache() async {
    final appDir = await getApplicationDocumentsDirectory();
    final coversDir = Directory(p.join(appDir.path, 'covers'));
    if (await coversDir.exists()) {
      await coversDir.delete(recursive: true);
      await coversDir.create();
    }
    await loadBooks();
  }
}
