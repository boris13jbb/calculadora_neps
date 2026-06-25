import 'package:flutter/material.dart';

class AppColors {
  static const backgroundGradientStart = Color(0xFFFDFBF7);
  static const backgroundGradientEnd = Color(0xFFF5EFE3);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFFFFDF8);
  static const card = Color(0xFFFFFFFF);
  static const sidebar = Color(0xFF1A2332);
  static const header = Color(0xFF1A2332);
  static const accent = Color(0xFFC5A059);
  static const accentDark = Color(0xFFB8860B);
  static const primaryGreen = Color(0xFF2F6B45);
  static const primaryBlue = Color(0xFF1F4E79);
  static const steelBlue = Color(0xFF3D5A80);
  static const danger = Color(0xFFB94D4D);
  static const muted = Color(0xFF7A6648);
  static const border = Color(0xFFE8DCC4);
  static const borderLight = Color(0xFFEDE4D3);
  static const formulaBg = Color(0xFFFFF9EE);
  static const textDark = Color(0xFF1F2A2E);
  static const textGreen = Color(0xFF2C3E2F);
  static const headerText = Color(0xFFF7EAC5);
  static const headerMuted = Color(0xFFCFD8C5);
}

class AppTheme {
  static ThemeData build() {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        brightness: Brightness.light,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.backgroundGradientStart,
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderLight),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: AppColors.sidebar,
        indicatorColor: AppColors.accent,
        selectedIconTheme: IconThemeData(color: AppColors.sidebar),
        unselectedIconTheme: IconThemeData(color: AppColors.headerMuted),
        selectedLabelTextStyle: TextStyle(
          color: AppColors.accent,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: AppColors.headerMuted,
          fontSize: 12,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.sidebar,
        indicatorColor: AppColors.accent.withValues(alpha: 0.25),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? AppColors.accent : AppColors.headerMuted,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 11,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.accent : AppColors.headerMuted,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
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
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      dropdownMenuTheme: const DropdownMenuThemeData(
        textStyle: TextStyle(
          color: AppColors.textDark,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
