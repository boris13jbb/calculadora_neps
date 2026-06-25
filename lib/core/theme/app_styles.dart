import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Tokens de diseño compartidos (espaciado, radios, sombras).
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
}

class AppRadius {
  AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
}

class AppShadows {
  AppShadows._();

  static List<BoxShadow> get card => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> get soft => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ];
}

class AppDecorations {
  AppDecorations._();

  static BoxDecoration card({
    Color? color,
    double radius = AppRadius.lg,
    bool bordered = true,
  }) {
    return BoxDecoration(
      color: color ?? AppColors.card,
      borderRadius: BorderRadius.circular(radius),
      border: bordered ? Border.all(color: AppColors.borderLight) : null,
      boxShadow: AppShadows.card,
    );
  }

  static BoxDecoration accentCard({
    Color? color,
    double radius = AppRadius.lg,
  }) {
    return BoxDecoration(
      color: color ?? AppColors.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.borderLight),
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
      color: color ?? AppColors.formulaBg,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.borderLight),
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
      border: Border.all(color: AppColors.borderLight),
    );
  }
}
