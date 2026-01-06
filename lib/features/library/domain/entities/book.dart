enum BookType { pdf, epub, mobi, fb2, txt, azw3 }

abstract class Book {
  final String id;
  final String title;
  final String author;
  final String filePath;
  final String? coverPath;
  final BookType type;
  final double progress;
  final String? lastPosition;
  final DateTime lastRead;

  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.filePath,
    this.coverPath,
    required this.type,
    this.progress = 0.0,
    this.lastPosition,
    required this.lastRead,
  });

  Map<String, dynamic> toMap();
}
