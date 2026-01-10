import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:lumen_reader/core/services/cloud/google_drive_service.dart';
import 'package:lumen_reader/core/theme/app_theme.dart';
import 'package:lumen_reader/core/theme/theme_provider.dart';

enum LibraryViewMode { grid, list, sideBySide }

class ReaderSettingsState {
  final double fontSize;
  final String fontFamily;
  final double lineHeight;
  final double brightness;
  final double zoom;
  final String colorMode; // 'normal', 'sepia', 'paper', 'dark', 'midnight'
  final bool onboardingSeen;
  final bool isCloudSyncEnabled;
  final bool isCloudSyncLoading;
  final String? cloudAccountEmail;
  final bool isHorizontal;
  final String pageTransition;
  final bool isDarkMode;
  final bool isWoodShelf;
  final bool showProgress;
  final bool showHiddenFiles;
  final LibraryViewMode viewMode;
  final String? lastReadBookId;
  final String? mainDirectory;
  final String? mainDirectoryUri;
  final bool autoImportEnabled;

  final bool dailyReminderEnabled;
  final int dailyReminderHour;
  final int dailyReminderMinute;

  const ReaderSettingsState({
    required this.fontSize,
    required this.fontFamily,
    required this.lineHeight,
    this.brightness = 0.5,
    this.zoom = 1.0,
    this.colorMode = 'normal',
    this.onboardingSeen = false,
    this.isCloudSyncEnabled = false,
    this.isCloudSyncLoading = false,
    this.cloudAccountEmail,
    this.isHorizontal = false,
    this.pageTransition = 'slide', // 'slide', 'fade', 'none'
    this.isDarkMode = false,
    this.isWoodShelf = false,
    this.showProgress = false,
    this.showHiddenFiles = false,
    this.viewMode = LibraryViewMode.grid,
    this.lastReadBookId,
    this.mainDirectory,
    this.mainDirectoryUri,
    this.autoImportEnabled = false,
    this.dailyReminderEnabled = false,
    this.dailyReminderHour = 20,
    this.dailyReminderMinute = 0,
  });

  ReaderSettingsState copyWith({
    double? fontSize,
    String? fontFamily,
    double? lineHeight,
    double? brightness,
    double? zoom,
    String? colorMode,
    bool? onboardingSeen,
    bool? isCloudSyncEnabled,
    bool? isCloudSyncLoading,
    String? cloudAccountEmail,
    bool? isHorizontal,
    String? pageTransition,
    bool? isDarkMode,
    bool? isWoodShelf,
    bool? showProgress,
    bool? showHiddenFiles,
    LibraryViewMode? viewMode,
    String? lastReadBookId,
    String? mainDirectory,
    String? mainDirectoryUri,
    bool? autoImportEnabled,
    bool? dailyReminderEnabled,
    int? dailyReminderHour,
    int? dailyReminderMinute,
  }) {
    return ReaderSettingsState(
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      lineHeight: lineHeight ?? this.lineHeight,
      brightness: brightness ?? this.brightness,
      zoom: zoom ?? this.zoom,
      colorMode: colorMode ?? this.colorMode,
      onboardingSeen: onboardingSeen ?? this.onboardingSeen,
      isCloudSyncEnabled: isCloudSyncEnabled ?? this.isCloudSyncEnabled,
      isCloudSyncLoading: isCloudSyncLoading ?? this.isCloudSyncLoading,
      cloudAccountEmail: cloudAccountEmail ?? this.cloudAccountEmail,
      isHorizontal: isHorizontal ?? this.isHorizontal,
      pageTransition: pageTransition ?? this.pageTransition,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      isWoodShelf: isWoodShelf ?? this.isWoodShelf,
      showProgress: showProgress ?? this.showProgress,
      showHiddenFiles: showHiddenFiles ?? this.showHiddenFiles,
      viewMode: viewMode ?? this.viewMode,
      lastReadBookId: lastReadBookId ?? this.lastReadBookId,
      mainDirectory: mainDirectory ?? this.mainDirectory,
      mainDirectoryUri: mainDirectoryUri ?? this.mainDirectoryUri,
      autoImportEnabled: autoImportEnabled ?? this.autoImportEnabled,
      dailyReminderEnabled: dailyReminderEnabled ?? this.dailyReminderEnabled,
      dailyReminderHour: dailyReminderHour ?? this.dailyReminderHour,
      dailyReminderMinute: dailyReminderMinute ?? this.dailyReminderMinute,
    );
  }
}

