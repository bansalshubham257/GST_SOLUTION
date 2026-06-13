// lib/core/theme/app_colors.dart

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand Colors
  static const Color primary = Color(0xFF2563EB);       // Blue 600
  static const Color primaryDark = Color(0xFF1D4ED8);   // Blue 700
  static const Color primaryLight = Color(0xFF3B82F6);  // Blue 500
  static const Color primarySurface = Color(0xFFEFF6FF); // Blue 50

  static const Color secondary = Color(0xFF059669);     // Emerald 600
  static const Color secondaryDark = Color(0xFF047857); // Emerald 700
  static const Color secondaryLight = Color(0xFF10B981); // Emerald 500
  static const Color secondarySurface = Color(0xFFECFDF5); // Emerald 50

  static const Color accent = Color(0xFFF59E0B);        // Amber 500
  static const Color accentDark = Color(0xFFD97706);    // Amber 600
  static const Color accentSurface = Color(0xFFFFFBEB);  // Amber 50

  static const Color danger = Color(0xFFDC2626);        // Red 600
  static const Color dangerLight = Color(0xFFFEF2F2);   // Red 50
  static const Color warning = Color(0xFFF59E0B);       // Amber 500
  static const Color warningLight = Color(0xFFFFFBEB);  // Amber 50
  static const Color success = Color(0xFF059669);       // Emerald 600
  static const Color successLight = Color(0xFFECFDF5);  // Emerald 50
  static const Color info = Color(0xFF0284C7);          // Sky 600
  static const Color infoLight = Color(0xFFF0F9FF);     // Sky 50

  // Light Theme
  static const Color backgroundLight = Color(0xFFF8FAFC); // Slate 50
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceVariantLight = Color(0xFFF1F5F9); // Slate 100
  static const Color borderLight = Color(0xFFE2E8F0);    // Slate 200
  static const Color dividerLight = Color(0xFFF1F5F9);   // Slate 100

  static const Color textPrimaryLight = Color(0xFF0F172A);  // Slate 900
  static const Color textSecondaryLight = Color(0xFF475569); // Slate 600
  static const Color textTertiaryLight = Color(0xFF94A3B8);  // Slate 400
  static const Color textDisabledLight = Color(0xFFCBD5E1);  // Slate 300

  // Dark Theme
  static const Color backgroundDark = Color(0xFF0F172A);  // Slate 900
  static const Color surfaceDark = Color(0xFF1E293B);     // Slate 800
  static const Color surfaceVariantDark = Color(0xFF334155); // Slate 700
  static const Color borderDark = Color(0xFF334155);      // Slate 700
  static const Color dividerDark = Color(0xFF1E293B);     // Slate 800

  static const Color textPrimaryDark = Color(0xFFF8FAFC);   // Slate 50
  static const Color textSecondaryDark = Color(0xFF94A3B8);  // Slate 400
  static const Color textTertiaryDark = Color(0xFF475569);   // Slate 600
  static const Color textDisabledDark = Color(0xFF334155);   // Slate 700

  // GST Specific
  static const Color cgstColor = Color(0xFF7C3AED);  // Violet 600
  static const Color sgstColor = Color(0xFF2563EB);  // Blue 600
  static const Color igstColor = Color(0xFFEA580C);  // Orange 600
  static const Color cessColor = Color(0xFF0891B2);  // Cyan 600

  // Chart Colors
  static const List<Color> chartColors = [
    Color(0xFF2563EB),
    Color(0xFF059669),
    Color(0xFFF59E0B),
    Color(0xFFDC2626),
    Color(0xFF7C3AED),
    Color(0xFF0891B2),
  ];
}

