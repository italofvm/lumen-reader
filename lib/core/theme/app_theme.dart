import 'package:flutter/material.dart';

enum AppThemeMode { light, dark, sepia, midnight }

class AppTheme {
  static ThemeData getTheme(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return _lightTheme;
      case AppThemeMode.dark:
        return _darkTheme;
      case AppThemeMode.sepia:
        return _sepiaTheme;
      case AppThemeMode.midnight:
        return _midnightTheme;
    }
  }

  static DialogThemeData _dialogTheme(ColorScheme cs) {
    return DialogThemeData(
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: cs.onSurface,
      ),
      contentTextStyle: TextStyle(
        fontSize: 14,
        height: 1.35,
        color: cs.onSurface.withAlpha((0.85 * 255).round()),
      ),
    );
  }

  static BottomSheetThemeData _bottomSheetTheme(ColorScheme cs) {
    return BottomSheetThemeData(
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      modalBackgroundColor: cs.surface,
      modalElevation: 0,
    );
  }

  static InputDecorationTheme _inputTheme(ColorScheme cs) {
    return InputDecorationTheme(
      filled: true,
      fillColor: cs.surfaceContainerHighest.withAlpha((0.35 * 255).round()),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: cs.outline.withAlpha((0.45 * 255).round()),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: cs.outline.withAlpha((0.35 * 255).round()),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cs.primary, width: 1.4),
      ),
      isDense: true,
    );
  }

  static final ThemeData _lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorSchemeSeed: Colors.blue,
    dialogTheme: _dialogTheme(ColorScheme.fromSeed(seedColor: Colors.blue)),
    bottomSheetTheme:
        _bottomSheetTheme(ColorScheme.fromSeed(seedColor: Colors.blue)),
    inputDecorationTheme: _inputTheme(ColorScheme.fromSeed(seedColor: Colors.blue)),
  );

  static final ThemeData _darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF121212),
    cardColor: const Color(0xFF1E1E1E),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF121212),
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white70),
    ),
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF5C6BC0),
      brightness: Brightness.dark,
      surface: const Color(0xFF1E1E1E),
      onSurface: Colors.white,
    ),
    dialogTheme: _dialogTheme(
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF5C6BC0),
        brightness: Brightness.dark,
        surface: const Color(0xFF1E1E1E),
        onSurface: Colors.white,
      ),
    ),
    bottomSheetTheme: _bottomSheetTheme(
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF5C6BC0),
        brightness: Brightness.dark,
        surface: const Color(0xFF1E1E1E),
        onSurface: Colors.white,
      ),
    ),
    inputDecorationTheme: _inputTheme(
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF5C6BC0),
        brightness: Brightness.dark,
        surface: const Color(0xFF1E1E1E),
        onSurface: Colors.white,
      ),
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Color(0xFFE0E0E0)),
    ),
    iconTheme: const IconThemeData(color: Colors.white70),
  );

  static final ThemeData _sepiaTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF4ECD8),
    appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFE8DDC0)),
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.brown,
      brightness: Brightness.light,
      surface: const Color(0xFFF4ECD8),
    ),
    dialogTheme: _dialogTheme(
      ColorScheme.fromSeed(
        seedColor: Colors.brown,
        brightness: Brightness.light,
        surface: const Color(0xFFF4ECD8),
      ),
    ),
    bottomSheetTheme: _bottomSheetTheme(
      ColorScheme.fromSeed(
        seedColor: Colors.brown,
        brightness: Brightness.light,
        surface: const Color(0xFFF4ECD8),
      ),
    ),
    inputDecorationTheme: _inputTheme(
      ColorScheme.fromSeed(
        seedColor: Colors.brown,
        brightness: Brightness.light,
        surface: const Color(0xFFF4ECD8),
      ),
    ),
  );

  static final ThemeData _midnightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Colors.black,
    appBarTheme: const AppBarTheme(backgroundColor: Colors.black),
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
      surface: Colors.black,
    ),
    dialogTheme: _dialogTheme(
      ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
        surface: Colors.black,
      ),
    ),
    bottomSheetTheme: _bottomSheetTheme(
      ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
        surface: Colors.black,
      ),
    ),
    inputDecorationTheme: _inputTheme(
      ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
        surface: Colors.black,
      ),
    ),
  );
}
