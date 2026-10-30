import 'package:flutter/material.dart';

class AppColors {
  // Deep Cyber Dark Palette
  static const Color background = Color(0xFF070A12);
  static const Color surface = Color(0xFF0F172A);
  static const Color surfaceElevated = Color(0xFF1E293B);
  static const Color surfaceHighlight = Color(0xFF283548);
  
  // Threat & Status Colors
  static const Color cyberCyan = Color(0xFF00F0FF);
  static const Color threatRed = Color(0xFFFF2A6D);
  static const Color threatRedGlow = Color(0x33FF2A6D);
  static const Color warningAmber = Color(0xFFFFB300);
  static const Color warningAmberGlow = Color(0x33FFB300);
  static const Color verifiedGreen = Color(0xFF05FFA1);
  static const Color verifiedGreenGlow = Color(0x3305FFA1);
  
  // Accent & Tech Colors
  static const Color neonPurple = Color(0xFF9D4EDD);
  static const Color border = Color(0xFF1E293B);
  static const Color borderHighlight = Color(0xFF334155);
  static const Color borderCyan = Color(0x6600F0FF);
  
  // Typography
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.cyberCyan,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.cyberCyan,
        secondary: AppColors.threatRed,
        surface: AppColors.surface,
        error: AppColors.threatRed,
        onPrimary: Colors.black,
        onSurface: AppColors.textPrimary,
      ),
      fontFamily: 'Segoe UI',
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.cyberCyan,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.borderHighlight, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cyberCyan, width: 2),
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 24,
      ),
    );
  }
}
