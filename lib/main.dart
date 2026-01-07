import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:device_preview/device_preview.dart';
import 'package:lumen_reader/core/theme/app_theme.dart';
import 'package:lumen_reader/core/theme/theme_provider.dart';
import 'package:lumen_reader/core/services/update/app_update_service.dart';
import 'package:lumen_reader/features/library/presentation/screens/library_screen.dart';
import 'package:lumen_reader/features/reader/presentation/screens/pdf_reader_screen.dart';
import 'package:lumen_reader/features/reader/presentation/screens/epub_reader_screen.dart';
import 'package:path/path.dart' as p;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();

  runApp(
    ProviderScope(
      child: DevicePreview(
        enabled: !kReleaseMode, // Disable DevicePreview in release mode
        builder: (context) => const LumenReaderApp(),
      ),
    ),
  );
}

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };
}

class LumenReaderApp extends ConsumerWidget {
  const LumenReaderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      scrollBehavior: AppScrollBehavior(), // Enable mouse dragging
      title: 'Lumen Reader',
      locale: DevicePreview.locale(context), // Add locale
      builder: DevicePreview.appBuilder, // Add builder
      theme: AppTheme.getTheme(themeMode),
      navigatorKey: _OpenFileCoordinator.navigatorKey,
      home: const _OpenFileCoordinator(child: LibraryScreen()),
      debugShowCheckedModeBanner: false,
    );
  }
}

class _OpenFileCoordinator extends ConsumerStatefulWidget {
  final Widget child;
  const _OpenFileCoordinator({required this.child});

  static final navigatorKey = GlobalKey<NavigatorState>();
  static const _channel = MethodChannel('lumen_reader/open_file');

  @override
  ConsumerState<_OpenFileCoordinator> createState() => _OpenFileCoordinatorState();
}

class _OpenFileCoordinatorState extends ConsumerState<_OpenFileCoordinator> {
  bool _initialized = false;
  bool _didCheckUpdates = false;

  @override
  void initState() {
    super.initState();
    _initOpenFileHandling();
    _initUpdateCheck();
  }

  void _initUpdateCheck() {
    if (_didCheckUpdates) return;
    _didCheckUpdates = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _OpenFileCoordinator.navigatorKey.currentContext;
      if (ctx == null) return;
      AppUpdateService().checkAndPrompt(ctx);
    });
  }

  Future<void> _initOpenFileHandling() async {
    if (_initialized) return;
    _initialized = true;

    _OpenFileCoordinator._channel.setMethodCallHandler((call) async {
      if (call.method == 'onFileOpen') {
        final path = call.arguments as String?;
        if (path != null && path.trim().isNotEmpty) {
          _openFile(path);
        }
      }
    });

    try {
      final initial = await _OpenFileCoordinator._channel.invokeMethod<String>('getInitialFile');
      if (initial != null && initial.trim().isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _openFile(initial);
        });
      }
    } catch (_) {}
  }

  void _openFile(String filePath) {
    final nav = _OpenFileCoordinator.navigatorKey.currentState;
    if (nav == null) return;

    final ext = p.extension(filePath).toLowerCase();
    final title = p.basename(filePath);

    if (ext == '.pdf') {
      nav.push(
        MaterialPageRoute(
          builder: (_) => PdfReaderScreen(title: title, filePath: filePath),
        ),
      );
      return;
    }

    if (ext == '.epub') {
      nav.push(
        MaterialPageRoute(
          builder: (_) => EpubReaderScreen(title: title, filePath: filePath),
        ),
      );
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
