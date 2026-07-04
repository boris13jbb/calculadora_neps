import 'package:flutter/material.dart';

import '../theme/app_styles.dart';
import '../theme/app_theme.dart';

/// Tarjeta de métrica (KPI) profesional y reutilizable.
///
/// Reemplaza a las tarjetas de resumen duplicadas que existían por pantalla.
/// Presenta una insignia con icono, una etiqueta corta y un valor destacado,
/// con un realce de color a la izquierda para comunicar el estado/énfasis.
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.primaryBlue,
    this.subtitle,
    this.onTap,
    this.compact = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final badgeSize = compact ? 36.0 : 44.0;

    final content = Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 16,
        compact ? 12 : 14,
        compact ? 12 : 16,
        compact ? 12 : 14,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: badgeSize,
            height: badgeSize,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(compact ? 10 : 12),
            ),
            child: Icon(icon, color: color, size: compact ? 20 : 24),
          ),
          SizedBox(width: compact ? 10 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 10 : 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.muted,
                    letterSpacing: 0.3,
                    height: 1.15,
                  ),
                ),
                SizedBox(height: compact ? 2 : 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: compact ? 20 : 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textDark,
                      height: 1.05,
                    ),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.soft,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          // IntrinsicHeight acota la altura del Row para que la barra de acento
          // (un ColoredBox sin altura propia) pueda estirarse con
          // CrossAxisAlignment.stretch incluso cuando la tarjeta se coloca en un
          // contexto de altura no acotada (SingleChildScrollView / Wrap).
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: color),
                Expanded(child: content),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Grilla fluida de [KpiCard] que aprovecha todo el ancho disponible.
///
/// Calcula el número de columnas a partir de un ancho objetivo por tarjeta,
/// de modo que en pantallas anchas se distribuyen más tarjetas por fila y en
/// móvil se apilan, sin espacios muertos.
class KpiStrip extends StatelessWidget {
  const KpiStrip({
    super.key,
    required this.cards,
    this.spacing = 12,
    this.minCardWidth = 210,
    this.maxColumns = 6,
    this.compact = false,
  });

  final List<KpiCard> cards;
  final double spacing;
  final double minCardWidth;
  final int maxColumns;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final target = compact ? (minCardWidth * 0.8) : minCardWidth;
        var columns = (width / target).floor();
        columns = columns.clamp(1, maxColumns);
        // No permitir más columnas que tarjetas.
        columns = columns > cards.length ? cards.length : columns;
        final itemWidth = (width - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards)
              SizedBox(width: itemWidth, child: card),
          ],
        );
      },
    );
  }
}
