import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum StatusBannerType { info, warning, error }

/// Banner informativo reutilizable (sync, errores, avisos).
class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.message,
    this.type = StatusBannerType.warning,
    this.onDismiss,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final StatusBannerType type;
  final VoidCallback? onDismiss;
  final String? actionLabel;
  final VoidCallback? onAction;

  Color get _color => switch (type) {
        StatusBannerType.info => AppColors.primaryBlue,
        StatusBannerType.warning => AppColors.statusWarning,
        StatusBannerType.error => AppColors.danger,
      };

  IconData get _icon => switch (type) {
        StatusBannerType.info => Icons.info_outline,
        StatusBannerType.warning => Icons.cloud_off_outlined,
        StatusBannerType.error => Icons.error_outline,
      };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _color.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_icon, size: 18, color: _color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _color,
                  height: 1.3,
                ),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  foregroundColor: _color,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(actionLabel!, style: const TextStyle(fontSize: 11)),
              ),
            ],
            if (onDismiss != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: onDismiss,
                icon: Icon(Icons.close, size: 16, color: _color),
              ),
          ],
        ),
      ),
    );
  }
}
