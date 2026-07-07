import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/sync_phase.dart';
import '../../providers/app_state.dart';
import '../theme/app_theme.dart';

/// Banner compacto con el estado de sincronización de datos.
class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final phase = context.select<AppState, SyncPhase>((s) => s.syncPhase);
    final isLoading = context.select<AppState, bool>((s) => s.isLoading);
    final cloudError =
        context.select<AppState, String?>((s) => s.cloudSyncError);

    if (isLoading) {
      return _Banner(
        icon: Icons.downloading,
        message: SyncPhase.loadingLocal.label,
        color: AppColors.primaryBlue,
      );
    }

    return switch (phase) {
      SyncPhase.loadingLocal => _Banner(
          icon: Icons.downloading,
          message: phase.label,
          color: AppColors.primaryBlue,
        ),
      SyncPhase.syncingCloud => _Banner(
          icon: Icons.cloud_sync,
          message: phase.label,
          color: AppColors.primaryBlue,
        ),
      SyncPhase.realtime => _Banner(
          icon: Icons.sync,
          message: phase.label,
          color: AppColors.primaryGreen,
        ),
      SyncPhase.offline => _Banner(
          icon: Icons.cloud_off_outlined,
          message: phase.label,
          detail: cloudError,
          color: AppColors.statusWarning,
          onTap: () => context.read<AppState>().ensureCloudConnected(),
        ),
    };
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.message,
    required this.color,
    this.detail,
    this.onTap,
  });

  final IconData icon;
  final String message;
  final String? detail;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (detail != null && detail!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail!,
                    style: TextStyle(
                      color: color.withValues(alpha: 0.85),
                      fontSize: 11,
                    ),
                  ),
                ],
                if (onTap != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Toca para reintentar sincronización',
                    style: TextStyle(
                      color: color.withValues(alpha: 0.75),
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.refresh, size: 16, color: color.withValues(alpha: 0.8)),
        ],
      ),
    );

    return Material(
      color: color.withValues(alpha: 0.08),
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              child: content,
            ),
    );
  }
}