class ReaderSettingsNotifier extends StateNotifier<ReaderSettingsState> {
  static const String _boxName = 'settings';
  static const String _keyFontSize = 'font_size';
  static const String _keyFontFamily = 'font_family';
  static const String _keyLineHeight = 'line_height';
  static const String _keyCloudSync = 'cloud_sync_enabled';
  static const String _keyColorMode = 'color_mode';
  static const String _keyOnboardingSeen = 'onboarding_seen';
  static const String _keyIsHorizontal = 'is_horizontal';
  static const String _keyPageTransition = 'page_transition';
  static const String _keyIsDarkMode = 'is_dark_mode';
  static const String _keyIsWoodShelf = 'is_wood_shelf';
  static const String _keyShowProgress = 'show_progress';
  static const String _keyShowHiddenFiles = 'show_hidden_files';
  static const String _keyViewMode = 'view_mode';
  static const String _keyLastReadBookId = 'last_read_book_id';
  static const String _keyMainDirectory = 'main_directory';
  static const String _keyMainDirectoryUri = 'main_directory_uri';
  static const String _keyAutoImportEnabled = 'auto_import_enabled';
  static const String _keyDailyReminderEnabled = 'daily_reminder_enabled';
  static const String _keyDailyReminderHour = 'daily_reminder_hour';
  static const String _keyDailyReminderMinute = 'daily_reminder_minute';

  final Ref _ref;
  final GoogleDriveService _driveService = GoogleDriveService();

  ReaderSettingsNotifier(this._ref)
    : super(
        const ReaderSettingsState(
          fontSize: 14.0,
          fontFamily: 'Merriweather',
          lineHeight: 1.5,
          brightness: 0.5,
          zoom: 1.0,
          colorMode: 'normal',
          isCloudSyncEnabled: false,
          isCloudSyncLoading: false,
          cloudAccountEmail: null,
          isHorizontal: false,
          pageTransition: 'slide',
          isDarkMode: false,
          isWoodShelf: false,
          showProgress: false,
          showHiddenFiles: false,
          viewMode: LibraryViewMode.grid,
          lastReadBookId: null,
          dailyReminderEnabled: false,
          dailyReminderHour: 20,
          dailyReminderMinute: 0,
        ),
      ) {
    _loadSettings();
    _initBrightness();
  }

  Future<void> _initBrightness() async {
    try {
      final brightness = await ScreenBrightness().application;
      state = state.copyWith(brightness: brightness);
    } catch (_) {}
  }

