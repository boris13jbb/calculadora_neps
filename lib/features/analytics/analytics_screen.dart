import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/layout/responsive_layout.dart';
import '../../core/navigation/app_navigation.dart';
import '../../core/widgets/nav_permission_gate.dart';
import '../../core/widgets/app_loading_view.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/formula_box.dart';
import '../../core/widgets/quality_charts.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/status_banner.dart';
import '../../models/analytics_period.dart';
import '../../models/analytics_summary.dart';
import '../../models/nep_record.dart';
import '../../models/record_filters.dart';
import '../../providers/app_state.dart';
import '../../services/analytics_preferences_service.dart';
import '../../services/analytics_service.dart';
import '../../utils/analytics_filter_description.dart';
import '../../utils/record_filter_helper.dart';
import 'models/chart_config.dart';
import 'widgets/analytics_charts.dart';
import 'widgets/analytics_export_actions.dart';
import 'widgets/analytics_filter_panel.dart';
import 'widgets/custom_chart_builder.dart';

/// Pantalla de gráficas e informes analíticos con filtros temporales.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final RecordFilters _filters = RecordFilters();
  AnalyticsPeriod _period = AnalyticsPeriod.month;
  bool _isExporting = false;
  int _filterPanelKey = 0;
  final GlobalKey _chartsCaptureKey = GlobalKey();
  final AnalyticsPreferencesService _prefsService = analyticsPreferencesService;
  bool _prefsLoaded = false;
  ChartConfig _chartConfig = const ChartConfig();

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final snapshot = await _prefsService.load();
    if (!mounted || snapshot == null) {
      if (mounted) setState(() => _prefsLoaded = true);
      return;
    }
    setState(() {
      _period = snapshot.period;
      _applyFilters(snapshot.filters);
      if (snapshot.chartConfig != null) {
        _chartConfig = snapshot.chartConfig!;
      }
      if (_period == AnalyticsPeriod.custom) {
        ensureAnalyticsCustomDateDefaults(_filters);
      }
      _prefsLoaded = true;
      _filterPanelKey++;
    });
  }

  void _applyFilters(RecordFilters source) {
    _filters.tela = source.tela;
    _filters.loteTrama = source.loteTrama;
    _filters.telar = source.telar;
    _filters.nepsMin = source.nepsMin;
    _filters.nepsMax = source.nepsMax;
    _filters.mtsMin = source.mtsMin;
    _filters.mtsMax = source.mtsMax;
    _filters.dateFrom = source.dateFrom;
    _filters.dateTo = source.dateTo;
    _filters.searchText = source.searchText;
    _filters.alertLevel = source.alertLevel;
    _filters.turno = source.turno;
    _filters.operario = source.operario;
    _filters.lineaProduccion = source.lineaProduccion;
    _filters.soloNoRevisados = source.soloNoRevisados;
    _filters.soloConAccionCorrectiva = source.soloConAccionCorrectiva;
    _filters.quickRange = source.quickRange;
  }

  Future<void> _persistPreferences() async {
    if (!_prefsLoaded) return;
    await _prefsService.save(
      period: _period,
      filters: _filters,
      chartConfig: _chartConfig,
    );
  }

  void _onPeriodChanged(AnalyticsPeriod period) {
    setState(() {
      _period = period;
      if (period == AnalyticsPeriod.custom) {
        ensureAnalyticsCustomDateDefaults(_filters);
      }
    });
    _persistPreferences();
  }

  void _onFiltersChanged() {
    setState(() {});
    _persistPreferences();
  }

  void _clearFilters() {
    setState(() {
      _filters.clear();
      _filterPanelKey++;
    });
    _persistPreferences();
  }

  List<NepRecord> _filteredRecords(AppState appState) =>
      RecordFilterHelper.apply(appState.records, _filters);

  String? _dateRangeError() {
    if (_period != AnalyticsPeriod.custom) return null;
    return AnalyticsDateValidator.validateCustomRange(_filters);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final phone = isPhoneLayout(context);
    final spacing = screenSpacing(context);
    final dateError = _dateRangeError();
    final records = _filteredRecords(appState);
    final summary = analyticsService.buildSummary(records, _period);

    return NavPermissionGate(
      navId: AppNavId.analytics,
      child: AppPage(
      title: 'Análisis gráfico',
      subtitle:
          phone ? null : 'Visualización de informes por día, semana, mes y año',
      breadcrumb: const ['Inicio', 'Gráficas'],
      denseOnPhone: true,
      compactPadding: true,
      fillViewport: true,
      actions: [
        if (!phone)
          TextButton.icon(
            onPressed: () =>
                AppNavigation.navigateIfAllowed(context, AppNavId.dashboard),
            icon: const Icon(Icons.dashboard_outlined, size: 18),
            label: const Text('Panel principal'),
          ),
      ],
      child: _buildBody(
        context,
        appState: appState,
        phone: phone,
        spacing: spacing,
        records: records,
        summary: summary,
        dateError: dateError,
      ),
    ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required AppState appState,
    required bool phone,
    required double spacing,
    required List<NepRecord> records,
    required AnalyticsSummary summary,
    required String? dateError,
  }) {
    if (appState.isLoading && appState.records.isEmpty) {
      return const AppLoadingView(
        message: 'Cargando información de informes…',
      );
    }

    if (appState.bootstrapError != null && appState.records.isEmpty) {
      return EmptyState(
        compact: phone,
        icon: Icons.cloud_off_outlined,
        title: 'No se pudo cargar la información',
        message: 'No se pudo cargar la información de informes. '
            'Verifique su conexión o permisos.',
        actions: [
          EmptyStateAction(
            label: 'Reintentar',
            icon: Icons.refresh,
            onPressed: appState.reloadData,
          ),
        ],
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (appState.cloudSyncError != null)
            Padding(
              padding: EdgeInsets.only(bottom: spacing),
              child: StatusBanner(
                type: StatusBannerType.warning,
                message: appState.cloudSyncError!,
              ),
            ),
          FormulaBox(compact: phone),
          SizedBox(height: spacing),
          AppSectionHeader(
            icon: Icons.filter_list,
            title: 'Filtros',
            subtitle: phone ? null : 'Periodo, fechas y criterios de registro',
          ),
          SizedBox(height: phone ? 10 : 14),
          AnalyticsFilterPanel(
            key: ValueKey(_filterPanelKey),
            records: appState.records,
            filters: _filters,
            period: _period,
            dateRangeError: dateError,
            compact: phone,
            onPeriodChanged: _onPeriodChanged,
            onFiltersChanged: _onFiltersChanged,
            onClear: _clearFilters,
          ),
          SizedBox(height: spacing + 4),
          if (dateError == null && records.isEmpty)
            EmptyState(
              compact: phone,
              icon: Icons.bar_chart_outlined,
              title: 'Sin datos',
              message: 'No hay datos disponibles para el periodo seleccionado.',
              actions: [
                EmptyStateAction(
                  label: 'Limpiar filtros',
                  icon: Icons.filter_alt_off,
                  filled: false,
                  onPressed: _clearFilters,
                ),
              ],
            )
          else if (dateError == null) ...[
            AppSectionHeader(
              icon: Icons.insights_outlined,
              title: 'Indicadores clave',
              subtitle: '${records.length} registros en el filtro actual',
            ),
            SizedBox(height: phone ? 10 : 14),
            AnalyticsKpiSection(
              summary: summary,
              formatDecimal: appState.formatDecimal,
              formatNumber: appState.formatNumber,
              compact: phone,
            ),
            SizedBox(height: spacing + 4),
            AppSectionHeader(
              icon: Icons.show_chart,
              title: 'Catálogo de gráficas',
              subtitle: AnalyticsFilterDescription.describe(
                period: _period,
                filters: _filters,
              ),
            ),
            SizedBox(height: phone ? 10 : 14),
            RepaintBoundary(
              key: _chartsCaptureKey,
              child: QualityChartsSection(
                records: records,
                formatDecimal: appState.formatDecimal,
                include: QualityChartsCatalog.full,
                compact: phone,
              ),
            ),
            SizedBox(height: spacing + 4),
            const AppSectionHeader(
              icon: Icons.tune_outlined,
              title: 'Constructor de gráfica',
              subtitle: 'Combine métrica, agrupación y tipo visual',
            ),
            SizedBox(height: phone ? 10 : 14),
            CustomChartBuilder(
              records: records,
              formatDecimal: appState.formatDecimal,
              period: _period,
              compact: phone,
              initialConfig: _chartConfig,
              onConfigChanged: (config) {
                _chartConfig = config;
                _persistPreferences();
              },
            ),
            SizedBox(height: spacing + 4),
            const AppSectionHeader(
              icon: Icons.download_outlined,
              title: 'Exportar resultados',
            ),
            SizedBox(height: phone ? 10 : 14),
            AnalyticsExportActions(
              summary: summary,
              records: records,
              period: _period,
              filters: _filters,
              isExporting: _isExporting,
              chartsCaptureKey: _chartsCaptureKey,
              compact: phone,
              onExportStart: () => setState(() => _isExporting = true),
              onExportEnd: () => setState(() => _isExporting = false),
              onMessage: appState.showMessage,
            ),
          ],
        ],
      ),
    );
  }
}
