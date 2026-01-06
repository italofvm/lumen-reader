import 'book.dart';

class EpubBook extends Book {
  EpubBook({
    required super.id,
    required super.title,
    required super.author,
    required super.filePath,
    super.coverPath,
    super.progress,
    super.lastPosition,
    required super.lastRead,
  }) : super(type: BookType.epub);

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'filePath': filePath,
      'coverPath': coverPath,
      'type': 'epub',
      'progress': progress,
      'lastPosition': lastPosition,
      'lastRead': lastRead.toIso8601String(),
    };
  }
}
