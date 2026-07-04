import 'package:flutter/material.dart';

/// Paleta corporativa VICUNHA.
///
/// Se migró de un esquema dominado por beige a un lienzo neutro y frío con
/// superficies claras, chrome oscuro (sidebar/header) y acento dorado usado de
/// forma controlada. Los nombres de tokens se conservan para compatibilidad con
/// el resto de la app; solo cambian los valores y se agregan nuevos tokens.
class AppColors {
  AppColors._();

  // ── Lienzo / fondos ──────────────────────────────────────────────
  /// Fondo general de la aplicación (neutro frío y claro).
  static const canvas = Color(0xFFEDF0F4);
  static const backgroundGradientStart = Color(0xFFEDF0F4);
  static const backgroundGradientEnd = Color(0xFFE4E8EE);

  // ── Superficies ──────────────────────────────────────────────────
  /// Superficie principal de tarjetas.
  static const surface = Color(0xFFFFFFFF);

  /// Superficie secundaria (secciones internas, inputs, filas alternas).
  static const surfaceAlt = Color(0xFFF6F8FA);

  /// Alias histórico usado por componentes de tarjeta.
  static const card = surface;

  // ── Chrome oscuro (sidebar + barra de marca) ─────────────────────
  /// Fondo del sidebar de navegación.
  static const sidebar = Color(0xFF17222B);

  /// Fondo de la barra de marca / cabeceras oscuras.
  static const header = Color(0xFF1E2A33);

  /// Texto principal sobre chrome oscuro.
  static const headerText = Color(0xFFF3F6F9);

  /// Texto secundario/atenuado sobre chrome oscuro.
  static const headerMuted = Color(0xFFA7B4BF);

  // ── Acento dorado (uso controlado) ───────────────────────────────
  static const accent = Color(0xFFC5A059);
  static const accentDark = Color(0xFF9C7A22);

  /// Contenedor dorado muy claro (fondos de chips/realces sutiles).
  static const accentSoft = Color(0xFFF6EDD6);

  // ── Colores de acción primarios ──────────────────────────────────
  static const primaryGreen = Color(0xFF2F6B45);
  static const primaryBlue = Color(0xFF1F4E79);
  static const danger = Color(0xFFC0392B);

  // ── Texto / bordes (tonos fríos, sin beige) ──────────────────────
  static const textDark = Color(0xFF1B2833);
  static const textGreen = Color(0xFF2A3B47);
  static const muted = Color(0xFF5E6B77);
  static const border = Color(0xFFE1E6EC);
  static const borderLight = Color(0xFFEBEEF2);

  /// Fondo de la caja de fórmula (branding dorado muy sutil).
  static const formulaBg = Color(0xFFF6EFDD);

  // ── Estados de calidad (alertas de neps) ─────────────────────────
  static const statusNormal = Color(0xFF2E7D46);
  static const statusWarning = Color(0xFFC77700);
  static const statusCritical = Color(0xFFC0392B);

  /// Contenedores claros para chips/badges de estado sobre fondo claro.
  static const statusNormalBg = Color(0xFFE7F4EC);
  static const statusWarningBg = Color(0xFFFBEFD9);
  static const statusCriticalBg = Color(0xFFFBE7E4);

  /// Texto legible de estado sobre sus contenedores claros.
  static const statusNormalText = Color(0xFF1E5B32);
  static const statusWarningText = Color(0xFF8A5300);
  static const statusCriticalText = Color(0xFF8E2A20);
}

class AppTheme {
  const AppTheme._();

  static ThemeData build() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryBlue,
      brightness: Brightness.light,
    ).copyWith(
      surface: AppColors.surface,
      primary: AppColors.primaryBlue,
      secondary: AppColors.accent,
      error: AppColors.danger,
      onSurface: AppColors.textDark,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.canvas,
      dividerColor: AppColors.border,
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(color: AppColors.textDark),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: AppColors.sidebar,
        indicatorColor: AppColors.accent,
        selectedIconTheme: IconThemeData(color: AppColors.header),
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
        backgroundColor: AppColors.header,
        indicatorColor: AppColors.accent.withValues(alpha: 0.28),
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
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryBlue,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryBlue,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      dropdownMenuTheme: const DropdownMenuThemeData(
        textStyle: TextStyle(
          color: AppColors.textDark,
          fontWeight: FontWeight.w600,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.header,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(color: AppColors.headerText, fontSize: 12),
      ),
      listTileTheme: const ListTileThemeData(
        tileColor: AppColors.surfaceAlt,
        selectedTileColor: AppColors.accentSoft,
        selectedColor: AppColors.primaryGreen,
        iconColor: AppColors.textDark,
        textColor: AppColors.textDark,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.header,
        contentTextStyle: const TextStyle(color: AppColors.headerText),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
