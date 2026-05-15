import 'package:flutter/material.dart';

/// Application color scheme
class AppColors {
  // Primary colors
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryLight = Color(0xFFDBEAFE);
  
  // Status colors
  static const Color success = Color(0xFF22C55E);
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFF97316);
  static const Color warningLight = Color(0xFFFED7AA);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color critical = Color(0xFF7F1D1D);
  static const Color criticalLight = Color(0xFFFECACA);
  
  // Neutral colors
  static const Color background = Color(0xFFF9FAFB);
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE5E7EB);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);
}

/// Application theme configuration
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: AppColors.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
      ),
    );
  }
}

/// Status color helper — accepte FR (legacy/API) et EN (canonical displayName)
Color getStatusColor(String status) {
  switch (status) {
    case 'Disponible':
    case 'Available':
    case 'Operational':
      return AppColors.success;
    case 'En usage':
    case 'En service':
    case 'In Use':
      return AppColors.primary;
    case 'En maintenance':
    case 'In Maintenance':
    case 'Maintenance':
      return AppColors.warning;
    case 'Hors service':
    case 'Out of Service':
    case 'Out of service':
      return AppColors.error;
    case 'Inactif':
    case 'Idle':
    case 'Disposed':
      return AppColors.textSecondary;
    case 'À éliminer':
    case 'A eliminer':
    case 'To Dispose':
    case 'To be disposal':
      return AppColors.error;
    case 'Transféré':
    case 'Transfere':
    case 'Transferred':
      return AppColors.primary;
    default:
      return AppColors.textSecondary;
  }
}

/// Status background color helper
Color getStatusBackgroundColor(String status) {
  switch (status) {
    case 'Disponible':
    case 'Available':
    case 'Operational':
      return AppColors.successLight;
    case 'En usage':
    case 'En service':
    case 'In Use':
      return AppColors.primaryLight;
    case 'En maintenance':
    case 'In Maintenance':
    case 'Maintenance':
      return AppColors.warningLight;
    case 'Hors service':
    case 'Out of Service':
    case 'Out of service':
      return AppColors.errorLight;
    case 'Inactif':
    case 'Idle':
    case 'Disposed':
      return AppColors.background;
    case 'À éliminer':
    case 'A eliminer':
    case 'To Dispose':
    case 'To be disposal':
      return AppColors.errorLight;
    case 'Transféré':
    case 'Transfere':
    case 'Transferred':
      return AppColors.primaryLight;
    default:
      return AppColors.background;
  }
}
