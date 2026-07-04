import 'package:flutter/material.dart';

import '../../models/alert_level.dart';
import 'app_theme.dart';

/// Tokens de diseño compartidos (espaciado, radios, sombras, tipografía).
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

class AppRadius {
  AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;

  /// Radio "pastilla" para chips y badges.
  static const double pill = 999;
}

class AppShadows {
  AppShadows._();

  /// Sombra estándar de tarjeta (fría y sutil).
  static List<BoxShadow> get card => [
        BoxShadow(
          color: const Color(0xFF1B2833).withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  /// Sombra suave para secciones y elementos elevados ligeramente.
  static List<BoxShadow> get soft => [
        BoxShadow(
          color: const Color(0xFF1B2833).withValues(alpha: 0.04),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ];
}

/// Estilos de texto reutilizables para mantener jerarquía consistente.
class AppText {
  AppText._();

  static const TextStyle sectionTitle = TextStyle(
    fontWeight: FontWeight.w900,
    fontSize: 16,
    color: AppColors.textDark,
    letterSpacing: 0.1,
  );

  static const TextStyle cardTitle = TextStyle(
    fontWeight: FontWeight.w800,
    fontSize: 14,
    color: AppColors.textDark,
  );

  static const TextStyle subtle = TextStyle(
    fontSize: 12,
    color: AppColors.muted,
    fontWeight: FontWeight.w600,
  );

  /// Etiqueta corta en mayúsculas (KPIs, encabezados de columna).
  static const TextStyle overline = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    color: AppColors.muted,
    letterSpacing: 0.4,
  );
}

class AppDecorations {
  AppDecorations._();

  static BoxDecoration card({
    Color? color,
    double radius = AppRadius.lg,
    bool bordered = true,
    bool elevated = true,
  }) {
    return BoxDecoration(
      color: color ?? AppColors.card,
      borderRadius: BorderRadius.circular(radius),
      border: bordered ? Border.all(color: AppColors.border) : null,
      boxShadow: elevated ? AppShadows.card : null,
    );
  }

  static BoxDecoration accentCard({
    Color? color,
    double radius = AppRadius.lg,
  }) {
    return BoxDecoration(
      color: color ?? AppColors.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.border),
      boxShadow: AppShadows.soft,
    );
  }

  static BoxDecoration accentLeftBorder({
    Color? color,
    double radius = AppRadius.lg,
    Color borderColor = AppColors.accent,
  }) {
    // Borde uniforme; la franja izquierda dorada se aplica con un widget hijo.
    return BoxDecoration(
      color: color ?? AppColors.accentSoft,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.border),
      boxShadow: AppShadows.soft,
    );
  }

  static BoxDecoration section({
    Color? color,
    double radius = AppRadius.md,
  }) {
    return BoxDecoration(
      color: color ?? AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.border),
    );
  }
}

/// Paleta semántica de un estado de calidad (color base, contenedor claro,
/// texto legible e icono asociado). Centraliza el mapeo estado→estilo para no
/// duplicar lógica visual en cada pantalla.
class AppStatusStyle {
  const AppStatusStyle({
    required this.color,
    required this.background,
    required this.foreground,
    required this.icon,
    required this.label,
  });

  final Color color;
  final Color background;
  final Color foreground;
  final IconData icon;
  final String label;

  static const AppStatusStyle normal = AppStatusStyle(
    color: AppColors.statusNormal,
    background: AppColors.statusNormalBg,
    foreground: AppColors.statusNormalText,
    icon: Icons.check_circle_outline,
    label: 'Normal',
  );

  static const AppStatusStyle warning = AppStatusStyle(
    color: AppColors.statusWarning,
    background: AppColors.statusWarningBg,
    foreground: AppColors.statusWarningText,
    icon: Icons.warning_amber_rounded,
    label: 'Advertencia',
  );

  static const AppStatusStyle critical = AppStatusStyle(
    color: AppColors.statusCritical,
    background: AppColors.statusCriticalBg,
    foreground: AppColors.statusCriticalText,
    icon: Icons.error_outline,
    label: 'Crítico',
  );

  static AppStatusStyle of(AlertLevel level) {
    switch (level) {
      case AlertLevel.normal:
        return normal;
      case AlertLevel.advertencia:
        return warning;
      case AlertLevel.critico:
        return critical;
    }
  }
}
