import 'package:flutter/material.dart';

import '../../models/alert_level.dart';
import '../theme/app_styles.dart';

/// Chip de estado accesible: comunica el nivel con icono + texto + color de
/// contenedor (no depende solo del color). Componente canónico para mostrar
/// estados Normal / Advertencia / Crítico en toda la app.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.style,
    this.compact = false,
    this.showIcon = true,
    this.label,
  });

  /// Construye el chip a partir de un [AlertLevel].
  factory StatusChip.fromLevel(
    AlertLevel level, {
    Key? key,
    bool compact = false,
    bool showIcon = true,
  }) {
    return StatusChip(
      key: key,
      style: AppStatusStyle.of(level),
      compact: compact,
      showIcon: showIcon,
    );
  }

  final AppStatusStyle style;
  final bool compact;
  final bool showIcon;

  /// Texto opcional que reemplaza la etiqueta por defecto del estado.
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: style.color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(style.icon, size: compact ? 12 : 14, color: style.foreground),
            SizedBox(width: compact ? 4 : 6),
          ],
          Text(
            label ?? style.label,
            style: TextStyle(
              color: style.foreground,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
