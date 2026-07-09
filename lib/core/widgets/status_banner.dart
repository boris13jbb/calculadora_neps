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
    final bg = _color.withValues(alpha: 0.10);
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _color.withValues(alpha: 0.22)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_icon, size: 18, color: _color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                  height: 1.3,
                ),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: _color.withValues(alpha: 0.14),
                  foregroundColor: _color,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: Text(actionLabel!),
              ),
            ],
            if (onDismiss != null) ...[
              const SizedBox(width: 4),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: onDismiss,
                icon: Icon(Icons.close, size: 18, color: _color),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
