import 'package:flutter/material.dart';

import '../theme/app_styles.dart';
import '../theme/app_theme.dart';

/// Encabezado de sección reutilizable con jerarquía consistente.
///
/// Muestra un icono opcional, un título, un subtítulo opcional y acciones
/// alineadas a la derecha. Se usa para separar bloques dentro de una pantalla
/// (KPIs, gráficas, listas, etc.) manteniendo el mismo estilo en toda la app.
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.dense = false,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: dense ? 16 : 18, color: AppColors.accentDark),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                title,
                style: dense ? AppText.cardTitle : AppText.sectionTitle,
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle!, style: AppText.subtle),
        ],
      ],
    );

    if (trailing == null) return titleBlock;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: titleBlock),
        const SizedBox(width: 12),
        trailing!,
      ],
    );
  }
}
