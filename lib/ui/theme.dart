import 'package:flutter/material.dart';

class AppTheme {
  static const seed = Color(0xFF0468D7);

  static ThemeData light() => _base(ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light));
  static ThemeData dark() => _base(ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark));

  static ThemeData _base(ColorScheme scheme) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
      scaffoldBackgroundColor: scheme.surface,
      cardTheme: CardThemeData(elevation: 0, color: scheme.surfaceContainerLow, shape: shape, margin: EdgeInsets.zero),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18), textStyle: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18)),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14))),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: scheme.outlineVariant)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: scheme.outlineVariant)),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.5), space: 1),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}
