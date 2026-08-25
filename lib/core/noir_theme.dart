import 'package:flutter/material.dart';

class NoirPalette {
  NoirPalette._();

  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF0D0D0D);
  static const Color surfaceHigh = Color(0xFF181818);
  static const Color textPrimary = Color(0xFFF5F5F0);
  static const Color textDim = Color(0xFF8A8A85);
  static const Color border = Color(0xFF2E2E2E);
  static const Color boardLight = Color(0xFFE8E8E2);
  static const Color boardDark = Color(0xFF151515);
  static const Color highlightDot = Color(0x99BDBDBD);
  static const Color lastMoveTint = Color(0x26FFFFFF);
}

class NoirTheme {
  NoirTheme._();

  static ThemeData get dark {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: NoirPalette.background,
      colorScheme: const ColorScheme.dark(
        primary: Colors.white,
        onPrimary: Colors.black,
        secondary: NoirPalette.textDim,
        onSecondary: Colors.black,
        surface: NoirPalette.surface,
        onSurface: NoirPalette.textPrimary,
        error: Color(0xFFBBBBBB),
        outline: NoirPalette.border,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: NoirPalette.background,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: NoirPalette.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 3,
        ),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: NoirPalette.textPrimary,
        displayColor: NoirPalette.textPrimary,
      ),
      dividerColor: NoirPalette.border,
      splashColor: Colors.white10,
      highlightColor: Colors.white24,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            fontSize: 14,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: NoirPalette.textPrimary,
          side: const BorderSide(color: NoirPalette.border),
          minimumSize: const Size.fromHeight(48),
          textStyle: const TextStyle(letterSpacing: 1.5, fontSize: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Colors.white,
        linearTrackColor: NoirPalette.surfaceHigh,
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: Colors.white,
        thumbColor: Colors.white,
      ),
    );
  }
}
