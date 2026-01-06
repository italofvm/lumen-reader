import '../entities/book.dart';
import '../repositories/library_repository.dart';

class GetBooks {
  final LibraryRepository repository;

  GetBooks(this.repository);

  Future<List<Book>> call() {
    return repository.getBooks();
  }
}
