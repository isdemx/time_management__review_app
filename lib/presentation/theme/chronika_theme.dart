import 'package:flutter/material.dart';

class ChronikaTheme {
  static const Color orange = Color(0xFFFFA000);
  static const Color pink = Color(0xFFFF2D73);
  static const Color violet = Color(0xFF7C3CFF);
  static const Color blue = Color(0xFF246BFE);
  static const Color lightBackground = Color(0xFFD2DDEA);
  static const Color lightSurface = Color(0xFFEAF1FA);
  static const Color darkBackground = Color(0xFF0A101B);
  static const Color darkSurface = Color(0xFF121B2A);

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: blue,
      brightness: Brightness.light,
      primary: blue,
      secondary: pink,
      tertiary: orange,
      surface: lightSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: lightBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBackground,
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: lightBackground,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: blue,
        unselectedLabelColor: const Color(0xFF1B2433).withValues(alpha: 0.48),
        indicatorColor: blue,
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: blue,
        foregroundColor: Colors.white,
      ),
    );
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: blue,
      brightness: Brightness.dark,
      primary: blue,
      secondary: pink,
      tertiary: orange,
      surface: darkSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkBackground,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: blue,
        unselectedLabelColor: Colors.white.withValues(alpha: 0.45),
        indicatorColor: blue,
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: blue,
        foregroundColor: Colors.white,
      ),
    );
  }
}
