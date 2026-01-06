import '../../domain/entities/book.dart';
import '../../domain/repositories/library_repository.dart';
import '../datasources/library_local_datasource.dart';

class LibraryRepositoryImpl implements LibraryRepository {
  final LibraryLocalDataSource localDataSource;

  LibraryRepositoryImpl({required this.localDataSource});

  @override
  Future<List<Book>> getBooks() {
    return localDataSource.getBooks();
  }

  @override
  Future<void> addBook(Book book) {
    return localDataSource.saveBook(book);
  }

  @override
  Future<void> removeBook(String bookId) {
    return localDataSource.deleteBook(bookId);
  }

  @override
  Future<void> updateCoverPath(String bookId, String? coverPath) {
    return localDataSource.updateBookCoverPath(bookId, coverPath);
  }

  @override
  Future<void> updateProgress(String bookId, double progress) {
    return localDataSource.updateBookProgress(bookId, progress);
  }

  @override
  Future<void> updatePosition(String bookId, String position, double progress) {
    return localDataSource.updateBookPosition(bookId, position, progress);
  }

  @override
  Future<void> clearLibrary() {
    return localDataSource.deleteAllBooks();
  }
}
