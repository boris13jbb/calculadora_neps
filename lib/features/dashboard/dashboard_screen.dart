import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/layout/responsive_layout.dart';
import '../../core/navigation/app_navigation.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nav_permission_gate.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/capture_session_actions.dart';
import '../../core/widgets/formula_box.dart';
import '../../core/widgets/kpi_card.dart';
import '../../core/widgets/quality_charts.dart';
import '../../core/widgets/section_header.dart';
import '../../models/nep_record.dart';
import '../../providers/app_state.dart';
import '../../services/alert_service.dart';
import '../../services/analytics_service.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final phone = isPhoneLayout(context);
    final spacing = screenSpacing(context);
    final appState = context.read<AppState>();

    return NavPermissionGate(
      navId: AppNavId.dashboard,
      child: AppPage(
        title: 'Panel principal',
        subtitle: phone ? null : 'Análisis de calidad y control de neps',
        denseOnPhone: true,
        compactPadding: true,
        fillViewport: true,
        child: Selector<AppState, List<NepRecord>>(
          selector: (_, state) => state.dashboardRecords,
          builder: (context, records, _) {
            final analytics = analyticsService;
            final worstTela = alertService.mostProblematicTela(records);
            final worstLote = alertService.mostProblematicLote(records);
            final lastCritical = analytics.ultimaAlertaCritica(records);
            final pctCritical = analytics.porcentajeCriticos(records);

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FormulaBox(compact: phone),
                  SizedBox(height: spacing + 4),
                  AppSectionHeader(
                    icon: Icons.insights_outlined,
                    title: 'Indicadores clave',
                    subtitle:
                        phone ? null : 'Resumen ejecutivo del control de neps',
                  ),
                  SizedBox(height: phone ? 10 : 14),
                  _KpiGrid(
                    compact: phone,
                    totalRecords: analytics.totalRegistros(records),
                    totalNeps:
                        appState.formatDecimal(analytics.totalNeps(records)),
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
                  SizedBox(height: spacing + 8),
                  AppSectionHeader(
                    icon: Icons.bar_chart_outlined,
                    title: 'Análisis gráfico',
                    subtitle: phone
                        ? null
                        : 'Resumen rápido · el detalle está en Gráficas',
                  ),
                  SizedBox(height: phone ? 10 : 14),
                  QualityChartsSection(
                    records: records,
                    formatDecimal: appState.formatDecimal,
                    include: QualityChartsCatalog.dashboardSummary,
                    compact: phone,
                    onGoToCapture: () =>
                        goToNewCaptureSession(context, appState),
                    onGoToRecords: () => AppNavigation.navigateIfAllowed(
                        context, AppNavId.records),
                  ),
                  SizedBox(height: phone ? 12 : 16),
                  SizedBox(
                    width: phone ? double.infinity : null,
                    child: FilledButton.icon(
                      onPressed: () => AppNavigation.navigateIfAllowed(
                          context, AppNavId.analytics),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: Text(
                        phone
                            ? 'Ver gráficas completas'
                            : 'Ver análisis completo',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: phone ? 14 : 20,
                          vertical: phone ? 12 : 14,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: spacing + 8),
                  const AppSectionHeader(
                    icon: Icons.bolt_outlined,
                    title: 'Accesos rápidos',
                  ),
                  SizedBox(height: phone ? 10 : 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final itemWidth =
                          phone ? (constraints.maxWidth - 8) / 2 : null;

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
                            onTap: () =>
                                goToNewCaptureSession(context, appState),
                          ),
                          _QuickAction(
                            width: itemWidth,
                            compact: phone,
                            label: 'Alertas',
                            icon: Icons.notifications_active,
                            color: AppColors.statusCritical,
                            onTap: () => AppNavigation.navigateIfAllowed(
                                context, AppNavId.alerts),
                          ),
                          _QuickAction(
                            width: itemWidth,
                            compact: phone,
                            label: 'Ver registros',
                            icon: Icons.table_chart,
                            color: AppColors.primaryGreen,
                            onTap: () => AppNavigation.navigateIfAllowed(
                              context,
                              AppNavId.records,
                            ),
                          ),
                          _QuickAction(
                            width: itemWidth,
                            compact: phone,
                            label: 'Gráficas',
                            icon: Icons.analytics,
                            color: AppColors.primaryBlue,
                            onTap: () => AppNavigation.navigateIfAllowed(
                              context,
                              AppNavId.analytics,
                            ),
                          ),
                          _QuickAction(
                            width: itemWidth,
                            compact: phone,
                            label: 'Catálogo telas',
                            icon: Icons.texture,
                            color: AppColors.primaryBlue,
                            onTap: () => AppNavigation.navigateIfAllowed(
                              context,
                              AppNavId.fabrics,
                            ),
                          ),
                          _QuickAction(
                            width: itemWidth,
                            compact: phone,
                            label: 'Informes',
                            icon: Icons.folder_special,
                            color: AppColors.primaryBlue,
                            onTap: () => AppNavigation.navigateIfAllowed(
                              context,
                              AppNavId.reports,
                            ),
                          ),
                          _QuickAction(
                            width: itemWidth,
                            compact: phone,
                            label: 'Exportar',
                            icon: Icons.ios_share,
                            color: AppColors.primaryGreen,
                            onTap: () => AppNavigation.navigateIfAllowed(
                              context,
                              AppNavId.export,
                            ),
                          ),
                          _QuickAction(
                            width: itemWidth,
                            compact: phone,
                            label: 'Configuración',
                            icon: Icons.settings,
                            color: AppColors.primaryBlue,
                            onTap: () => AppNavigation.navigateIfAllowed(
                              context,
                              AppNavId.settings,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            );
          },
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
    return KpiStrip(
      compact: compact,
      minCardWidth: 230,
      cards: [
        KpiCard(
          compact: compact,
          label: 'Total registros',
          value: '$totalRecords',
          icon: Icons.list_alt,
          color: AppColors.primaryGreen,
        ),
        KpiCard(
          compact: compact,
          label: 'Total neps',
          value: totalNeps,
          icon: Icons.analytics_outlined,
          color: AppColors.primaryBlue,
        ),
        KpiCard(
          compact: compact,
          label: 'Promedio neps',
          value: averageNeps,
          icon: Icons.trending_up,
          color: AppColors.accentDark,
        ),
        KpiCard(
          compact: compact,
          label: 'Telares registrados',
          value: '$totalTelares',
          icon: Icons.precision_manufacturing,
          color: AppColors.primaryGreen,
        ),
        KpiCard(
          compact: compact,
          label: 'Telares críticos',
          value: '$criticalTelars',
          icon: Icons.error_outline,
          color: AppColors.statusCritical,
        ),
        KpiCard(
          compact: compact,
          label: '% registros críticos',
          value: pctCritical,
          icon: Icons.percent,
          color: AppColors.statusCritical,
        ),
        KpiCard(
          compact: compact,
          label: 'Tela más problemática',
          value: worstTela ?? '—',
          icon: Icons.texture,
          color: AppColors.statusWarning,
        ),
        KpiCard(
          compact: compact,
          label: 'Lote/trama crítico',
          value: worstLote ?? '—',
          icon: Icons.inventory_2_outlined,
          color: AppColors.statusWarning,
        ),
        KpiCard(
          compact: compact,
          label: 'Última alerta crítica',
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
    final button = FilledButton(
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: compact ? 18 : 24),
          SizedBox(width: compact ? 6 : 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: compact ? 12 : 14),
            ),
          ),
        ],
      ),
    );

    if (width == null) return button;

    return SizedBox(width: width, child: button);
  }
}
