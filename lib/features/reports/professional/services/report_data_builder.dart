import '../../../../utils/record_filter_helper.dart';
import '../../../../models/alert_level.dart';
import '../../../../models/nep_record.dart';
import '../../../../services/alert_service.dart';
import '../models/report_comparison.dart';
import '../models/report_conclusion.dart';
import '../models/report_section_type.dart';
import '../models/report_configuration.dart';
import '../models/report_detail_column.dart';
import '../models/report_period_preset.dart';
import '../models/report_statistics.dart';
import 'report_comparison_service.dart';
import 'report_conclusion_engine.dart';
import 'report_grouping_service.dart';
import 'report_period_resolver.dart';
import 'report_statistics_service.dart';

/// Datos procesados listos para vista previa y exportación.
class ProcessedReportData {
  const ProcessedReportData({
    required this.configuration,
    required this.records,
    required this.statistics,
    required this.dateRangeLabel,
    required this.filterDescription,
    this.comparison,
    this.conclusion,
    this.temporalGroups = const [],
    this.byTelar = const [],
    this.byTela = const [],
    this.byLote = const [],
    this.byTurno = const [],
    this.byOperario = const [],
    this.byLinea = const [],
    this.tableRecords = const [],
    this.generatedAt,
  });

  final ReportConfiguration configuration;
  final List<NepRecord> records;
  final ReportStatistics statistics;
  final String dateRangeLabel;
  final String filterDescription;
  final ReportComparison? comparison;
  final ReportConclusion? conclusion;
  final List<TemporalGroupPoint> temporalGroups;
  final List<DimensionGroupStats> byTelar;
  final List<DimensionGroupStats> byTela;
  final List<DimensionGroupStats> byLote;
  final List<DimensionGroupStats> byTurno;
  final List<DimensionGroupStats> byOperario;
  final List<DimensionGroupStats> byLinea;
  final List<NepRecord> tableRecords;
  final DateTime? generatedAt;

  bool get isEmpty => records.isEmpty;
}

/// Orquesta filtrado, estadísticas y preparación de datos del reporte.
class ReportDataBuilder {
  ReportDataBuilder({
    ReportStatisticsService? statistics,
    ReportGroupingService? grouping,
    ReportComparisonService? comparison,
    ReportConclusionEngine? conclusions,
    ReportPeriodResolver? periodResolver,
    AlertService? alerts,
  })  : _stats = statistics ?? reportStatisticsService,
        _grouping = grouping ?? reportGroupingService,
        _comparison = comparison ?? reportComparisonService,
        _conclusions = conclusions ?? reportConclusionEngine,
        _periodResolver = periodResolver ?? reportPeriodResolver,
        _alerts = alerts ?? alertService;

  final ReportStatisticsService _stats;
  final ReportGroupingService _grouping;
  final ReportComparisonService _comparison;
  final ReportConclusionEngine _conclusions;
  final ReportPeriodResolver _periodResolver;
  final AlertService _alerts;

  ProcessedReportData build({
    required ReportConfiguration config,
    required List<NepRecord> sourceRecords,
    bool includeOperatorData = true,
    bool includeCreatorData = true,
  }) {
    var     records = _stats.filterByPeriod(
      sourceRecords,
      config.periodPreset,
      customFrom: config.customDateFrom,
      customTo: config.customDateTo,
    );
    records = _stats.applyFilters(records, config.filters);
    records = RecordFilterHelper.sortChronological(records);

    final range = _periodResolver.resolve(
      config.periodPreset,
      customFrom: config.customDateFrom,
      customTo: config.customDateTo,
    );

    final statistics = _stats.compute(records);

    ReportComparison? comparisonResult;
    if (config.enableComparison && records.isNotEmpty) {
      comparisonResult = _comparison.compare(
        sourceRecords,
        config.periodPreset,
        comparisonPreset: config.comparisonPreset,
        customFromA: config.customDateFrom,
        customToA: config.customDateTo,
      );
    }

    ReportConclusion? conclusionResult;
    if (config.enableConclusions) {
      conclusionResult = _conclusions.generate(
        statistics: statistics,
        comparison: comparisonResult,
        includeOperatorNote: includeOperatorData,
      );
      if (config.editedConclusions.trim().isNotEmpty) {
        conclusionResult = conclusionResult.copyWith(
          editedText: config.editedConclusions,
        );
      }
      if (config.manualRecommendations.trim().isNotEmpty) {
        conclusionResult = conclusionResult.copyWith(
          manualRecommendations: config.manualRecommendations,
        );
      }
    }

    List<NepRecord>? previousRecords;
    if (config.enableComparison) {
      final prevRange = _periodResolver.previousPeriod(config.periodPreset);
      if (prevRange != null && !prevRange.isAll) {
        previousRecords = sourceRecords.where((r) {
          if (prevRange.start == null || prevRange.end == null) return false;
          final local = r.createdAt.toLocal();
          final day = DateTime(local.year, local.month, local.day);
          final startDay = DateTime(
            prevRange.start!.year,
            prevRange.start!.month,
            prevRange.start!.day,
          );
          final endDay = DateTime(
            prevRange.end!.year,
            prevRange.end!.month,
            prevRange.end!.day,
          );
          return !day.isBefore(startDay) && !day.isAfter(endDay);
        }).toList();
      }
    }

    final temporal =
        config.sections.contains(ReportSectionType.analisisTemporal)
            ? _grouping.groupByTemporal(records, config.temporalGrouping)
            : <TemporalGroupPoint>[];

    final tableRecords = _prepareTableRecords(records, config);

    return ProcessedReportData(
      configuration: config,
      records: records,
      statistics: statistics,
      dateRangeLabel: range.displayLabel,
      filterDescription: _filterDescription(config),
      comparison: comparisonResult,
      conclusion: conclusionResult,
      temporalGroups: temporal,
      byTelar: config.sections.contains(ReportSectionType.analisisTelar)
          ? _grouping.byTelar(records, previous: previousRecords)
          : [],
      byTela: config.sections.contains(ReportSectionType.analisisTela)
          ? _grouping.byTela(records, previous: previousRecords)
          : [],
      byLote: config.sections.contains(ReportSectionType.analisisLote)
          ? _grouping.byLote(records, previous: previousRecords)
          : [],
      byTurno: config.sections.contains(ReportSectionType.analisisTurno)
          ? _grouping.byTurno(records, previous: previousRecords)
          : [],
      byOperario: includeOperatorData &&
              config.sections.contains(ReportSectionType.analisisOperario)
          ? _grouping.byOperario(records, previous: previousRecords)
          : [],
      byLinea: config.sections.contains(ReportSectionType.analisisLinea)
          ? _grouping.byLinea(records, previous: previousRecords)
          : [],
      tableRecords: tableRecords,
      generatedAt: DateTime.now(),
    );
  }

