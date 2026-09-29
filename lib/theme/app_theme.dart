import 'package:flutter/material.dart';

/// Warm, soft palette from the design brief + a matching dark mode.
/// cream #fff5ef | coral red #e2506b | blush pink #f6c4cf | dark plum #4a2b35
class AppTheme {
  // ---- Brand colors (identical in both modes) ----
  static const Color cream = Color(0xFFFFF5EF);
  static const Color coral = Color(0xFFE2506B);
  static const Color blush = Color(0xFFF6C4CF);
  static const Color plum = Color(0xFF4A2B35);

  // Dark-mode variants: deep plum background, cream text, softened coral.
  static const Color darkBg = Color(0xFF241318);
  static const Color darkSurface = Color(0xFF33202A);
  static const Color darkText = Color(0xFFFFE9E0);
  static const Color darkCoral = Color(0xFFF06A82);

  /// Handwritten font for the speech bubble + counter pill.
  /// Bundled as an asset so it works offline; google_fonts is not required.
  static const String handwritingFamily = 'Caveat';

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: cream,
        colorScheme: const ColorScheme.light(
          primary: coral,
          onPrimary: Colors.white,
          secondary: blush,
          onSecondary: plum,
          surface: Color(0xFFFFFBF7),
          onSurface: plum,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: plum),
          bodyMedium: TextStyle(color: plum),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: cream,
          foregroundColor: plum,
          elevation: 0,
          centerTitle: true,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? coral : Colors.white,
          ),
          trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? blush : const Color(0xFFE8DAD2),
          ),
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkBg,
        colorScheme: const ColorScheme.dark(
          primary: darkCoral,
          onPrimary: Colors.white,
          secondary: blush,
          onSecondary: plum,
          surface: darkSurface,
          onSurface: darkText,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: darkText),
          bodyMedium: TextStyle(color: darkText),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: darkSurface,
          foregroundColor: darkText,
          elevation: 0,
          centerTitle: true,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? darkCoral : Colors.white,
          ),
          trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? coral : const Color(0xFF4A3038),
          ),
        ),
      );
}

/// Small helpers so widgets can ask "which palette am I on?"
extension ThemeX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get ink => isDark ? AppTheme.darkText : AppTheme.plum;
  Color get accent => isDark ? AppTheme.darkCoral : AppTheme.coral;
  Color get cardBg => isDark ? AppTheme.darkSurface : Colors.white;
  Color get roomWall => isDark ? const Color(0xFF2E1A22) : const Color(0xFFFFEDE2);
  Color get roomFloor => isDark ? const Color(0xFF3B2430) : const Color(0xFFF9DFCE);
}
