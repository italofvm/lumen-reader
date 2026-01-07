import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lumen_reader/features/library/presentation/widgets/book_card.dart';
import 'package:lumen_reader/features/library/presentation/widgets/book_list_tile.dart';
import 'package:lumen_reader/features/reader/presentation/screens/pdf_reader_screen.dart';
import 'package:lumen_reader/features/reader/presentation/screens/epub_reader_screen.dart';
import 'package:lumen_reader/features/reader/presentation/screens/txt_reader_screen.dart';
import 'package:lumen_reader/features/settings/presentation/screens/settings_screen.dart';
import 'package:lumen_reader/features/settings/domain/providers/settings_providers.dart';
import 'package:lumen_reader/features/library/presentation/providers/library_providers.dart';
import 'package:lumen_reader/features/library/presentation/screens/recent_reading_screen.dart';
import 'package:lumen_reader/features/library/presentation/screens/files_screen.dart';
import 'package:lumen_reader/features/library/presentation/screens/google_drive_picker_screen.dart';
import 'package:lumen_reader/features/library/presentation/widgets/book_search_delegate.dart';
import 'package:lumen_reader/core/utils/book_utils.dart';
import 'package:lumen_reader/features/library/presentation/widgets/dashboard_widgets.dart';
import 'package:lumen_reader/features/library/domain/entities/book.dart';
import 'package:lumen_reader/features/library/domain/entities/pdf_book.dart';
import 'package:lumen_reader/features/library/domain/entities/epub_book.dart';
import 'package:lumen_reader/features/library/domain/entities/other_book.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart'; // Import for kIsWeb
import 'package:permission_handler/permission_handler.dart';

