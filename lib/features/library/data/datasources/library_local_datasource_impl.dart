import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/book.dart';
import '../../domain/entities/pdf_book.dart';
import '../../domain/entities/epub_book.dart';
import '../../domain/entities/mobi_book.dart';
import '../../domain/entities/other_book.dart';
import 'library_local_datasource.dart';
import 'dart:io';

class LibraryLocalDataSourceImpl implements LibraryLocalDataSource {
  static const String _boxName = 'library_box';

  @override
  Future<List<Book>> getBooks() async {
    final box = await Hive.openBox(_boxName);
    return box.values.map((data) {
      final map = Map<String, dynamic>.from(data);
      final typeStr = map['type'] as String;
      final type = BookType.values.firstWhere(
        (e) => e.name == typeStr,
        orElse: () => BookType.pdf,
      );

      final id = map['id'];
      final title = map['title'];
      final author = map['author'];
      final filePath = map['filePath'];
      final coverPath = map['coverPath'];
      final progress = map['progress'] ?? 0.0;
      final lastPosition = map['lastPosition'] as String?;
      final lastRead = DateTime.parse(map['lastRead']);

      if (type == BookType.pdf) {
        return PdfBook(
          id: id,
          title: title,
          author: author,
          filePath: filePath,
          coverPath: coverPath,
          progress: progress,
          lastPosition: lastPosition,
          lastRead: lastRead,
        );
      } else if (type == BookType.epub) {
        return EpubBook(
          id: id,
          title: title,
          author: author,
          filePath: filePath,
          coverPath: coverPath,
          progress: progress,
          lastPosition: lastPosition,
          lastRead: lastRead,
        );
      } else if (type == BookType.mobi) {
        return MobiBook(
          id: id,
          title: title,
          author: author,
          filePath: filePath,
          coverPath: coverPath,
          progress: progress,
          lastPosition: lastPosition,
          lastRead: lastRead,
        );
      } else {
        return OtherBook(
          id: id,
          title: title,
          author: author,
          filePath: filePath,
          coverPath: coverPath,
          type: type,
          progress: progress,
          lastRead: lastRead,
        );
      }
    }).toList();
  }

  @override
  Future<void> saveBook(Book book) async {
    final box = await Hive.openBox(_boxName);
    await box.put(book.id, book.toMap());
  }

  @override
  Future<void> updateBookCoverPath(String bookId, String? coverPath) async {
    final box = await Hive.openBox(_boxName);
    final data = box.get(bookId);
    if (data == null) return;
    final map = Map<String, dynamic>.from(data);
    map['coverPath'] = coverPath;
    await box.put(bookId, map);
  }

  @override
  Future<void> deleteBook(String bookId) async {
    final box = await Hive.openBox(_boxName);
    final data = box.get(bookId);
    if (data != null) {
      final map = Map<String, dynamic>.from(data);
      final filePath = map['filePath'] as String;
      final coverPath = map['coverPath'] as String?;

      final appDir = await getApplicationDocumentsDirectory();

      // Only delete files if they are in our managed directory
      if (filePath.startsWith(appDir.path)) {
        if (File(filePath).existsSync()) await File(filePath).delete();
      }

      if (coverPath != null && coverPath.startsWith(appDir.path)) {
        if (File(coverPath).existsSync()) await File(coverPath).delete();
      }
    }
    await box.delete(bookId);
  }

  @override
  Future<void> deleteAllBooks() async {
    final box = await Hive.openBox(_boxName);
    for (var key in box.keys) {
      await deleteBook(key.toString());
    }
    await box.clear();
  }

  @override
  Future<void> updateBookProgress(String bookId, double progress) async {
    final box = await Hive.openBox(_boxName);
    final data = box.get(bookId);
    if (data != null) {
      final map = Map<String, dynamic>.from(data);
      map['progress'] = progress;
      map['lastRead'] = DateTime.now().toIso8601String();
      await box.put(bookId, map);
    }
  }

  @override
  Future<void> updateBookPosition(
    String bookId,
    String position,
    double progress,
  ) async {
    final box = await Hive.openBox(_boxName);
    final data = box.get(bookId);
    if (data != null) {
      final map = Map<String, dynamic>.from(data);
      map['lastPosition'] = position;
      map['progress'] = progress;
      map['lastRead'] = DateTime.now().toIso8601String();
      await box.put(bookId, map);
    }
  }
}
