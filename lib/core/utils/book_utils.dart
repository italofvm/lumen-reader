import 'dart:io';
import 'package:epubx/epubx.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:image/image.dart' as img;
import 'package:pdfx/pdfx.dart';

class BookUtils {
  static Future<String?> extractEpubCover(
    String filePath,
    String bookId,
  ) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final epubBook = await EpubReader.readBook(bytes);

      final coverImage = epubBook.CoverImage;
      if (coverImage != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final coversDir = Directory(p.join(appDir.path, 'covers'));
        if (!await coversDir.exists()) {
          await coversDir.create(recursive: true);
        }

        final coverPath = p.join(coversDir.path, '$bookId.png');

        // Encode the image to PNG and save it
        final pngBytes = img.encodePng(coverImage);
        await File(coverPath).writeAsBytes(pngBytes);

        return coverPath;
      }
    } catch (e) {
      print('Error extracting cover: $e');
    }
    return null;
  }

  static Future<String?> extractPdfCover(String filePath, String bookId) async {
    try {
      final document = await PdfDocument.openFile(filePath);
      final page = await document.getPage(1);

      final pageImage = await page.render(
        width: page.width * 2,
        height: page.height * 2,
      );

      if (pageImage != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final coversDir = Directory(p.join(appDir.path, 'covers'));
        if (!await coversDir.exists()) {
          await coversDir.create(recursive: true);
        }

        final coverPath = p.join(coversDir.path, '$bookId.png');
        await File(coverPath).writeAsBytes(pageImage.bytes);

        // pdfx closables are handled correctly by the library usually,
        // but it's good practice to close if available.
        // In many versions of native_pdf_renderer,
        //close() is used but might be implicit in some wrappers.

        return coverPath;
      }
    } catch (e) {
      print('Error extracting PDF cover: $e');
    }
    return null;
  }
}
