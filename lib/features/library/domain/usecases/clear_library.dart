import '../repositories/library_repository.dart';

class ClearLibrary {
  final LibraryRepository repository;

  ClearLibrary(this.repository);

  Future<void> call() async {
    return repository.clearLibrary();
  }
}
