import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lumen_reader/core/utils/book_utils.dart';
import 'package:lumen_reader/features/library/domain/entities/book.dart';
import 'package:lumen_reader/features/library/domain/entities/epub_book.dart';
import 'package:lumen_reader/features/library/domain/entities/other_book.dart';
import 'package:lumen_reader/features/library/domain/entities/pdf_book.dart';
import 'package:lumen_reader/features/library/presentation/providers/library_providers.dart';
import 'package:lumen_reader/features/settings/domain/providers/settings_providers.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AutoImportService {
  static const MethodChannel _safChannel = MethodChannel('lumen_reader/saf');

  static const String _boxName = 'settings';
  static const String _keyImportedNames = 'auto_import_imported_names';

  final WidgetRef _ref;

  AutoImportService(this._ref);

  Future<void> runIfEnabled() async {
    final settings = _ref.read(readerSettingsProvider);
    if (!settings.autoImportEnabled) return;

    if (kIsWeb) return;

    if (Platform.isAndroid) {
      final uri = settings.mainDirectoryUri;
      if (uri == null || uri.trim().isEmpty) return;
      await _importFromAndroidSafUri(uri);
      return;
    }

    final dir = settings.mainDirectory;
    if (dir == null || dir.trim().isEmpty) return;
    await _importFromDirectoryPath(dir);
  }

  Future<void> _importFromAndroidSafUri(String uri) async {
    final box = await Hive.openBox(_boxName);
    final imported = _readImportedNames(box);

    final dynamic result = await _safChannel.invokeMethod<dynamic>(
      'listBooksFromDirectoryUri',
      {'uri': uri},
    );

    if (result is! List) return;

    for (final item in result) {
      if (item is! Map) continue;
      final path = item['path'];
      final name = item['name'];
      if (path is! String || name is! String) continue;

      if (imported.contains(name)) continue;

      final ok = await _importSingleFile(path: path, fileName: name);
      if (ok) {
        imported.add(name);
      }
    }

    await box.put(_keyImportedNames, imported.toList());
  }

  Future<void> _importFromDirectoryPath(String directoryPath) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) return;

    final box = await Hive.openBox(_boxName);
    final imported = _readImportedNames(box);

    final allowedExtensions = {'pdf', 'epub', 'mobi', 'fb2', 'txt', 'azw3'};

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final fileName = p.basename(entity.path);
      final ext = p.extension(fileName).replaceFirst('.', '').toLowerCase();
      if (!allowedExtensions.contains(ext)) continue;

      if (imported.contains(fileName)) continue;

      final ok = await _importSingleFile(path: entity.path, fileName: fileName);
      if (ok) {
        imported.add(fileName);
      }
    }

    await box.put(_keyImportedNames, imported.toList());
  }

  Set<String> _readImportedNames(Box box) {
    final raw = box.get(_keyImportedNames);
    if (raw is List) {
      return raw.whereType<String>().toSet();
    }
    return <String>{};
  }

  Future<bool> _importSingleFile({required String path, required String fileName}) async {
    final books = _ref.read(libraryProvider).asData?.value ?? const <Book>[];

    // Evita duplicar por nome (simples) e por caminho.
    if (books.any((b) => b.filePath == path)) return false;

    final extension = fileName.split('.').last.toLowerCase();

    final appDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory(p.join(appDir.path, 'books'));
    if (!await booksDir.exists()) await booksDir.create(recursive: true);

    final bookId = '${DateTime.now().millisecondsSinceEpoch}_${fileName.hashCode}';
    final targetPath = p.join(booksDir.path, '$bookId.$extension');

    if (p.isWithin(booksDir.path, path) || p.dirname(path) == booksDir.path) {
      // Arquivo já está no diretório gerenciado pelo app.
      return await _importAsBook(filePath: path, fileName: fileName, bookId: bookId);
    }

    await File(path).copy(targetPath);
    return await _importAsBook(filePath: targetPath, fileName: fileName, bookId: bookId);
  }

  Future<bool> _importAsBook({
    required String filePath,
    required String fileName,
    required String bookId,
  }) async {
    final extension = fileName.split('.').last.toLowerCase();

    if (extension == 'pdf') {
      final coverPath = await BookUtils.extractPdfCover(filePath, bookId);
      final book = PdfBook(
        id: bookId,
        title: fileName,
        author: 'Desconhecido',
        filePath: filePath,
        coverPath: coverPath,
        lastRead: DateTime.now(),
      );
      await _ref.read(libraryProvider.notifier).importBook(book);
      return true;
    }

    if (extension == 'epub') {
      final coverPath = await BookUtils.extractEpubCover(filePath, bookId);
      final book = EpubBook(
        id: bookId,
        title: fileName,
        author: 'Desconhecido',
        filePath: filePath,
        coverPath: coverPath,
        lastRead: DateTime.now(),
      );
      await _ref.read(libraryProvider.notifier).importBook(book);
      return true;
    }

    final type = BookType.values.firstWhere(
      (e) => e.name == extension,
      orElse: () => BookType.txt,
    );

    final book = OtherBook(
      id: bookId,
      title: fileName,
      author: 'Desconhecido',
      filePath: filePath,
      type: type,
      lastRead: DateTime.now(),
      progress: 0.0,
    );

    await _ref.read(libraryProvider.notifier).importBook(book);
    return true;
  }
}
