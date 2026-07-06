import 'package:flutter/material.dart';

/// Color palette for one brightness mode (light or dark).
/// Primary stays the same deep blue in both modes for brand consistency;
/// backgrounds/text invert appropriately for dark mode.
///
/// Public (not prefixed with `_`) so screens/widgets across the app can
/// type their `colors` parameters as `AppPalette` instead of `dynamic` —
/// this keeps compile-time checking on every `colors.xxx` access.
class AppPalette {
  final Color primary;
  final Color primaryLight;
  final Color primaryPale;
  final Color bgApp;
  final Color bgCard;
  final Color bgSoft;
  final Color border;
  final Color textMain;
  final Color textSub;
  final Color green;
  final Color greenBg;
  final Color red;
  final Color redBg;

  const AppPalette({
    required this.primary,
    required this.primaryLight,
    required this.primaryPale,
    required this.bgApp,
    required this.bgCard,
    required this.bgSoft,
    required this.border,
    required this.textMain,
    required this.textSub,
    required this.green,
    required this.greenBg,
    required this.red,
    required this.redBg,
  });
}

const _light = AppPalette(
  primary: Color(0xFF1E3A5F),
  primaryLight: Color(0xFF2E5C8A),
  primaryPale: Color(0xFFDCE6F2),
  bgApp: Color(0xFFF4F7FB),
  bgCard: Color(0xFFFFFFFF),
  bgSoft: Color(0xFFEAF0F8),
  border: Color(0xFFD7E2EF),
  textMain: Color(0xFF1B2A3A),
  textSub: Color(0xFF5A7290),
  green: Color(0xFF1F8A4C),
  greenBg: Color(0xFFE6F4EB),
  red: Color(0xFFC43D3D),
  redBg: Color(0xFFFBEAEA),
);

const _dark = AppPalette(
  primary: Color(0xFF6C93BF), // lighter blue so it stays legible on dark bg
  primaryLight: Color(0xFF8BAAD1),
  primaryPale: Color(0xFF223447),
  bgApp: Color(0xFF11181F), // near-black with a slight blue tint
  bgCard: Color(0xFF1A232D),
  bgSoft: Color(0xFF212C38),
  border: Color(0xFF2E3B49),
  textMain: Color(0xFFE7EEF5),
  textSub: Color(0xFF9AB0C4),
  green: Color(0xFF3FBE73),
  greenBg: Color(0xFF163524),
  red: Color(0xFFE0645F),
  redBg: Color(0xFF3A1F1F),
);

/// Static-looking accessors kept for backward compatibility with screens
/// that were written against `AppColors.xxx` directly (light mode values).
/// New/updated screens should prefer `AppColors.of(context).xxx` so they
/// react correctly to dark mode.
class AppColors {
  static const Color primary = _light.primary;
  static const Color primaryLight = _light.primaryLight;
  static const Color primaryPale = _light.primaryPale;
  static const Color bgApp = _light.bgApp;
  static const Color bgCard = _light.bgCard;
  static const Color bgSoft = _light.bgSoft;
  static const Color border = _light.border;
  static const Color textMain = _light.textMain;
  static const Color textSub = _light.textSub;
  static const Color green = _light.green;
  static const Color greenBg = _light.greenBg;
  static const Color red = _light.red;
  static const Color redBg = _light.redBg;

  /// Context-aware palette that switches automatically with the device's
  /// light/dark setting (or the app's manual override, if added later).
  static AppPalette of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? _dark : _light;
  }
}

class AppTheme {
  static ThemeData get light => _buildTheme(_light, Brightness.light);
  static ThemeData get dark => _buildTheme(_dark, Brightness.dark);

  static ThemeData _buildTheme(AppPalette p, Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      // No custom fontFamily set: Flutter falls back to Android's
      // default font (Roboto/Noto), which renders Arabic correctly
      // with no extra setup.
      scaffoldBackgroundColor: p.bgApp,
      colorScheme: ColorScheme.fromSeed(
        seedColor: p.primary,
        brightness: brightness,
        primary: p.primary,
        secondary: p.primaryLight,
        surface: p.bgCard,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.bgCard,
        foregroundColor: p.primary,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: p.bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: p.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.bgApp,
        hintStyle: TextStyle(color: p.textSub),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.border, width: 1.4),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.border, width: 1.4),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.primary, width: 1.6),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      textTheme: TextTheme(
        bodyMedium: TextStyle(color: p.textMain, fontSize: 14),
      ),
    );
  }
}
