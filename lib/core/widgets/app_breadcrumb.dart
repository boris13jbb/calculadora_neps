import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppBreadcrumb extends StatelessWidget {
  const AppBreadcrumb({
    super.key,
    required this.segments,
  });

  final List<String> segments;

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) return const SizedBox.shrink();

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: [
        const Icon(Icons.home_outlined, size: 14, color: AppColors.accent),
        for (var i = 0; i < segments.length; i++) ...[
          const Icon(Icons.chevron_right, size: 14, color: AppColors.muted),
          Text(
            segments[i],
            style: TextStyle(
              fontSize: 12,
              fontWeight:
                  i == segments.length - 1 ? FontWeight.w800 : FontWeight.w600,
              color:
                  i == segments.length - 1 ? AppColors.accent : AppColors.muted,
            ),
          ),
        ],
      ],
    );
  }
}
