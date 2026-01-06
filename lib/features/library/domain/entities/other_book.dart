import 'book.dart';

class OtherBook extends Book {
  OtherBook({
    required super.id,
    required super.title,
    required super.author,
    required super.filePath,
    super.coverPath,
    required super.type,
    super.progress,
    super.lastPosition,
    required super.lastRead,
  });

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'filePath': filePath,
      'coverPath': coverPath,
      'type': type.name,
      'progress': progress,
      'lastPosition': lastPosition,
      'lastRead': lastRead.toIso8601String(),
    };
  }
}
