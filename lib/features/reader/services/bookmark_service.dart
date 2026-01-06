import 'package:hive_flutter/hive_flutter.dart';

class ReaderBookmark {
  final String id;
  final String label;
  final String position;
  final DateTime createdAt;

  ReaderBookmark({
    required this.id,
    required this.label,
    required this.position,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'position': position,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static ReaderBookmark fromMap(Map<String, dynamic> map) {
    return ReaderBookmark(
      id: map['id'] as String,
      label: map['label'] as String? ?? '',
      position: map['position'] as String? ?? '',
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}

class BookmarkService {
  static const String _boxName = 'bookmarks_box';

  Future<List<ReaderBookmark>> listBookmarks(String bookId) async {
    final box = await Hive.openBox(_boxName);
    final raw = box.get(bookId);
    if (raw == null) return [];

    final list = List<Map>.from(raw as List);
    final bookmarks = list
        .map((e) => ReaderBookmark.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    bookmarks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return bookmarks;
  }

  Future<void> addBookmark({
    required String bookId,
    required String label,
    required String position,
  }) async {
    final box = await Hive.openBox(_boxName);
    final raw = box.get(bookId);
    final list = raw == null ? <Map<String, dynamic>>[] : List<Map>.from(raw);

    final now = DateTime.now();
    final id = '${now.microsecondsSinceEpoch}';

    list.add(
      ReaderBookmark(
        id: id,
        label: label,
        position: position,
        createdAt: now,
      ).toMap(),
    );

    await box.put(bookId, list);
  }

  Future<void> removeBookmark({
    required String bookId,
    required String bookmarkId,
  }) async {
    final box = await Hive.openBox(_boxName);
    final raw = box.get(bookId);
    if (raw == null) return;

    final list = List<Map>.from(raw as List);
    list.removeWhere((e) => (e['id']?.toString() ?? '') == bookmarkId);
    await box.put(bookId, list);
  }

  Future<void> clearBookmarks(String bookId) async {
    final box = await Hive.openBox(_boxName);
    await box.delete(bookId);
  }
}
