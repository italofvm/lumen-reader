import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:device_preview/device_preview.dart';
import 'package:lumen_reader/core/theme/app_theme.dart';
import 'package:lumen_reader/core/theme/theme_provider.dart';
import 'package:lumen_reader/features/library/presentation/screens/library_screen.dart';

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
      home: const LibraryScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
