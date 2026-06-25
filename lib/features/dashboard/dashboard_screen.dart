import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/layout/responsive_layout.dart';
import '../../core/theme/app_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/capture_session_actions.dart';
import '../../core/widgets/formula_box.dart';
import '../../core/widgets/quick_access_button.dart';
import '../../core/widgets/summary_cards.dart';
import '../../providers/app_state.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final phone = isPhoneLayout(context);
    final spacing = screenSpacing(context);

    return AppPage(
      title: 'Inicio / Panel principal',
      subtitle: 'Dashboard de indicadores y accesos rapidos',
      breadcrumb: const ['Inicio', 'Panel principal'],
      denseOnPhone: true,
      compactPadding: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FormulaBox(compact: phone),
          SizedBox(height: spacing),
          SummaryCards(
            totalRecords: appState.visibleRecords.length,
            totalNeps: appState.formatDecimal(appState.totalNeps),
            averageNeps: appState.formatDecimal(appState.averageNeps),
          ),
          SizedBox(height: spacing + 4),
          AppCard(
            title: 'Accesos rapidos',
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = phone ? constraints.maxWidth : null;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    QuickAccessButton(
                      width: itemWidth,
                      compact: phone,
                      label: 'Nuevo registro',
                      icon: Icons.add_circle_outline,
                      color: AppColors.accent,
                      foreground: AppColors.textDark,
                      onTap: () => goToNewCaptureSession(context, appState),
                    ),
                    QuickAccessButton(
                      width: itemWidth,
                      compact: phone,
                      label: 'Ver registros',
                      icon: Icons.table_chart_outlined,
                      color: AppColors.primaryGreen,
                      onTap: () => appState.setNavigationIndex(2),
                    ),
                    QuickAccessButton(
                      width: itemWidth,
                      compact: phone,
                      label: 'Catalogo telas',
                      icon: Icons.texture_outlined,
                      color: AppColors.primaryBlue,
                      onTap: () => appState.setNavigationIndex(3),
                    ),
                    QuickAccessButton(
                      width: itemWidth,
                      compact: phone,
                      label: 'Informes',
                      icon: Icons.folder_special_outlined,
                      color: AppColors.steelBlue,
                      onTap: () => appState.setNavigationIndex(4),
                    ),
                    QuickAccessButton(
                      width: itemWidth,
                      compact: phone,
                      label: 'Exportar',
                      icon: Icons.ios_share_outlined,
                      color: AppColors.primaryGreen,
                      onTap: () => appState.setNavigationIndex(5),
                    ),
                  ],
                );
              },
            ),
          ),
          SizedBox(height: spacing),
          AppCard(
            title: 'Estado actual',
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = phone ? 1 : 4;
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: columns,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: phone ? 3.2 : 1.8,
                  children: [
                    _StatusTile(
                      icon: Icons.desktop_windows_outlined,
                      label: 'Pantalla',
                      value: phone ? 'Movil' : 'Escritorio',
                      subtitle: 'modo activo',
                    ),
                    _StatusTile(
                      icon: Icons.assignment_outlined,
                      label: 'Registros',
                      value: '${appState.records.length}',
                      subtitle: 'registros capturados',
                    ),
                    _StatusTile(
                      icon: Icons.texture_outlined,
                      label: 'Telas',
                      value: '${appState.fabrics.length}',
                      subtitle: 'telas en catalogo',
                    ),
                    _StatusTile(
                      icon: Icons.filter_alt_outlined,
                      label: 'Filtros',
                      value: appState.filters.hasActiveFilters ? 'Si' : 'No',
                      subtitle: appState.filters.hasActiveFilters
                          ? '${appState.visibleRecords.length} visibles'
                          : 'filtros aplicados',
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
  });

  final IconData icon;
  final String label;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppDecorations.section(),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accentDark, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 10, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
