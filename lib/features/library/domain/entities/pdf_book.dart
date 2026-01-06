import 'book.dart';

class PdfBook extends Book {
  PdfBook({
    required super.id,
    required super.title,
    required super.author,
    required super.filePath,
    super.coverPath,
    super.progress,
    super.lastPosition,
    required super.lastRead,
  }) : super(type: BookType.pdf);

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'filePath': filePath,
      'coverPath': coverPath,
      'type': 'pdf',
      'progress': progress,
      'lastPosition': lastPosition,
      'lastRead': lastRead.toIso8601String(),
    };
  }
}
