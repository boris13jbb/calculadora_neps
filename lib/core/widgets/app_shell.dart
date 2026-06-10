import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/capture/capture_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/export/export_screen.dart';
import '../../features/fabrics/fabric_catalog_screen.dart';
import '../../features/records/records_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../providers/app_state.dart';
import '../layout/breakpoints.dart';
import '../theme/app_theme.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  static const _destinations = [
    _NavItem(
      label: 'Inicio',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
    ),
    _NavItem(
      label: 'Captura',
      icon: Icons.add_circle_outline,
      selectedIcon: Icons.add_circle,
    ),
    _NavItem(
      label: 'Registros',
      icon: Icons.table_chart_outlined,
      selectedIcon: Icons.table_chart,
    ),
    _NavItem(
      label: 'Telas',
      icon: Icons.texture_outlined,
      selectedIcon: Icons.texture,
    ),
    _NavItem(
      label: 'Informes',
      icon: Icons.folder_special_outlined,
      selectedIcon: Icons.folder_special,
    ),
    _NavItem(
      label: 'Exportar',
      icon: Icons.ios_share_outlined,
      selectedIcon: Icons.ios_share,
    ),
  ];

  static const _screens = [
    DashboardScreen(),
    CaptureScreen(),
    RecordsScreen(),
    FabricCatalogScreen(),
    ReportsScreen(),
    ExportScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    if (appState.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= AppBreakpoints.desktop;

        if (useRail) {
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  NavigationRail(
                    extended: constraints.maxWidth >= AppBreakpoints.wide,
                    minExtendedWidth: 180,
                    selectedIndex: appState.navigationIndex,
                    onDestinationSelected: appState.setNavigationIndex,
                    labelType: constraints.maxWidth >= AppBreakpoints.wide
                        ? NavigationRailLabelType.none
                        : NavigationRailLabelType.all,
                    backgroundColor: AppColors.header,
                    indicatorColor: AppColors.accent,
                    leading: const Padding(
                      padding: EdgeInsets.only(top: 16, bottom: 8),
                      child: Icon(
                        Icons.calculate_outlined,
                        color: AppColors.accent,
                        size: 32,
                      ),
                    ),
                    destinations: _destinations
                        .map(
                          (item) => NavigationRailDestination(
                            icon: Icon(item.icon),
                            selectedIcon: Icon(item.selectedIcon),
                            label: Text(item.label),
                          ),
                        )
                        .toList(),
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(
                    child: IndexedStack(
                      index: appState.navigationIndex,
                      children: _screens,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          body: SafeArea(
            child: IndexedStack(
              index: appState.navigationIndex,
              children: _screens,
            ),
          ),
          bottomNavigationBar: NavigationBar(
            height: 64,
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
            selectedIndex: appState.navigationIndex,
            onDestinationSelected: appState.setNavigationIndex,
            destinations: _destinations
                .map(
                  (item) => NavigationDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selectedIcon),
                    label: item.label,
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
