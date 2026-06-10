import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/layout/responsive_layout.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/capture_session_actions.dart';
import '../../core/widgets/formula_box.dart';
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
      title: 'Panel principal',
      subtitle: phone ? null : 'Resumen general de la operacion',
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
          Text(
            'Accesos rapidos',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: phone ? 14 : 16,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: phone ? 8 : 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = phone ? (constraints.maxWidth - 8) / 2 : null;

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _QuickAction(
                    width: itemWidth,
                    compact: phone,
                    label: 'Nuevo registro',
                    icon: Icons.add_circle,
                    color: AppColors.accent,
                    foreground: AppColors.textDark,
                    onTap: () => goToNewCaptureSession(context, appState),
                  ),
                  _QuickAction(
                    width: itemWidth,
                    compact: phone,
                    label: 'Ver registros',
                    icon: Icons.table_chart,
                    color: AppColors.primaryGreen,
                    onTap: () => appState.setNavigationIndex(2),
                  ),
                  _QuickAction(
                    width: itemWidth,
                    compact: phone,
                    label: 'Catalogo telas',
                    icon: Icons.texture,
                    color: AppColors.primaryBlue,
                    onTap: () => appState.setNavigationIndex(3),
                  ),
                  _QuickAction(
                    width: itemWidth,
                    compact: phone,
                    label: 'Informes',
                    icon: Icons.folder_special,
                    color: AppColors.primaryBlue,
                    onTap: () => appState.setNavigationIndex(4),
                  ),
                  _QuickAction(
                    width: itemWidth,
                    compact: phone,
                    label: 'Exportar',
                    icon: Icons.ios_share,
                    color: AppColors.primaryGreen,
                    onTap: () => appState.setNavigationIndex(5),
                  ),
                ],
              );
            },
          ),
          SizedBox(height: spacing),
          Container(
            padding: sectionPadding(context),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(sectionRadius(context)),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estado actual',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: phone ? 12 : 14,
                    color: AppColors.textGreen,
                  ),
                ),
                SizedBox(height: phone ? 4 : 8),
                Text(
                  'Registros: ${appState.records.length}',
                  style: TextStyle(fontSize: phone ? 12 : 14),
                ),
                Text(
                  'Telas: ${appState.fabrics.length}',
                  style: TextStyle(fontSize: phone ? 12 : 14),
                ),
                Text(
                  'Filtros: ${appState.filters.hasActiveFilters ? 'Activos' : 'No'}',
                  style: TextStyle(fontSize: phone ? 12 : 14),
                ),
                if (appState.filters.hasActiveFilters)
                  Text(
                    'Visibles: ${appState.visibleRecords.length}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: phone ? 12 : 14,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
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
    final button = FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: foreground,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 16,
          vertical: compact ? 10 : 14,
        ),
        minimumSize: Size(compact ? 0 : 64, compact ? 40 : 48),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: compact ? 18 : 24),
      label: Text(
        label,
        style: TextStyle(fontSize: compact ? 12 : 14),
        overflow: TextOverflow.ellipsis,
      ),
    );

    if (width == null) return button;

    return SizedBox(width: width, child: button);
  }
}
