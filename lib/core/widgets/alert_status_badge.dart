import 'package:flutter/material.dart';

import '../../models/alert_level.dart';
import '../../services/alert_service.dart';
import '../theme/app_theme.dart';

/// Badge visual del estado de alerta de un registro.
class AlertStatusBadge extends StatelessWidget {
  const AlertStatusBadge({
    super.key,
    required this.level,
    this.compact = false,
  });

  final AlertLevel level;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = alertService.getAlertColor(level);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(compact ? 8 : 12),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        level.label,
        style: TextStyle(
          color: color,
          fontSize: compact ? 10 : 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Texto de neps resaltado según nivel de alerta.
class AlertNepsText extends StatelessWidget {
  const AlertNepsText({
    super.key,
    required this.nepsText,
    required this.level,
    this.fontSize = 14,
    this.bold = true,
  });

  final String nepsText;
  final AlertLevel level;
  final double fontSize;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final color = alertService.getAlertColor(level);
    return Text(
      nepsText,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
        fontFamily: 'monospace',
      ),
    );
  }
}

/// Indicador circular de color para listas compactas.
class AlertLevelDot extends StatelessWidget {
  const AlertLevelDot({super.key, required this.level, this.size = 10});

  final AlertLevel level;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: alertService.getAlertColor(level),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
    );
  }
}
