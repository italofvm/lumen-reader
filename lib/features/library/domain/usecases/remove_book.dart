import '../repositories/library_repository.dart';

class RemoveBook {
  final LibraryRepository repository;

  RemoveBook(this.repository);

  Future<void> call(String bookId) async {
    return repository.removeBook(bookId);
  }
}