const List<String> _textExtensions = ['mobi', 'fb2', 'txt', 'azw3'];

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  @override
  Widget build(BuildContext context) {
    final libraryState = ref.watch(libraryProvider);
    final settings = ref.watch(readerSettingsProvider);

    return Scaffold(
      backgroundColor: settings.isWoodShelf
          ? const Color(0xFF121212) // Dark background for grid
          : Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: settings.isWoodShelf,
      appBar: AppBar(
        title: Text(
          'Biblioteca',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: settings.isWoodShelf ? Colors.white : null,
          ),
        ),
        backgroundColor: settings.isWoodShelf
            ? Colors.transparent
            : Theme.of(context).appBarTheme.backgroundColor,
        iconTheme: IconThemeData(
          color: settings.isWoodShelf
              ? Colors.white
              : Theme.of(context).iconTheme.color,
        ),
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              final books = libraryState.asData?.value ?? [];
              final selectedBook = await showSearch<Book?>(
                context: context,
                delegate: BookSearchDelegate(books: books, ref: ref),
              );

              if (selectedBook != null && context.mounted) {
                _openBook(context, selectedBook);
              }
            },
          ),
          PopupMenuButton<LibraryViewMode>(
            icon: Icon(
              settings.viewMode == LibraryViewMode.grid
                  ? Icons.grid_view_rounded
                  : settings.viewMode == LibraryViewMode.list
                  ? Icons.view_list_rounded
                  : Icons.view_sidebar_rounded,
            ),
            tooltip: 'Modo de visualização',
            onSelected: (mode) {
              ref.read(readerSettingsProvider.notifier).setViewMode(mode);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: LibraryViewMode.grid,
                child: Row(
                  children: [
                    Icon(Icons.grid_view_rounded, size: 20),
                    SizedBox(width: 12),
                    Text('Grade'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: LibraryViewMode.list,
                child: Row(
                  children: [
                    Icon(Icons.view_list_rounded, size: 20),
                    SizedBox(width: 12),
                    Text('Lista'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: LibraryViewMode.sideBySide,
                child: Row(
                  children: [
                    Icon(Icons.view_sidebar_rounded, size: 20),
                    SizedBox(width: 12),
                    Text('Lado a lado'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: Stack(
        children: [
          if (settings.isWoodShelf)
            Positioned.fill(
              child: CustomPaint(painter: _GridBackgroundPainter()),
            ),
          libraryState.when(
            data: (books) {
              // Sort books by lastRead for Recent section
              final sortedBooks = List<Book>.from(books)
                ..sort((a, b) => b.lastRead.compareTo(a.lastRead));

              final recentBook = sortedBooks.isNotEmpty
                  ? sortedBooks.first
                  : null;

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Espaçamento inicial
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),

                  // Recent Section
                  if (!settings.isWoodShelf && recentBook != null)
                    SliverToBoxAdapter(
                      child: DashboardSection(
                        title: 'Lista recente',
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Row(
                            children: [
                              BookCover(
                                book: recentBook,
                                width: 100,
                                height: 150,
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      recentBook.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: null,
                                          ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      recentBook.author,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontSize: 14,
                                            color: const Color(0xFF666677),
                                          ),
                                    ),
                                    const SizedBox(height: 24),
                                    FilledButton.icon(
                                      onPressed: () =>
                                          _openBook(context, recentBook),
                                      icon: const Icon(Icons.menu_book),
                                      label: const Text('Continuar Lendo'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF5C6BC0,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 32)),

                  // Quick Actions Section (Hide in Wood Shelf mode)
                  if (!settings.isWoodShelf)
                    SliverToBoxAdapter(
                      child: DashboardSection(
                        title: 'Meus Arquivos',
                        onSettingsTap:
                            () {}, // Placeholder for section settings
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 28),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              QuickActionItem(
                                icon: Icons.file_open,
                                label: 'Arquivo',
                                color: const Color(
                                  0xFF42A5F5,
                                ), // Blue/Dropbox style
                                onTap: () => _importBook(context, ref),
                              ),
                              QuickActionItem(
                                icon: Icons.folder,
                                label: 'Pasta',
                                color: const Color(
                                  0xFFFFA726,
                                ), // Orange/WebDav style
                                onTap: () => _scanFolder(context, ref),
                              ),
                              QuickActionItem(
                                icon: Icons.cloud,
                                label: 'Nuvem',
                                color: const Color(
                                  0xFF66BB6A,
                                ), // Green/FTP style
                                onTap: () async {
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
                                    );
                                  }
                                },
                              ),
                              QuickActionItem(
                                icon: Icons.sd_storage,
                                label: 'Escanear',
                                color: const Color(
                                  0xFFBDBDBD,
                                ), // Grey/SDCard style
                                onTap: () => _scanDevice(context, ref),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  if (!settings.isWoodShelf)
                    const SliverToBoxAdapter(child: SizedBox(height: 40)),

                  // View Mode selector removed from here as it's now in the AppBar
                  if (!settings.isWoodShelf)
                    const SliverToBoxAdapter(child: SizedBox(height: 40)),

                  // Grid de livros
                  if (books.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(40.0),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.library_books_outlined,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Nenhum livro encontrado.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.symmetric(
                        horizontal: settings.isWoodShelf ? 16.0 : 24.0,
                        vertical: 20.0,
                      ),
                      sliver: _buildLibraryContent(context, books, settings),
                    ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 100),
                  ), // Bottom padding aumentado
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Erro: $err')),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF121318) : cs.surface,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  padding: EdgeInsets.zero,
                  margin: EdgeInsets.zero,
                  decoration: const BoxDecoration(color: Color(0xFF2C3E50)),
                  child: Stack(
                    children: [
                      // Background Image
                      Positioned.fill(
                        child: Image.asset(
                          'assets/images/drawer_bg.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                      // Frosted Glass Effect
                      Positioned.fill(
                        child: ClipRect(
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(
                              sigmaX: 5.0,
                              sigmaY: 5.0,
                            ),
                            child: Container(
                              color: Colors.black.withAlpha((0.3 * 255).round()),
                            ),
                          ),
                        ),
                      ),
                      // Content
                      Positioned.fill(
                        child: SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withAlpha((0.2 * 255).round()),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: Image.asset(
                                        'assets/icon/app_icon.png',
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Lumen Reader',
                                            style: Theme.of(context)
                                                .textTheme
                                                .headlineSmall
                                                ?.copyWith(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 24,
                                                  letterSpacing: 0.5,
                                                  shadows: [
                                                    const Shadow(
                                                      color: Colors.black45,
                                                      offset: Offset(2, 2),
                                                      blurRadius: 4,
                                                    ),
                                                  ],
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Sua biblioteca pessoal',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: Colors.white
                                                      .withAlpha((0.9 * 255).round()),
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Material(
                      color: Colors.transparent,
                      child: Column(
                        children: [
                          ListTile(
                            leading: Icon(
                              Icons.history,
                              color: cs.onSurface.withAlpha((0.90 * 255).round()),
                            ),
                            title: Text(
                              'Lista recente',
                              style: TextStyle(
                                color: cs.onSurface.withAlpha((0.92 * 255).round()),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onTap: () {
                              Navigator.pop(context); // Close drawer
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const RecentReadingScreen(),
                                ),
                              );
                            },
                          ),
                          ListTile(
                            selected: true,
                            selectedTileColor: cs.primary.withAlpha((0.12 * 255).round()),
                            leading: Icon(
                              Icons.book,
                              color: cs.primary,
                            ),
                            title: Text(
                              'Minha estante',
                              style: TextStyle(
                                color: cs.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onTap: () => Navigator.pop(context),
                          ),
                          ListTile(
                            leading: Icon(
                              Icons.folder_open,
                              color: cs.onSurface.withAlpha((0.90 * 255).round()),
                            ),
                            title: Text(
                              'Meus Arquivos',
                              style: TextStyle(
                                color: cs.onSurface.withAlpha((0.92 * 255).round()),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const FilesScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ListTile(
                tileColor: cs.surfaceContainerHighest.withAlpha(((isDark ? 0.25 : 0.35) * 255).round()),
                leading: Icon(Icons.settings, color: cs.onSurface.withAlpha((0.92 * 255).round())),
                title: Text(
                  'Configurações',
                  style: TextStyle(
                    color: cs.onSurface.withAlpha((0.92 * 255).round()),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                trailing: Icon(Icons.chevron_right_rounded, color: cs.onSurface.withAlpha((0.55 * 255).round())),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  Future<void> _handleImportedFile(
    String filePath,
    String fileName,
    WidgetRef ref,
  ) async {
    final books = ref.read(libraryProvider).asData?.value ?? [];
    if (books.any((b) => b.filePath == filePath)) {
      // book already in library
      return;
    }

    final extension = fileName.split('.').last.toLowerCase();
    final bookId = DateTime.now().millisecondsSinceEpoch.toString();

    if (extension == 'pdf') {
      final coverPath = await BookUtils.extractPdfCover(filePath, bookId);
      final pdfBook = PdfBook(
        id: bookId,
        title: fileName,
        author: 'Desconhecido',
        filePath: filePath,
        coverPath: coverPath,
        lastRead: DateTime.now(),
      );
      await ref.read(libraryProvider.notifier).importBook(pdfBook);
    } else if (extension == 'epub') {
      final coverPath = await BookUtils.extractEpubCover(filePath, bookId);
      final epubBook = EpubBook(
        id: bookId,
        title: fileName,
        author: 'Desconhecido',
        filePath: filePath,
        coverPath: coverPath,
        lastRead: DateTime.now(),
      );
      await ref.read(libraryProvider.notifier).importBook(epubBook);
    } else if (_textExtensions.contains(extension)) {
      final type = BookType.values.firstWhere(
        (e) => e.name == extension,
        orElse: () => BookType.mobi,
      );
      final book = OtherBook(
        id: bookId,
        title: fileName,
        author: 'Desconhecido',
        filePath: filePath,
        type: type,
        lastRead: DateTime.now(),
      );
      await ref.read(libraryProvider.notifier).importBook(book);
    }
  }

  Future<void> _scanFolder(BuildContext context, WidgetRef ref) async {
    if (kIsWeb) return;

    final String? directoryPath = await FilePicker.platform.getDirectoryPath();

    if (directoryPath == null) return;

    final List<String> allowedExtensions = [
      'pdf',
      'epub',
      'mobi',
      'azw3',
      'fb2',
      'txt',
    ];

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Escaneando: $directoryPath')));
    }

    int count = 0;
    try {
      final dir = Directory(directoryPath);
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final fileName = entity.path.split('/').last;
        if (!ref.read(readerSettingsProvider).showHiddenFiles &&
            fileName.startsWith('.')) {
          continue;
        }

        final ext = fileName.split('.').last.toLowerCase();
        if (allowedExtensions.contains(ext)) {
          await _handleImportedFile(entity.path, fileName, ref);
          count++;
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Escaneamento concluído: $count novos livros encontrados.',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao escanear: $e')));
      }
    }
  }

  Future<void> _scanDevice(BuildContext context, WidgetRef ref) async {
    if (kIsWeb) return;

    if (Platform.isAndroid) {
      if (!await Permission.manageExternalStorage.request().isGranted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Acesse Configurações e permita "Acesso a todos os arquivos" para escanear.',
              ),
              duration: Duration(seconds: 4),
            ),
          );
        }
        await openAppSettings();
        if (!context.mounted) return;
        return;
      }
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Escaneando pastas comuns...')),
    );

    int count = 0;
    final List<String> pathsToScan = [];

    if (Platform.isAndroid) {
      pathsToScan.addAll([
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Documents',
        '/storage/emulated/0/Books',
      ]);
    } else if (Platform.isIOS || Platform.isMacOS) {
      final docsDir = await getApplicationDocumentsDirectory();
      pathsToScan.add(docsDir.path);
    }

    final List<String> allowedExtensions = [
      'pdf',
      'epub',
      'mobi',
      'azw3',
      'fb2',
      'txt',
    ];

    try {
      for (String path in pathsToScan) {
        final dir = Directory(path);
        if (await dir.exists()) {
          await for (final entity in dir.list(
            recursive: true,
            followLinks: false,
          )) {
            if (entity is! File) continue;
            final fileName = entity.path.split('/').last;
            if (!ref.read(readerSettingsProvider).showHiddenFiles &&
                fileName.startsWith('.')) {
              continue;
            }

            final ext = fileName.split('.').last.toLowerCase();
            if (allowedExtensions.contains(ext)) {
              await _handleImportedFile(entity.path, fileName, ref);
              count++;
            }
          }
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Escaneamento concluído: $count novos livros encontrados.',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao escanear: $e')));
      }
    }
  }

  Future<void> _importBook(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'epub', 'mobi', 'azw3', 'fb2', 'txt'],
      withData: true,
    );

    if (result != null) {
      final PlatformFile file = result.files.single;
      final fileName = file.name;
      final extension = fileName.split('.').last.toLowerCase();

      if (kIsWeb) {
        if (file.bytes == null) return;
        if (!context.mounted) return;

        if (extension == 'pdf') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PdfReaderScreen(
                title: fileName,
                filePath: '',
                fileBytes: file.bytes,
              ),
            ),
          );
        } else if (extension == 'epub') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EpubReaderScreen(
                title: fileName,
                filePath: '',
                fileBytes: file.bytes,
              ),
            ),
          );
        } else if (_textExtensions.contains(extension)) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EpubReaderScreen(
                // Use Epub reader as placeholder if it handles mobi or just placeholder screen
                title: fileName,
                filePath: '',
                fileBytes: file.bytes,
              ),
            ),
          );
        }

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Modo Web: Livro aberto temporariamente (não salvo).',
            ),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      final bookId = DateTime.now().millisecondsSinceEpoch.toString();
      final appDir = await getApplicationDocumentsDirectory();
      final booksDir = Directory(p.join(appDir.path, 'books'));
      if (!await booksDir.exists()) await booksDir.create(recursive: true);
      final targetPath = p.join(booksDir.path, '$bookId.$extension');

      if (file.path != null) {
        final sourcePath = file.path!;
        await File(sourcePath).copy(targetPath);
        await _handleImportedFile(targetPath, fileName, ref);
        return;
      }

      final bytes = file.bytes;
      if (bytes == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não foi possível acessar o arquivo selecionado.'),
            ),
          );
        }
        return;
      }

      await File(targetPath).writeAsBytes(bytes, flush: true);
      await _handleImportedFile(targetPath, fileName, ref);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAutoResume();
    });
  }

  void _checkAutoResume() {
    final settings = ref.read(readerSettingsProvider);
    if (settings.lastReadBookId != null) {
      final libraryState = ref.read(libraryProvider);
      libraryState.whenData((books) {
        try {
          final book = books.firstWhere((b) => b.id == settings.lastReadBookId);
          _openBook(context, book);
        } catch (_) {}
      });
    }
  }

  void _openBook(BuildContext context, Book book) {
    switch (book.type) {
      case BookType.pdf:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                PdfReaderScreen(title: book.title, filePath: book.filePath),
          ),
        );
        return;
      case BookType.epub:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                EpubReaderScreen(title: book.title, filePath: book.filePath),
          ),
        );
        return;
      case BookType.txt:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                TxtReaderScreen(title: book.title, filePath: book.filePath),
          ),
        );
        return;
      case BookType.mobi:
      case BookType.fb2:
      case BookType.azw3:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Formato "${book.type.name.toUpperCase()}" ainda não tem leitor dedicado. Em breve!',
            ),
          ),
        );
        return;
    }
  }

  void _handleDelete(BuildContext context, Book book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover livro'),
        content: Text('Deseja realmente remover "${book.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(libraryProvider.notifier).removeBook(book.id);
    }
  }

  Widget _buildLibraryContent(
    BuildContext context,
    List<Book> books,
    ReaderSettingsState settings,
  ) {
    switch (settings.viewMode) {
      case LibraryViewMode.grid:
        if (settings.isWoodShelf) {
          return SliverLayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.crossAxisExtent;
              final crossAxisCount = w >= 650 ? 3 : 2;

              return SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: 0.56,
                  crossAxisSpacing: 14.0,
                  mainAxisSpacing: 8.0,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final book = books[index];
                  return _ShelfBookTile(
                    child: BookCard(
                      book: book,
                      onDelete: () => _handleDelete(context, book),
                      onTap: () => _openBook(context, book),
                    ),
                  );
                }, childCount: books.length),
              );
            },
          );
        }
        return SliverLayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.crossAxisExtent;
            final crossAxisCount = w >= 900
                ? 6
                : w >= 650
                ? 4
                : 3;

            return SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: 0.62,
                crossAxisSpacing: 18.0,
                mainAxisSpacing: 18.0,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final book = books[index];
                return BookCard(
                  book: book,
                  onDelete: () => _handleDelete(context, book),
                  onTap: () => _openBook(context, book),
                );
              }, childCount: books.length),
            );
          },
        );
      case LibraryViewMode.list:
        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final book = books[index];
            return BookListTile(
              book: book,
              onDelete: () => _handleDelete(context, book),
              onTap: () => _openBook(context, book),
            );
          }, childCount: books.length),
        );
      case LibraryViewMode.sideBySide:
        return SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.8,
            crossAxisSpacing: 16.0,
            mainAxisSpacing: 16.0,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            final book = books[index];
            return _SideBySideBookCard(
              book: book,
              onDelete: () => _handleDelete(context, book),
              onTap: () => _openBook(context, book),
            );
          }, childCount: books.length),
        );
    }
  }
}

