import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app_theme.dart';
import 'package:lumen_reader/features/settings/domain/providers/settings_providers.dart';

final themeProvider = StateNotifierProvider<ThemeNotifier, AppThemeMode>((ref) {
  return ThemeNotifier(ref);
});

class ThemeNotifier extends StateNotifier<AppThemeMode> {
  static const String _boxName = 'settings';
  static const String _key = 'theme_mode';

  final Ref _ref;

  ThemeNotifier(this._ref) : super(AppThemeMode.light) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final box = await Hive.openBox(_boxName);
    final savedMode = box.get(_key, defaultValue: AppThemeMode.light.name);
    state = AppThemeMode.values.firstWhere(
      (e) => e.name == savedMode,
      orElse: () => AppThemeMode.light,
    );
  }

  Future<void> setTheme(AppThemeMode mode) async {
    state = mode;
    final box = await Hive.openBox(_boxName);
    await box.put(_key, mode.name);

    // Sync with Reader Color Mode
    String readerMode;
    switch (mode) {
      case AppThemeMode.light:
        readerMode = 'normal';
        break;
      case AppThemeMode.dark:
        readerMode = 'dark';
        break;
      case AppThemeMode.sepia:
        readerMode = 'sepia';
        break;
      case AppThemeMode.midnight:
        readerMode = 'midnight';
        break;
    }

    _ref
        .read(readerSettingsProvider.notifier)
        .setColorMode(readerMode, syncTheme: false);
  }
}
