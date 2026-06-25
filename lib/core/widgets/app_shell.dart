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
import 'vicunha_sidebar.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  static const _destinations = [
    VicunhaNavDestination(
      label: 'Inicio',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
    ),
    VicunhaNavDestination(
      label: 'Captura',
      icon: Icons.add_circle_outline,
      selectedIcon: Icons.add_circle,
    ),
    VicunhaNavDestination(
      label: 'Registros',
      icon: Icons.table_chart_outlined,
      selectedIcon: Icons.table_chart,
    ),
    VicunhaNavDestination(
      label: 'Telas',
      icon: Icons.texture_outlined,
      selectedIcon: Icons.texture,
    ),
    VicunhaNavDestination(
      label: 'Informes',
      icon: Icons.folder_special_outlined,
      selectedIcon: Icons.folder_special,
    ),
    VicunhaNavDestination(
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
        backgroundColor: AppColors.backgroundGradientStart,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= AppBreakpoints.desktop;

        if (useRail) {
          return Scaffold(
            backgroundColor: AppColors.backgroundGradientStart,
            body: SafeArea(
              child: Row(
                children: [
                  VicunhaSidebar(
                    extended: constraints.maxWidth >= AppBreakpoints.wide,
                    selectedIndex: appState.navigationIndex,
                    onDestinationSelected: appState.setNavigationIndex,
                    destinations: _destinations,
                  ),
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
          backgroundColor: AppColors.backgroundGradientStart,
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
