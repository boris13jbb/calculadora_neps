import '../../core/permissions/permission.dart';
import '../../features/alerts/alerts_screen.dart';
import '../../features/capture/capture_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/export/export_screen.dart';
import '../../features/fabrics/fabric_catalog_screen.dart';
import '../../features/records/records_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/users/users_screen.dart';
import '../../features/analytics/analytics_screen.dart';
import '../../models/app_user.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';
import '../../providers/auth_provider.dart';

enum AppNavId {
  dashboard,
  analytics,
  capture,
  records,
  alerts,
  fabrics,
  reports,
  export,
  users,
  settings,
}

class AppNavItem {
  const AppNavItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.permission,
    required this.screen,
  });

  final AppNavId id;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Permission permission;
  final Widget screen;
}

class AppNavigation {
  const AppNavigation._();

  static const List<AppNavItem> all = [
    AppNavItem(
      id: AppNavId.dashboard,
      label: 'Inicio',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      permission: Permission.viewDashboard,
      screen: DashboardScreen(),
    ),
    AppNavItem(
      id: AppNavId.analytics,
      label: 'Gráficas',
      icon: Icons.analytics_outlined,
      selectedIcon: Icons.analytics,
      permission: Permission.viewDashboard,
      screen: AnalyticsScreen(),
    ),
    AppNavItem(
      id: AppNavId.capture,
      label: 'Captura',
      icon: Icons.add_circle_outline,
      selectedIcon: Icons.add_circle,
      permission: Permission.captureRecords,
      screen: CaptureScreen(),
    ),
    AppNavItem(
      id: AppNavId.records,
      label: 'Registros',
      icon: Icons.table_chart_outlined,
      selectedIcon: Icons.table_chart,
      permission: Permission.viewRecords,
      screen: RecordsScreen(),
    ),
    AppNavItem(
      id: AppNavId.alerts,
      label: 'Alertas',
      icon: Icons.notifications_outlined,
      selectedIcon: Icons.notifications_active,
      permission: Permission.viewAlerts,
      screen: AlertsScreen(),
    ),
    AppNavItem(
      id: AppNavId.fabrics,
      label: 'Telas',
      icon: Icons.texture_outlined,
      selectedIcon: Icons.texture,
      permission: Permission.manageFabrics,
      screen: FabricCatalogScreen(),
    ),
    AppNavItem(
      id: AppNavId.reports,
      label: 'Informes',
      icon: Icons.folder_special_outlined,
      selectedIcon: Icons.folder_special,
      permission: Permission.manageReports,
      screen: ReportsScreen(),
    ),
    AppNavItem(
      id: AppNavId.export,
      label: 'Exportar',
      icon: Icons.ios_share_outlined,
      selectedIcon: Icons.ios_share,
      permission: Permission.exportReports,
      screen: ExportScreen(),
    ),
    AppNavItem(
      id: AppNavId.users,
      label: 'Usuarios',
      icon: Icons.people_outline,
      selectedIcon: Icons.people,
      permission: Permission.manageUsers,
      screen: UsersScreen(),
    ),
    AppNavItem(
      id: AppNavId.settings,
      label: 'Config',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      permission: Permission.viewSettings,
      screen: SettingsScreen(),
    ),
  ];

  static List<AppNavItem> visibleFor(AppUser? user) {
    if (user == null || !user.isActive) return [];
    return all.where((item) => user.hasPermission(item.permission)).toList();
  }

  /// Índice de una pantalla dentro de la lista visible para el usuario.
  /// Devuelve `null` si el usuario no tiene acceso a esa pantalla.
  static int? indexOf(AppUser? user, AppNavId id) {
    final items = visibleFor(user);
    for (var i = 0; i < items.length; i++) {
      if (items[i].id == id) return i;
    }
    return null;
  }

  static int clampIndex(int index, int length) {
    if (length <= 0) return 0;
    if (index < 0) return 0;
    if (index >= length) return length - 1;
    return index;
  }

  /// Navega a una pantalla por id respetando permisos del usuario actual.
  static void navigateIfAllowed(BuildContext context, AppNavId id) {
    final auth = context.read<AuthProvider>();
    final appState = context.read<AppState>();
    final index = indexOf(auth.profile, id);
    if (index != null) {
      appState.setNavigationIndex(index);
    }
  }
}
