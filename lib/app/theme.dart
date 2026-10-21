import 'package:flutter/material.dart';

/// Тематизация приложения: Material 3, seed-цвет и светлый/тёмный варианты.
abstract final class AppThemes {
  /// Seed-цвет бренда. Подбирается финально на UX-этапе.
  static const Color seedColor = Color(0xFF3D6EF7);

  /// Светлая тема.
  static ThemeData light() => _build(Brightness.light);

  /// Тёмная тема.
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
    );
  }
}
