import 'package:flutter/material.dart';

import '../theme/app_styles.dart';

class QuickAccessButton extends StatelessWidget {
  const QuickAccessButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.foreground = Colors.white,
    this.compact = false,
    this.width,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color foreground;
  final VoidCallback onTap;
  final bool compact;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: color,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 16,
            vertical: compact ? 12 : 16,
          ),
          child: Row(
            children: [
              Icon(icon, color: foreground, size: compact ? 20 : 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 13 : 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: foreground.withValues(alpha: 0.85),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );

    if (width == null) return button;
    return SizedBox(width: width, child: button);
  }
}
