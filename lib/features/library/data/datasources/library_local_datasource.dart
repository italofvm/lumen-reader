import '../../domain/entities/book.dart';

abstract class LibraryLocalDataSource {
  Future<List<Book>> getBooks();
  Future<void> saveBook(Book book);
  Future<void> deleteBook(String bookId);
  Future<void> updateBookCoverPath(String bookId, String? coverPath);
  Future<void> updateBookProgress(String bookId, double progress);
  Future<void> updateBookPosition(
    String bookId,
    String position,
    double progress,
  );
  Future<void> deleteAllBooks();
}
