import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/layout/responsive_layout.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/capture_session_actions.dart';
import '../../core/widgets/dashboard_charts.dart';
import '../../core/widgets/formula_box.dart';
import '../../providers/app_state.dart';
import '../../services/alert_service.dart';
import '../../services/analytics_service.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final phone = isPhoneLayout(context);
    final spacing = screenSpacing(context);
    final records = appState.visibleRecords;

    final analytics = analyticsService;
    final worstTela = alertService.mostProblematicTela(records);
    final worstLote = alertService.mostProblematicLote(records);
    final lastCritical = analytics.ultimaAlertaCritica(records);
    final pctCritical = analytics.porcentajeCriticos(records);

    return AppPage(
      title: 'Panel principal',
      subtitle: phone ? null : 'Análisis de calidad y control de neps',
      denseOnPhone: true,
      compactPadding: true,
      fillViewport: true,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormulaBox(compact: phone),
            SizedBox(height: spacing),
            Text(
              'Indicadores clave',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: phone ? 14 : 16,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: phone ? 8 : 12),
            _KpiGrid(
              compact: phone,
              totalRecords: analytics.totalRegistros(records),
              totalNeps: appState.formatDecimal(analytics.totalNeps(records)),
              averageNeps:
                  appState.formatNumber(analytics.promedioNeps(records)),
              totalTelares: analytics.totalTelares(records),
              criticalTelars: analytics.countTelaresCriticos(records),
              worstTela: worstTela?.key,
              worstLote: worstLote?.key,
              lastCritical: lastCritical != null
                  ? 'T${lastCritical.telar} · ${appState.formatDecimal(lastCritical.neps)} neps'
                  : null,
              pctCritical: '${pctCritical.toStringAsFixed(1)}%',
            ),
            SizedBox(height: spacing + 4),
            Text(
              'Gráficas de análisis',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: phone ? 14 : 16,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: phone ? 8 : 12),
            DashboardChartsSection(
              records: records,
              formatDecimal: appState.formatDecimal,
              compact: phone,
              onGoToCapture: () => appState.setNavigationIndex(1),
              onGoToRecords: () => appState.setNavigationIndex(2),
            ),
            SizedBox(height: spacing + 4),
            Text(
              'Accesos rápidos',
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
                      label: 'Alertas',
                      icon: Icons.notifications_active,
                      color: AppColors.statusCritical,
                      onTap: () => appState.setNavigationIndex(3),
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
                      label: 'Catálogo telas',
                      icon: Icons.texture,
                      color: AppColors.primaryBlue,
                      onTap: () => appState.setNavigationIndex(4),
                    ),
                    _QuickAction(
                      width: itemWidth,
                      compact: phone,
                      label: 'Informes',
                      icon: Icons.folder_special,
                      color: AppColors.primaryBlue,
                      onTap: () => appState.setNavigationIndex(5),
                    ),
                    _QuickAction(
                      width: itemWidth,
                      compact: phone,
                      label: 'Exportar',
                      icon: Icons.ios_share,
                      color: AppColors.primaryGreen,
                      onTap: () => appState.setNavigationIndex(6),
                    ),
                    _QuickAction(
                      width: itemWidth,
                      compact: phone,
                      label: 'Configuración',
                      icon: Icons.settings,
                      color: AppColors.primaryBlue,
                      onTap: () => appState.setNavigationIndex(7),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({
    required this.compact,
    required this.totalRecords,
    required this.totalNeps,
    required this.averageNeps,
    required this.totalTelares,
    required this.criticalTelars,
    this.worstTela,
    this.worstLote,
    this.lastCritical,
    required this.pctCritical,
  });

  final bool compact;
  final int totalRecords;
  final String totalNeps;
  final String averageNeps;
  final int totalTelares;
  final int criticalTelars;
  final String? worstTela;
  final String? worstLote;
  final String? lastCritical;
  final String pctCritical;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: compact ? 2 : 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: compact ? 1.55 : 2.5,
      children: [
        DashboardKpiCard(
          title: 'Total registros',
          value: '$totalRecords',
          icon: Icons.list_alt,
          color: AppColors.primaryGreen,
        ),
        DashboardKpiCard(
          title: 'Total neps',
          value: totalNeps,
          icon: Icons.analytics_outlined,
          color: AppColors.primaryBlue,
        ),
        DashboardKpiCard(
          title: 'Promedio neps',
          value: averageNeps,
          icon: Icons.trending_up,
          color: AppColors.accentDark,
        ),
        DashboardKpiCard(
          title: 'Telares registrados',
          value: '$totalTelares',
          icon: Icons.precision_manufacturing,
          color: AppColors.primaryGreen,
        ),
        DashboardKpiCard(
          title: 'Telares críticos',
          value: '$criticalTelars',
          icon: Icons.error_outline,
          color: AppColors.statusCritical,
        ),
        DashboardKpiCard(
          title: '% registros críticos',
          value: pctCritical,
          icon: Icons.percent,
          color: AppColors.statusCritical,
        ),
        DashboardKpiCard(
          title: 'Tela más problemática',
          value: worstTela ?? '—',
          icon: Icons.texture,
          color: AppColors.statusWarning,
        ),
        DashboardKpiCard(
          title: 'Lote/trama crítico',
          value: worstLote ?? '—',
          icon: Icons.inventory_2_outlined,
          color: AppColors.statusWarning,
        ),
        DashboardKpiCard(
          title: 'Última alerta crítica',
          value: lastCritical ?? '—',
          icon: Icons.notification_important_outlined,
          color: AppColors.statusCritical,
          subtitle: lastCritical == null ? 'Sin alertas críticas' : null,
        ),
      ],
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
