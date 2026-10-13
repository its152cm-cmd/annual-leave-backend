import 'package:flutter/material.dart';

/// Core theme colors and styles
class AppTheme {
  // Brand & Surface Colors
  static const Color primaryGreen = Color(0xFF34C759);
  static const Color primaryColor = primaryGreen;
  static const Color primaryBlue = Color(0xFF0066FF);
  static const Color backgroundWhite = Color(0xFFFFFFFF);
  static const Color surfaceSecondary = Color(0xFFF4F6F8);
  static const Color cardBackground = Color(0xFFF8F9FA);
  static const Color borderSubtle = Color(0xFFE5E7EB);
  static const Color textDark = Color(0xFF1C1C1E);
  static const Color textMuted = Color(0xFF8E8E93);
  static const Color badgeGreenLight = Color(0xFFE8F8EC);
  static const Color shadowColor = Color(0x1A000000);

  // Shared sizing tokens
  static const double radiusSmall = 12;
  static const double radiusMedium = 16;
  static const double radiusLarge = 24;
  static const double radiusPill = 999;

  static const List<BoxShadow> softShadow = [
    BoxShadow(
      color: shadowColor,
      blurRadius: 10,
      offset: Offset(0, 4),
    ),
  ];

  // Date Status Fill Colors
  static const Color statusBusyBg = Color(0xFFFFD1D1);
  static const Color statusHolidayBg = Color(0xFFF3E5F5);
  static const Color statusAnnualLeaveBg = Color(0xFFD0E8FF);
  static const Color statusRecommendedBg = Color(0xFFFFF3C4);
  static const Color statusNormalBg = Colors.transparent;

  // Date Status Text Colors
  static const Color statusBusyText = Color(0xFFD32F2F);
  static const Color statusHolidayText = Color(0xFF7B1FA2);
  static const Color statusAnnualLeaveText = Color(0xFF1976D2);
  static const Color statusRecommendedText = Color(0xFFF57F17);

  // Default Font Family Name
  static const String fontFamily = 'Inter';

  /// Global ThemeData with App Font Configuration
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: backgroundWhite,
      primaryColor: primaryGreen,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreen,
        primary: primaryGreen,
        surface: backgroundWhite,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: textDark,
          fontWeight: FontWeight.bold,
          fontSize: 28,
        ),
        titleLarge: TextStyle(
          color: textDark,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
        bodyLarge: TextStyle(
          color: textDark,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          color: textDark,
          fontSize: 14,
        ),
        bodySmall: TextStyle(
          color: textMuted,
          fontSize: 12,
        ),
      ),
    );
  }
}