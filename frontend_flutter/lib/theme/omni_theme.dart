import 'package:flutter/material.dart';

class OmniTheme {
  static const bg950 = Color(0xFF020617);
  static const bg900 = Color(0xFF0F172A);
  static const bg800 = Color(0xFF1E293B);
  static const bg700 = Color(0xFF334155);
  static const accentBlue = Color(0xFF3B82F6);
  static const accentIndigo = Color(0xFF6366F1);
  static const textPrimary = Color(0xFFF8FAFC);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF64748B);
  static const green400 = Color(0xFF4ADE80);
  static const red400 = Color(0xFFF87171);
  static const yellow400 = Color(0xFFFACC15);
  static const orange400 = Color(0xFFFB923C);

  static ThemeData get theme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg950,
    primaryColor: accentBlue,
    colorScheme: const ColorScheme.dark(
      primary: accentBlue,
      secondary: accentIndigo,
      surface: bg900,
      onPrimary: textPrimary,
      onSecondary: textPrimary,
      onSurface: textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: bg950,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Outfit',
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: textPrimary,
        letterSpacing: -0.5,
      ),
      iconTheme: IconThemeData(color: textSecondary),
    ),
    cardTheme: CardTheme(
      color: bg900,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: bg800, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: bg950,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: bg800),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: bg800),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: accentBlue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: red400),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: red400, width: 1.5),
      ),
      labelStyle: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: textMuted,
        letterSpacing: 1.5,
        height: 1.2,
      ),
      hintStyle: const TextStyle(color: bg700, fontSize: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accentBlue,
        foregroundColor: textPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
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
      displayLarge: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: textPrimary),
      displayMedium: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: textPrimary),
      displaySmall: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: textPrimary),
      headlineLarge: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: textPrimary),
      headlineMedium: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: textPrimary),
      headlineSmall: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: textPrimary),
      titleLarge: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: textPrimary),
      titleMedium: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: textPrimary),
      titleSmall: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: textPrimary),
      bodyLarge: TextStyle(color: textPrimary, fontSize: 16),
      bodyMedium: TextStyle(color: textPrimary, fontSize: 14),
      bodySmall: TextStyle(color: textSecondary, fontSize: 12),
      labelLarge: TextStyle(fontWeight: FontWeight.bold, color: textPrimary),
      labelMedium: TextStyle(fontWeight: FontWeight.bold, color: textSecondary),
      labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textMuted, letterSpacing: 1.5),
    ),
    dividerTheme: const DividerThemeData(
      color: bg800,
      thickness: 1,
      space: 1,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: bg900,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: bg900,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: bg800),
      ),
    ),
    tabBarTheme: const TabBarTheme(
      labelColor: accentBlue,
      unselectedLabelColor: textMuted,
      indicatorColor: accentBlue,
      indicatorSize: TabBarIndicatorSize.tab,
      labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      unselectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: bg800,
      selectedColor: accentBlue.withOpacity(0.2),
      labelStyle: const TextStyle(color: textPrimary, fontSize: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),
    useMaterial3: true,
  );
}
