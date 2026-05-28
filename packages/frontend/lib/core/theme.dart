import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color primary = Color(0xFF6750A4);
  static const Color secondary = Color(0xFF7C4DFF);
  static const Color bgDark = Color(0xFF0F0F1A);
  static const Color bgCard = Color(0xFF1A1A2E);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textMuted = Color(0xFFB0B0B0);
  static const Color accentBlue = Color(0xFF7C4DFF);
  static const Color red400 = Color(0xFFEF5350);

  static final ThemeData light = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: primary,
    brightness: Brightness.light,
  );

  static final ThemeData dark = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: primary,
    brightness: Brightness.dark,
  );
}