  Future<void> _loadSettings() async {
    final box = await Hive.openBox(_boxName);
    final fontSize = box.get(_keyFontSize, defaultValue: 14.0);
    final rawFontFamily = box.get(_keyFontFamily, defaultValue: 'Merriweather');
    final String fontFamily = rawFontFamily == 'Serif' ? 'Merriweather' : rawFontFamily;
    final lineHeight = box.get(_keyLineHeight, defaultValue: 1.5);
    final isCloudSyncEnabled = box.get(_keyCloudSync, defaultValue: false);
    final colorMode = box.get(_keyColorMode, defaultValue: 'normal');
    final onboardingSeen = box.get(_keyOnboardingSeen, defaultValue: false);
    final isHorizontal = box.get(_keyIsHorizontal, defaultValue: false);
    final pageTransition = box.get(_keyPageTransition, defaultValue: 'slide');
    final isDarkMode = box.get(_keyIsDarkMode, defaultValue: false);
    final isWoodShelf = box.get(_keyIsWoodShelf, defaultValue: false);
    final showProgress = box.get(_keyShowProgress, defaultValue: false);
    final showHiddenFiles = box.get(_keyShowHiddenFiles, defaultValue: false);
    final lastReadBookId = box.get(_keyLastReadBookId);
    final mainDirectory = box.get(_keyMainDirectory);
    final mainDirectoryUri = box.get(_keyMainDirectoryUri);
    final autoImportEnabled =
        box.get(_keyAutoImportEnabled, defaultValue: false) as bool;
    final dailyReminderEnabled =
        box.get(_keyDailyReminderEnabled, defaultValue: false) as bool;
    final dailyReminderHour =
        (box.get(_keyDailyReminderHour, defaultValue: 20) as int).clamp(0, 23);
    final dailyReminderMinute =
        (box.get(_keyDailyReminderMinute, defaultValue: 0) as int).clamp(0, 59);

    String? cloudEmail;
    var cloudEnabled = isCloudSyncEnabled as bool;
    if (cloudEnabled) {
      final account = await _driveService.signInSilently();
      cloudEmail = account?.email;
      if (account == null) {
        cloudEnabled = false;
        await box.put(_keyCloudSync, false);
      }
    }

    state = state.copyWith(
      fontSize: fontSize,
      fontFamily: fontFamily,
      lineHeight: lineHeight,
      onboardingSeen: onboardingSeen,
      isCloudSyncEnabled: cloudEnabled,
      isCloudSyncLoading: false,
      cloudAccountEmail: cloudEmail,
      colorMode: colorMode,
      isHorizontal: isHorizontal,
      pageTransition: pageTransition,
      isDarkMode: isDarkMode,
      isWoodShelf: isWoodShelf,
      showProgress: showProgress,
      showHiddenFiles: showHiddenFiles,
      viewMode: LibraryViewMode.values.firstWhere(
        (e) => e.toString() == box.get(_keyViewMode),
        orElse: () => LibraryViewMode.grid,
      ),
      lastReadBookId: lastReadBookId,
      mainDirectory: mainDirectory,
      mainDirectoryUri: mainDirectoryUri,
      autoImportEnabled: autoImportEnabled,
      dailyReminderEnabled: dailyReminderEnabled,
      dailyReminderHour: dailyReminderHour,
      dailyReminderMinute: dailyReminderMinute,
    );
  }

  Future<void> setDailyReminderEnabled(bool enabled) async {
    state = state.copyWith(dailyReminderEnabled: enabled);
    final box = await Hive.openBox(_boxName);
    await box.put(_keyDailyReminderEnabled, enabled);
  }

  Future<void> setDailyReminderTime({required int hour, required int minute}) async {
    final h = hour.clamp(0, 23);
    final m = minute.clamp(0, 59);
    state = state.copyWith(dailyReminderHour: h, dailyReminderMinute: m);
    final box = await Hive.openBox(_boxName);
    await box.put(_keyDailyReminderHour, h);
    await box.put(_keyDailyReminderMinute, m);
  }

  Future<void> setOnboardingSeen(bool value) async {
    state = state.copyWith(onboardingSeen: value);
    final box = await Hive.openBox(_boxName);
    await box.put(_keyOnboardingSeen, value);
  }

  void _setCloudLoading(bool value) {
    state = state.copyWith(isCloudSyncLoading: value);
  }

  Future<void> updateMainDirectory(String? path) async {
    final box = await Hive.openBox(_boxName);
    if (path == null || path.trim().isEmpty) {
      await box.delete(_keyMainDirectory);
      state = state.copyWith(mainDirectory: null);
      return;
    }

    await box.put(_keyMainDirectory, path);
    state = state.copyWith(mainDirectory: path);
  }

  Future<void> updateMainDirectoryUri(String? uri) async {
    final box = await Hive.openBox(_boxName);
    if (uri == null || uri.trim().isEmpty) {
      await box.delete(_keyMainDirectoryUri);
      state = state.copyWith(mainDirectoryUri: null);
      return;
    }

    await box.put(_keyMainDirectoryUri, uri);
    state = state.copyWith(mainDirectoryUri: uri);
  }

  Future<void> setAutoImportEnabled(bool enabled) async {
    final box = await Hive.openBox(_boxName);
    await box.put(_keyAutoImportEnabled, enabled);
    state = state.copyWith(autoImportEnabled: enabled);
  }

  Future<void> setFontSize(double size) async {
    state = state.copyWith(fontSize: size);
    final box = await Hive.openBox(_boxName);
    await box.put(_keyFontSize, size);
  }

  Future<void> setFontFamily(String family) async {
    state = state.copyWith(fontFamily: family);
    final box = await Hive.openBox(_boxName);
    await box.put(_keyFontFamily, family);
  }

  Future<void> setLineHeight(double height) async {
    state = state.copyWith(lineHeight: height);
    final box = await Hive.openBox(_boxName);
    await box.put(_keyLineHeight, height);
  }