  List<NepRecord> _prepareTableRecords(
    List<NepRecord> records,
    ReportConfiguration config,
  ) {
    if (!config.sections.contains(ReportSectionType.tablaDetallada)) {
      return [];
    }

    var filtered = List<NepRecord>.from(records);
    final tableConfig = config.tableConfig;

    filtered = switch (tableConfig.recordFilter) {
      ReportTableRecordFilter.soloCriticos => filtered
          .where((r) => _alerts.getAlertLevel(r.neps) == AlertLevel.critico)
          .toList(),
      ReportTableRecordFilter.soloPendientes =>
        filtered.where((r) => r.requiereSeguimiento).toList(),
      _ => filtered,
    };

    filtered.sort((a, b) {
      final cmp = _compareByColumn(a, b, tableConfig.sortColumn);
      return tableConfig.sortAscending ? cmp : -cmp;
    });

    if (!tableConfig.includeAllRecords && tableConfig.recordLimit != null) {
      return filtered.take(tableConfig.recordLimit!).toList();
    }
    return filtered;
  }

  int _compareByColumn(
    NepRecord a,
    NepRecord b,
    ReportDetailColumn column,
  ) {
    return switch (column) {
      ReportDetailColumn.neps => a.neps.compareTo(b.neps),
      ReportDetailColumn.mtsCalculados =>
        a.mtsCalculados.compareTo(b.mtsCalculados),
      ReportDetailColumn.telar => a.telar.compareTo(b.telar),
      ReportDetailColumn.tela => a.tela.compareTo(b.tela),
      ReportDetailColumn.fecha ||
      ReportDetailColumn.hora =>
        a.createdAt.compareTo(b.createdAt),
      _ => a.createdAt.compareTo(b.createdAt),
    };
  }

  String _filterDescription(ReportConfiguration config) {
    final f = config.filters;
    if (!f.hasActiveFilters) return 'Sin filtros adicionales';
    final parts = <String>[];
    if (f.telares.isNotEmpty) parts.add('Telares: ${f.telares.join(", ")}');
    if (f.telas.isNotEmpty) parts.add('Telas: ${f.telas.join(", ")}');
    if (f.lotes.isNotEmpty) parts.add('Lotes: ${f.lotes.join(", ")}');
    if (f.turnos.isNotEmpty) parts.add('Turnos: ${f.turnos.join(", ")}');
    if (f.operarios.isNotEmpty) {
      parts.add('Operarios: ${f.operarios.join(", ")}');
    }
    if (f.alertLevel != null) {
      parts.add('Alerta: ${f.alertLevel!.label}');
    }
    return parts.join(' · ');
  }

  /// Validaciones previas a generar el reporte.
  String? validate(ReportConfiguration config) {
    if (config.sections.isEmpty) {
      return 'Seleccione al menos una sección del reporte.';
    }
    if (config.cover.title.trim().isEmpty) {
      return 'El título del reporte no puede estar vacío.';
    }
    if (config.periodPreset == ReportPeriodPreset.rangoPersonalizado) {
      if (config.customDateFrom == null || config.customDateTo == null) {
        return 'Defina la fecha inicial y final del rango personalizado.';
      }
      final fromDay = DateTime(
        config.customDateFrom!.year,
        config.customDateFrom!.month,
        config.customDateFrom!.day,
      );
      final toDay = DateTime(
        config.customDateTo!.year,
        config.customDateTo!.month,
        config.customDateTo!.day,
      );
      if (fromDay.isAfter(toDay)) {
        return 'La fecha inicial no puede ser posterior a la final.';
      }
    }
    if (config.sections.contains(ReportSectionType.tablaDetallada) &&
        config.tableConfig.columns.isEmpty) {
      return 'Seleccione al menos una columna para la tabla detallada.';
    }
    if (config.sections.contains(ReportSectionType.graficas)) {
      final enabled = config.charts.where((c) => c.enabled).toList();
      if (enabled.isEmpty) {
        return 'Active al menos una gráfica o desactive la sección de gráficas.';
      }
    }
    return null;
  }
}

final reportDataBuilder = ReportDataBuilder();