// Removing redundant _BookCover

// Removing redundant _BookCard and _BookCover

class _GridBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Dark background is already set by Scaffold

    final paint = Paint()
      ..color = Colors.white.withAlpha((0.05 * 255).round())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const gridSize = 40.0;

    // Draw vertical lines
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw horizontal lines
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// _ViewModeButton removed as view mode selection is now in the AppBar

class _SideBySideBookCard extends ConsumerWidget {
  final Book book;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _SideBySideBookCard({
    required this.book,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(readerSettingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      onLongPress: onDelete,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900]?.withAlpha((0.5 * 255).round()) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (isDark ? Colors.white : Colors.black).withAlpha((0.05 * 255).round()),
          ),
        ),
        child: Row(
          children: [
            // Cover Small
            SizedBox(
              width: 45,
              height: 65,
              child: BookCover(
                book: book,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            const SizedBox(width: 14),
            // Book Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (settings.showProgress) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: book.progress,
                              minHeight: 3,
                              backgroundColor: Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).primaryColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(book.progress * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShelfBookTile extends StatelessWidget {
  final Widget child;

  const _ShelfBookTile({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.bottomCenter,
      // The "wood" shelf logic
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // Shelf visual (gradient + shadow)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 18,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4E342E), Color(0xFF3E2723)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black54,
                    offset: Offset(0, -2),
                    blurRadius: 2,
                  ),
                ],
                border: Border(
                  top: BorderSide(
                    color: Color(0xFF6D4C41),
                    width: 1,
                  ), // Light edge
                ),
              ),
            ),
          ),
          // The book sitting on the shelf
          Padding(
            padding: const EdgeInsets.only(
              bottom: 14.0,
              left: 12,
              right: 12,
              top: 12,
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}
