import 'package:flutter/material.dart';

class OmniTheme {
  static const primary = Color(0xFF8B5CF6);
  static const primaryLight = Color(0xFFA78BFA);
  static const primaryDark = Color(0xFF6D28D9);
  static const secondary = Color(0xFF06B6D4);
  static const tertiary = Color(0xFFEC4899);
  static const accent = Color(0xFFF43F5E);

  static const bg950 = Color(0xFF0A0A1A);
  static const bg900 = Color(0xFF12122A);
  static const bg800 = Color(0xFF1E1E3A);
  static const bg700 = Color(0xFF2D2D4A);
  static const textPrimary = Color(0xFFF1F0FB);
  static const textSecondary = Color(0xFFA5A3C9);
  static const textMuted = Color(0xFF6B6999);
  static const success = Color(0xFF34D399);
  static const error = Color(0xFFFB7185);
  static const warning = Color(0xFFFBBF24);
  static const info = Color(0xFF38BDF8);

  static const accentBlue = primary;
  static const accentIndigo = primaryDark;
  static const green400 = success;
  static const red400 = error;
  static const yellow400 = warning;
  static const orange400 = Color(0xFFFB923C);

  static List<Color> get primaryGradient => [primary, primaryLight];
  static List<Color> get accentGradient => [primary, secondary];
  static List<Color> get sunsetGradient => [primary, tertiary];
  static List<Color> get bgGradient => [bg950, const Color(0xFF140A26)];

  static ThemeData get theme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg950,
    primaryColor: primary,
    colorScheme: const ColorScheme.dark(
      primary: primary,
      secondary: secondary,
      tertiary: tertiary,
      surface: bg900,
      onPrimary: textPrimary,
      onSecondary: textPrimary,
      onTertiary: textPrimary,
      onSurface: textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Outfit',
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: textPrimary,
        letterSpacing: -0.5,
      ),
      iconTheme: IconThemeData(color: textSecondary),
    ),
    cardTheme: CardThemeData(
      color: bg900,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: bg800.withOpacity(0.5), width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: bg800.withOpacity(0.3),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: bg800.withOpacity(0.5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: bg800.withOpacity(0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: error, width: 1.5),
      ),
      labelStyle: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: textMuted,
        letterSpacing: 1.5,
        height: 1.2,
      ),
      hintStyle: TextStyle(color: textMuted.withOpacity(0.5), fontSize: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: textPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: textSecondary,
        textStyle: const TextStyle(fontSize: 14),
      ),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: textPrimary, fontSize: 34),
      displayMedium: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: textPrimary, fontSize: 28),
      displaySmall: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: textPrimary, fontSize: 24),
      headlineLarge: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: textPrimary, fontSize: 22),
      headlineMedium: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: textPrimary, fontSize: 20),
      headlineSmall: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: textPrimary, fontSize: 18),
      titleLarge: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: textPrimary, fontSize: 20),
      titleMedium: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: textPrimary, fontSize: 18),
      titleSmall: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: textPrimary, fontSize: 16),
      bodyLarge: TextStyle(color: textPrimary, fontSize: 18),
      bodyMedium: TextStyle(color: textPrimary, fontSize: 16),
      bodySmall: TextStyle(color: textSecondary, fontSize: 14),
      labelLarge: TextStyle(fontWeight: FontWeight.bold, color: textPrimary, fontSize: 16),
      labelMedium: TextStyle(fontWeight: FontWeight.bold, color: textSecondary, fontSize: 14),
      labelSmall: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textMuted, letterSpacing: 1.5),
    ),
    dividerTheme: DividerThemeData(
      color: bg800.withOpacity(0.5),
      thickness: 1,
      space: 1,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: bg900,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: bg900,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: bg800.withOpacity(0.5)),
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: primary,
      unselectedLabelColor: textMuted,
      indicatorColor: primary,
      indicatorSize: TabBarIndicatorSize.tab,
      labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      unselectedLabelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: bg800,
      selectedColor: primary.withOpacity(0.2),
      labelStyle: const TextStyle(color: textPrimary, fontSize: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),
    useMaterial3: true,
  );
}
