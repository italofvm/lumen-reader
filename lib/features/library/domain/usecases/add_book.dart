import '../entities/book.dart';
import '../repositories/library_repository.dart';

class AddBook {
  final LibraryRepository repository;

  AddBook(this.repository);

  Future<void> call(Book book) {
    return repository.addBook(book);
  }
}
