import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lumen_reader/features/library/presentation/providers/library_providers.dart';
import 'package:lumen_reader/features/settings/domain/providers/settings_providers.dart';
import 'package:lumen_reader/features/library/domain/entities/book.dart';
import 'package:lumen_reader/features/library/domain/entities/other_book.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:lumen_reader/core/utils/book_utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:lumen_reader/features/library/presentation/screens/google_drive_picker_screen.dart';

// Removed unused _textExtensions

class FilesScreen extends ConsumerWidget {
  const FilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meus Arquivos')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final crossAxisCount = width >= 520 ? 4 : 2;
          // Ajuste fino para evitar cards altos demais em telas pequenas.
          final aspect = width >= 520 ? 1.05 : 1.35;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: aspect,
                  children: [
                    _FileActionCard(
                      icon: Icons.file_open,
                      label: 'Arquivo',
                      color: const Color(0xFF42A5F5),
                      onTap: () => _importBook(context, ref),
                    ),
                    _FileActionCard(
                      icon: Icons.folder,
                      label: 'Pasta',
                      color: const Color(0xFFFFA726),
                      onTap: () => _scanFolder(context, ref),
                    ),
                    _FileActionCard(
                      icon: Icons.cloud,
                      label: 'Google Drive',
                      color: const Color(0xFF66BB6A),
                      onTap: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const GoogleDrivePickerScreen(),
                          ),
                        );
                        if (!context.mounted) return;
                        if (result != null && result is Map<String, String>) {
                          await _handleImportedFile(
                            result['path']!,
                            result['name']!,
                            ref,
                            messenger,
                          );
                        }
                      },
                    ),
                    _FileActionCard(
                      icon: Icons.sd_storage,
                      label: 'Dispositivo',
                      color: const Color(0xFFBDBDBD),
                      onTap: () => _scanDevice(context, ref),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Selecione uma opção para adicionar livros à sua biblioteca.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- Logic copied from LibraryScreen (simplified/adapted) ---

  Future<void> _importBook(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'epub', 'mobi', 'fb2', 'txt', 'azw3'],
      withData: true,
    );
    if (!context.mounted) return;
    if (result != null) {
      final file = result.files.single;
      if (file.path != null) {
        await _handleImportedFile(file.path!, file.name, ref, messenger);
        return;
      }

      final bytes = file.bytes;
      if (bytes == null) {
        if (context.mounted) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Não foi possível acessar o arquivo selecionado.'),
            ),
          );
        }
        return;
      }

      final appDir = await getApplicationDocumentsDirectory();
      if (!context.mounted) return;
      final booksDir = Directory(p.join(appDir.path, 'books'));
      if (!await booksDir.exists()) await booksDir.create(recursive: true);

      final extension = file.name.split('.').last.toLowerCase();
      final bookId = '${DateTime.now().millisecondsSinceEpoch}_${file.name.hashCode}';
      final targetPath = p.join(booksDir.path, '$bookId.$extension');
      await File(targetPath).writeAsBytes(bytes, flush: true);
      if (!context.mounted) return;
      await _handleImportedFile(targetPath, file.name, ref, messenger);
    }
  }

  Future<void> _scanFolder(BuildContext context, WidgetRef ref) async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (!context.mounted) return;
    if (selectedDirectory == null) return;

    final messenger = ScaffoldMessenger.of(context);

    // Permission check usually redundant for getDirectoryPath on some OS but good practice for raw file access
    // On Android 11+ explicit permission might be needed or manage external storage

    final dir = Directory(selectedDirectory);
    if (await dir.exists()) {
      final allowedExtensions = ['pdf', 'epub', 'mobi', 'fb2', 'txt', 'azw3'];
      try {
        int addedCount = 0;

        await for (final entity in dir.list(recursive: true)) {
          if (entity is! File) continue;

          final fileName = entity.path.split('/').last;
          if (!ref.read(readerSettingsProvider).showHiddenFiles &&
              fileName.startsWith('.')) {
            continue;
          }

          final ext = fileName.split('.').last.toLowerCase();
          if (!allowedExtensions.contains(ext)) continue;

          await _handleImportedFile(
            entity.path,
            fileName,
            ref,
            messenger,
            isBatch: true,
          );
          addedCount++;
        }
        if (!context.mounted) return;
        if (context.mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text('$addedCount livros encontrados.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text('Erro ao escanear pasta: $e')),
          );
        }
      }
    }
  }

  Future<void> _scanDevice(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    var status = await Permission.storage.status;
    if (!context.mounted) return;
    if (!status.isGranted) {
      status = await Permission.storage.request();
      if (!context.mounted) return;
    }

    var manageStatus = await Permission.manageExternalStorage.status;
    if (!context.mounted) return;
    if (!manageStatus.isGranted && !status.isGranted) {
      manageStatus = await Permission.manageExternalStorage.request();
      if (!context.mounted) return;
    }

    if (status.isGranted || manageStatus.isGranted) {
      // Very basic scan implementation - usually needs more robust logic for Android 11+
      // Using /storage/emulated/0/Download and Documents as common targets
      final allowedExtensions = ['pdf', 'epub', 'mobi', 'fb2', 'txt', 'azw3'];
      int totalAdded = 0;

      final roots = [
        Directory('/storage/emulated/0/Download'),
        Directory('/storage/emulated/0/Documents'),
        Directory('/storage/emulated/0/Books'),
      ];

      for (var dir in roots) {
        if (await dir.exists()) {
          try {
            await for (final entity in dir.list(recursive: true)) {
              if (entity is! File) continue;

              final fileName = entity.path.split('/').last;
              if (!ref.read(readerSettingsProvider).showHiddenFiles &&
                  fileName.startsWith('.')) {
                continue;
              }

              final ext = fileName.split('.').last.toLowerCase();
              if (!allowedExtensions.contains(ext)) continue;

              await _handleImportedFile(
                entity.path,
                fileName,
                ref,
                messenger,
                isBatch: true,
              );
              totalAdded++;
            }
          } catch (e) {
            debugPrint('Error scanning $dir: $e');
          }
        }
      }
      if (!context.mounted) return;
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Escanenamento concluído. $totalAdded livros adicionados.',
            ),
          ),
        );
      }
    } else {
      if (!context.mounted) return;
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: const Text(
              'Permissão de armazenamento negada. Ative nas configurações para escanear o dispositivo.',
            ),
            action: SnackBarAction(
              label: 'Abrir',
              onPressed: () {
                openAppSettings();
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleImportedFile(
    String filePath,
    String fileName,
    WidgetRef ref,
    ScaffoldMessengerState messenger, {
    bool isBatch = false,
  }) async {
    final extension = fileName.split('.').last.toLowerCase();

    // Basic logic: Copy to app directory
    final appDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory(p.join(appDir.path, 'books'));
    if (!await booksDir.exists()) await booksDir.create(recursive: true);

    final booksDirPath = booksDir.path;

    // Generate ID
    late final String bookId;
    late final String targetPath;
    if (p.isWithin(booksDirPath, filePath) || p.dirname(filePath) == booksDirPath) {
      targetPath = filePath;
      bookId = p.basenameWithoutExtension(filePath);
    } else {
      bookId = '${DateTime.now().millisecondsSinceEpoch}_${fileName.hashCode}';
      targetPath = p.join(booksDir.path, '$bookId.$extension');
      await File(filePath).copy(targetPath);
    }

    // Extract cover
    String? coverPath;
    if (extension == 'epub') {
      coverPath = await BookUtils.extractEpubCover(targetPath, bookId);
    } else if (extension == 'pdf') {
      coverPath = await BookUtils.extractPdfCover(targetPath, bookId);
    }

    final book = OtherBook(
      id: bookId,
      title: fileName.replaceAll('.$extension', ''), // Simple title
      author: 'Desconhecido',
      coverPath: coverPath,
      filePath: targetPath,
      type: BookType.values.firstWhere(
        (e) => e.name == extension,
        orElse: () => BookType.txt,
      ),
      lastRead: DateTime.now(), // Recently added
      progress: 0.0,
    );

    await ref.read(libraryProvider.notifier).importBook(book);

    if (!isBatch) {
      messenger.showSnackBar(
        SnackBar(content: Text('Livro "$fileName" importado com sucesso!')),
      );
    }
  }
}

class _FileActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _FileActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withAlpha((0.1 * 255).round()),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
