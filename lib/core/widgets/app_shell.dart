import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';
import '../../providers/auth_provider.dart';
import '../layout/breakpoints.dart';
import '../navigation/app_navigation.dart';
import '../theme/app_theme.dart';
import 'empty_state.dart';
import 'status_banner.dart';
import 'sync_status_banner.dart';
import 'vicunha_sidebar.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  /// Preferencia del usuario para el sidebar (colapsado/expandido).
  /// `null` = usar el comportamiento por defecto según el ancho.
  bool? _sidebarExtendedPreference;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final bootstrapError =
        context.select<AppState, String?>((s) => s.bootstrapError);
    final navigationIndex =
        context.select<AppState, int>((s) => s.navigationIndex);
    final criticalAlertsCount =
        context.select<AppState, int>((s) => s.criticalAlertsCount);
    final appState = context.read<AppState>();

    final navItems = AppNavigation.visibleFor(auth.profile);
    appState.applyPendingNavigation(auth.profile);

    if (bootstrapError != null) {
      return Scaffold(
        body: Center(
          child: EmptyState(
            icon: Icons.storage_outlined,
            title: 'Error al cargar datos',
            message: bootstrapError,
            iconColor: AppColors.danger,
            actions: [
              EmptyStateAction(
                label: 'Reintentar',
                icon: Icons.refresh,
                onPressed: appState.reloadData,
              ),
            ],
          ),
        ),
      );
    }

    if (navItems.isEmpty) {
      return Scaffold(
        body: Center(
          child: EmptyState(
            icon: Icons.lock_outline,
            title: 'Sin acceso',
            message: 'Su rol no tiene pantallas asignadas.',
            iconColor: AppColors.danger,
            actions: [
              EmptyStateAction(
                label: 'Cerrar sesión',
                icon: Icons.logout,
                onPressed: auth.signOut,
              ),
            ],
          ),
        ),
      );
    }

    final safeIndex =
        AppNavigation.clampIndex(navigationIndex, navItems.length);

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= AppBreakpoints.desktop;

        if (useRail) {
          final extended = _sidebarExtendedPreference ??
              (constraints.maxWidth >= AppBreakpoints.wide);
          final destinations = navItems
              .map(
                (item) => VicunhaNavDestination(
                  label: item.label,
                  icon: item.icon,
                  selectedIcon: item.selectedIcon,
                  badgeCount:
                      item.id == AppNavId.alerts ? criticalAlertsCount : 0,
                ),
              )
              .toList();

          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  VicunhaSidebar(
                    selectedIndex: safeIndex,
                    onDestinationSelected: appState.setNavigationIndex,
                    destinations: destinations,
                    extended: extended,
                    onToggleExtended: () => setState(
                      () => _sidebarExtendedPreference = !extended,
                    ),
                    userName: auth.profile?.effectiveDisplayName,
                    userRole: auth.profile?.role.label,
                    onSignOut: auth.signOut,
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(
                    child: _ShellBody(
                      navItems: navItems,
                      selectedIndex: safeIndex,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          body: SafeArea(
            child: _ShellBody(
              navItems: navItems,
              selectedIndex: safeIndex,
            ),
          ),
          bottomNavigationBar: NavigationBar(
            height: 64,
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
            selectedIndex: safeIndex,
            onDestinationSelected: appState.setNavigationIndex,
            destinations: navItems
                .asMap()
                .entries
                .map(
                  (entry) => NavigationDestination(
                    icon: _navIcon(entry.key, entry.value, criticalAlertsCount),
                    selectedIcon: _navSelectedIcon(
                      entry.key,
                      entry.value,
                      criticalAlertsCount,
                    ),
                    label: entry.value.label,
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}

class _ShellBody extends StatelessWidget {
  const _ShellBody({
    required this.navItems,
    required this.selectedIndex,
  });

  final List<AppNavItem> navItems;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    final cloudSyncError =
        context.select<AppState, String?>((s) => s.cloudSyncError);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SyncStatusBanner(),
        if (cloudSyncError != null)
          StatusBanner(
            type: StatusBannerType.warning,
            message: cloudSyncError.contains('permisos')
                ? 'Firebase conectado parcialmente. Si no ve informes, pulse Actualizar en Informes o recargue la página.'
                : cloudSyncError,
          ),
        Expanded(
          child: IndexedStack(
            index: selectedIndex,
            children: navItems.map((item) => item.screen).toList(),
          ),
        ),
      ],
    );
  }
}

Widget _navIcon(int index, AppNavItem item, int criticalAlertsCount) {
  if (item.id == AppNavId.alerts && criticalAlertsCount > 0) {
    return Badge(
      label: Text('$criticalAlertsCount'),
      child: Icon(item.icon),
    );
  }
  return Icon(item.icon);
}

Widget _navSelectedIcon(int index, AppNavItem item, int criticalAlertsCount) {
  if (item.id == AppNavId.alerts && criticalAlertsCount > 0) {
    return Badge(
      label: Text('$criticalAlertsCount'),
      child: Icon(item.selectedIcon),
    );
  }
  return Icon(item.selectedIcon);
}
