import 'package:flutter/material.dart';

class AppColors {
  static const backgroundGradientStart = Color(0xFFD9D2B0);
  static const backgroundGradientEnd = Color(0xFFC2B280);
  static const surface = Color(0xFFFEF9E8);
  static const surfaceAlt = Color(0xFFFFFDF4);
  static const header = Color(0xFF1F2A2E);
  static const accent = Color(0xFFC5A059);
  static const accentDark = Color(0xFFB8860B);
  static const primaryGreen = Color(0xFF2F6B45);
  static const primaryBlue = Color(0xFF1F4E79);
  static const danger = Color(0xFFB94D4D);
  static const muted = Color(0xFF7A6648);
  static const border = Color(0xFFD6C394);
  static const formulaBg = Color(0xFFEBDFC3);
  static const textDark = Color(0xFF1F2A2E);
  static const textGreen = Color(0xFF2C3E2F);

  /// Colores de estado para alertas de calidad.
  static const statusNormal = Color(0xFF2F6B45);
  static const statusWarning = Color(0xFFE67E22);
  static const statusCritical = Color(0xFFB94D4D);
}

class AppTheme {
  static ThemeData build() {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.backgroundGradientStart,
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: AppColors.header,
        indicatorColor: AppColors.accent,
        selectedIconTheme: IconThemeData(color: AppColors.header),
        unselectedIconTheme: IconThemeData(color: Color(0xFFCFD8C5)),
        selectedLabelTextStyle: TextStyle(
          color: AppColors.accent,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: Color(0xFFCFD8C5),
          fontSize: 12,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.header,
        indicatorColor: AppColors.accent.withValues(alpha: 0.25),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? AppColors.accent : const Color(0xFFCFD8C5),
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 11,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.accent : const Color(0xFFCFD8C5),
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      dropdownMenuTheme: const DropdownMenuThemeData(
        textStyle: TextStyle(
          color: AppColors.textDark,
          fontWeight: FontWeight.w600,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        tileColor: AppColors.surfaceAlt,
        selectedTileColor: AppColors.formulaBg,
        selectedColor: AppColors.primaryGreen,
        iconColor: AppColors.textDark,
        textColor: AppColors.textDark,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
