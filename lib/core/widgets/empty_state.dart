import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Acción opcional en un estado vacío.
class EmptyStateAction {
  const EmptyStateAction({
    required this.label,
    required this.onPressed,
    this.filled = true,
    this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final bool filled;
  final IconData? icon;
}

/// Estado vacío reutilizable con iconografía y acciones.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actions = const [],
    this.compact = false,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String message;
  final List<EmptyStateAction> actions;
  final bool compact;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppColors.muted;
    final iconSize = compact ? 36.0 : 52.0;
    final titleSize = compact ? 13.0 : 15.0;
    final messageSize = compact ? 11.0 : 13.0;
    final padding = compact ? 16.0 : 28.0;

    return Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(compact ? 10 : 14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: iconSize, color: color),
          ),
          SizedBox(height: compact ? 8 : 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: titleSize,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: messageSize,
              color: AppColors.muted,
              height: 1.35,
            ),
          ),
          if (actions.isNotEmpty) ...[
            SizedBox(height: compact ? 10 : 14),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: actions.map((action) {
                if (action.filled) {
                  return FilledButton.icon(
                    onPressed: action.onPressed,
                    icon: Icon(action.icon ?? Icons.arrow_forward, size: 16),
                    label: Text(action.label),
                  );
                }
                return OutlinedButton.icon(
                  onPressed: action.onPressed,
                  icon: Icon(action.icon ?? Icons.arrow_forward, size: 16),
                  label: Text(action.label),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