  Future<void> setBrightness(double value) async {
    state = state.copyWith(brightness: value);
    try {
      await ScreenBrightness().setApplicationScreenBrightness(value);
    } catch (_) {}
  }

  void setZoom(double value) {
    state = state.copyWith(zoom: value);
  }

  Future<void> setColorMode(String mode, {bool syncTheme = true}) async {
    state = state.copyWith(colorMode: mode);
    final box = await Hive.openBox(_boxName);
    await box.put(_keyColorMode, mode);

    if (syncTheme) {
      AppThemeMode? themeMode;
      switch (mode) {
        case 'normal':
        case 'paper':
          themeMode = AppThemeMode.light;
          break;
        case 'sepia':
          themeMode = AppThemeMode.sepia;
          break;
        case 'dark':
          themeMode = AppThemeMode.dark;
          break;
        case 'midnight':
          themeMode = AppThemeMode.midnight;
          break;
      }

      if (themeMode != null) {
        _ref.read(themeProvider.notifier).setTheme(themeMode);
      }
    }
  }

  Future<void> updateIsDarkMode(bool value) async {
    final box = await Hive.openBox(_boxName);
    await box.put(_keyIsDarkMode, value);
    state = state.copyWith(isDarkMode: value);
  }

  Future<void> updateIsWoodShelf(bool value) async {
    final box = await Hive.openBox(_boxName);
    await box.put(_keyIsWoodShelf, value);
    state = state.copyWith(isWoodShelf: value);
  }

  Future<void> updateShowProgress(bool value) async {
    final box = await Hive.openBox(_boxName);
    await box.put(_keyShowProgress, value);
    state = state.copyWith(showProgress: value);
  }

  Future<void> updateShowHiddenFiles(bool value) async {
    final box = await Hive.openBox(_boxName);
    await box.put(_keyShowHiddenFiles, value);
    state = state.copyWith(showHiddenFiles: value);
  }

  Future<void> setViewMode(LibraryViewMode mode) async {
    state = state.copyWith(viewMode: mode);
    final box = await Hive.openBox(_boxName);
    await box.put(_keyViewMode, mode.toString());
  }

  Future<void> setLastReadBookId(String? bookId) async {
    state = state.copyWith(lastReadBookId: bookId);
    final box = await Hive.openBox(_boxName);
    if (bookId == null) {
      await box.delete(_keyLastReadBookId);
    } else {
      await box.put(_keyLastReadBookId, bookId);
    }
  }

  Future<void> setIsHorizontal(bool horizontal) async {
    state = state.copyWith(isHorizontal: horizontal);
    final box = await Hive.openBox(_boxName);
    await box.put(_keyIsHorizontal, horizontal);
  }

  Future<void> setPageTransition(String transition) async {
    state = state.copyWith(pageTransition: transition);
    final box = await Hive.openBox(_boxName);
    await box.put(_keyPageTransition, transition);
  }

  Future<bool> toggleCloudSync(bool enabled) async {
    if (state.isCloudSyncLoading) return false;
    _setCloudLoading(true);
    final previousEnabled = state.isCloudSyncEnabled;
    final previousEmail = state.cloudAccountEmail;

    try {
      final box = await Hive.openBox(_boxName);

      if (enabled) {
        final account = await _driveService.signIn();
        if (account == null) {
          state = state.copyWith(
            isCloudSyncEnabled: previousEnabled,
            cloudAccountEmail: previousEmail,
          );
          return false;
        }

        state = state.copyWith(
          isCloudSyncEnabled: true,
          cloudAccountEmail: account.email,
        );
        await box.put(_keyCloudSync, true);
        return true;
      } else {
        await _driveService.signOut();
        state = state.copyWith(
          isCloudSyncEnabled: false,
          cloudAccountEmail: null,
        );
        await box.put(_keyCloudSync, false);
        return true;
      }
    } catch (_) {
      state = state.copyWith(
        isCloudSyncEnabled: previousEnabled,
        cloudAccountEmail: previousEmail,
      );
      return false;
    } finally {
      _setCloudLoading(false);
    }
  }
}

final readerSettingsProvider =
    StateNotifierProvider<ReaderSettingsNotifier, ReaderSettingsState>((ref) {
      return ReaderSettingsNotifier(ref);
    });
