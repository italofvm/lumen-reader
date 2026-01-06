import '../entities/book.dart';

abstract class LibraryRepository {
  Future<List<Book>> getBooks();
  Future<void> addBook(Book book);
  Future<void> removeBook(String bookId);
  Future<void> updateCoverPath(String bookId, String? coverPath);
  Future<void> updateProgress(String bookId, double progress);
  Future<void> updatePosition(String bookId, String position, double progress);
  Future<void> clearLibrary();
}
