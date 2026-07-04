import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';
import '../../providers/auth_provider.dart';
import '../layout/breakpoints.dart';
import '../layout/responsive_layout.dart';
import '../navigation/app_navigation.dart';
import '../theme/app_theme.dart';

/// Barra superior profesional de cada pantalla.
///
/// Aporta contexto y valor: título/subtítulo de sección, estado de
/// sincronización, acceso rápido a alertas críticas y menú de usuario/rol.
/// En escritorio la identidad de marca vive en el sidebar; en móvil se muestra
/// un wordmark compacto porque no hay sidebar.
class AppTopBar extends StatelessWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= AppBreakpoints.desktop;
    final isPhone = width < AppBreakpoints.phone;
    final hasActions = actions != null && actions!.isNotEmpty;

    final horizontal = isDesktop ? 24.0 : (isPhone ? 14.0 : 18.0);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      padding: EdgeInsets.fromLTRB(horizontal, isPhone ? 10 : 14, horizontal,
          hasActions ? 10 : (isPhone ? 10 : 14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (!isDesktop) ...[
                const _BrandMark(),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: isPhone ? 18 : 22,
                        color: AppColors.textDark,
                        letterSpacing: 0.1,
                      ),
                    ),
                    if (subtitle != null && !isPhone) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _StatusCluster(isPhone: isPhone),
            ],
          ),
          if (hasActions) ...[
            SizedBox(height: isPhone ? 8 : 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: actions!,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.header,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.calculate_outlined,
            color: AppColors.accent,
            size: 18,
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'VICUNHA',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            color: AppColors.textDark,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _StatusCluster extends StatelessWidget {
  const _StatusCluster({required this.isPhone});

  final bool isPhone;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isPhone) ...[
          const _SyncIndicator(),
          const SizedBox(width: 8),
        ],
        const _AlertsBell(),
        const SizedBox(width: 8),
        const _UserChip(),
      ],
    );
  }
}

class _SyncIndicator extends StatelessWidget {
  const _SyncIndicator();

  @override
  Widget build(BuildContext context) {
    final hasError = context.select<AppState, bool>(
      (s) => s.cloudSyncError != null,
    );
    final color = hasError ? AppColors.statusWarning : AppColors.statusNormal;
    final label = hasError ? 'Sync limitada' : 'Sincronizado';

    return Tooltip(
      message: hasError
          ? 'Sincronización en la nube limitada. Los datos locales siguen disponibles.'
          : 'Datos sincronizados con la nube.',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertsBell extends StatelessWidget {
  const _AlertsBell();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final auth = context.watch<AuthProvider>();
    final count = appState.criticalAlertsCount;
    final alertsIndex = AppNavigation.indexOf(auth.profile, AppNavId.alerts);

    final icon = Icon(
      count > 0 ? Icons.notifications_active : Icons.notifications_none,
      color: count > 0 ? AppColors.statusCritical : AppColors.muted,
    );

    return IconButton(
      tooltip:
          count > 0 ? '$count alerta(s) crítica(s)' : 'Sin alertas críticas',
      onPressed: alertsIndex == null
          ? null
          : () => appState.setNavigationIndex(alertsIndex),
      icon: count > 0
          ? Badge(
              label: Text('$count'),
              backgroundColor: AppColors.statusCritical,
              child: icon,
            )
          : icon,
    );
  }
}

class _UserChip extends StatelessWidget {
  const _UserChip();

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;
    final width = MediaQuery.sizeOf(context).width;
    final showDetails =
        width >= AppBreakpoints.tablet && !isPhoneLayout(context);

    final name = profile?.effectiveDisplayName ?? 'Invitado';
    final roleLabel = profile?.role.label ?? '';

    final avatar = CircleAvatar(
      radius: 16,
      backgroundColor: AppColors.header,
      child: Text(
        _initials(name),
        style: const TextStyle(
          color: AppColors.accent,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );

    return PopupMenuButton<String>(
      tooltip: 'Cuenta',
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      onSelected: (value) {
        if (value == 'logout') auth.signOut();
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              if (roleLabel.isNotEmpty)
                Text(
                  roleLabel,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 18, color: AppColors.danger),
              SizedBox(width: 10),
              Text('Cerrar sesión'),
            ],
          ),
        ),
      ],
      child: Container(
        padding: EdgeInsets.fromLTRB(4, 4, showDetails ? 10 : 4, 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            avatar,
            if (showDetails) ...[
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  if (roleLabel.isNotEmpty)
                    Text(
                      roleLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down,
                  size: 18, color: AppColors.muted),
            ],
          ],
        ),
      ),
    );
  }
}
