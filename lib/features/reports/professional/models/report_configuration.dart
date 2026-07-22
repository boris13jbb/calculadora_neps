import 'report_chart_configuration.dart';
import 'report_chart_type.dart';
import 'report_column_configuration.dart';
import 'report_cover_configuration.dart';
import 'report_detail_column.dart';
import 'report_export_options.dart';
import 'report_filter_configuration.dart';
import 'report_metric_id.dart';
import 'report_period_preset.dart';
import 'report_section_type.dart';

/// Plantillas predefinidas del generador de reportes.
enum ReportTemplateKind {
  ejecutivo('Reporte ejecutivo'),
  tecnico('Reporte técnico'),
  calidad('Reporte de calidad'),
  seguimiento('Reporte de seguimiento'),
  personalizado('Reporte personalizado');

  const ReportTemplateKind(this.label);

  final String label;
}

/// Configuración completa del reporte profesional.
class ReportConfiguration {
  ReportConfiguration({
    this.periodPreset = ReportPeriodPreset.esteMes,
    DateTime? customDateFrom,
    DateTime? customDateTo,
    ReportFilterConfiguration? filters,
    Set<ReportSectionType>? sections,
    Set<ReportMetricId>? metrics,
    List<ReportChartConfiguration>? charts,
    ReportColumnConfiguration? tableConfig,
    ReportCoverConfiguration? cover,
    ReportExportOptions? exportOptions,
    this.templateKind = ReportTemplateKind.personalizado,
    this.temporalGrouping = ReportTemporalGrouping.dia,
    this.enableComparison = false,
    this.comparisonPreset,
    this.enableConclusions = true,
    this.editedConclusions = '',
    this.manualRecommendations = '',
    this.sectionOrder,
    List<ReportDetailColumn>? hiddenSections,
  })  : customDateFrom = customDateFrom,
        customDateTo = customDateTo,
        filters = filters ?? ReportFilterConfiguration(),
        sections = sections ?? _defaultSections(),
        metrics = metrics ?? ReportMetricId.executiveDefaults(),
        charts = charts ?? _defaultCharts(),
        tableConfig = tableConfig ?? const ReportColumnConfiguration(),
        cover = cover ?? const ReportCoverConfiguration(),
        exportOptions = exportOptions ?? const ReportExportOptions(),
        hiddenSections = hiddenSections ?? [];

  ReportPeriodPreset periodPreset;
  DateTime? customDateFrom;
  DateTime? customDateTo;
  ReportFilterConfiguration filters;
  Set<ReportSectionType> sections;
  Set<ReportMetricId> metrics;
  List<ReportChartConfiguration> charts;
  ReportColumnConfiguration tableConfig;
  ReportCoverConfiguration cover;
  ReportExportOptions exportOptions;
  ReportTemplateKind templateKind;
  ReportTemporalGrouping temporalGrouping;
  bool enableComparison;
  ReportPeriodPreset? comparisonPreset;
  bool enableConclusions;
  String editedConclusions;
  String manualRecommendations;
  List<ReportSectionType>? sectionOrder;
  List<ReportDetailColumn> hiddenSections;

  static Set<ReportSectionType> _defaultSections() => {
        ReportSectionType.portada,
        ReportSectionType.resumenEjecutivo,
        ReportSectionType.alertas,
        ReportSectionType.tablaDetallada,
      };

  static List<ReportChartConfiguration> _defaultCharts() => [
        const ReportChartConfiguration(type: ReportChartType.tendenciaNeps),
        const ReportChartConfiguration(type: ReportChartType.circularAlertas),
      ];

  List<ReportSectionType> get orderedSections {
    final active = sections.toList();
    if (sectionOrder != null && sectionOrder!.isNotEmpty) {
      final ordered = <ReportSectionType>[];
      for (final s in sectionOrder!) {
        if (active.contains(s)) ordered.add(s);
      }
      for (final s in active) {
        if (!ordered.contains(s)) ordered.add(s);
      }
      return ordered;
    }
    return active;
  }

  void applyTemplate(ReportTemplateKind kind) {
    templateKind = kind;
    switch (kind) {
      case ReportTemplateKind.ejecutivo:
        sections = {
          ReportSectionType.portada,
          ReportSectionType.resumenEjecutivo,
          ReportSectionType.alertas,
          ReportSectionType.graficas,
          ReportSectionType.comparacionPeriodos,
          ReportSectionType.conclusiones,
        };
        metrics = ReportMetricId.executiveDefaults();
        charts = ReportChartType.executiveDefaults()
            .map((t) => ReportChartConfiguration(type: t))
            .toList();
        enableComparison = true;
        enableConclusions = true;
      case ReportTemplateKind.tecnico:
        sections = {
          ReportSectionType.portada,
          ReportSectionType.resumenEjecutivo,
          ReportSectionType.analisisTemporal,
          ReportSectionType.analisisTelar,
          ReportSectionType.analisisTela,
          ReportSectionType.analisisLote,
          ReportSectionType.analisisTurno,
          ReportSectionType.graficas,
          ReportSectionType.tablaDetallada,
        };
        metrics = ReportMetricId.technicalDefaults();
        charts = ReportChartType.technicalDefaults()
            .map((t) => ReportChartConfiguration(type: t))
            .toList();
        enableComparison = false;
        enableConclusions = false;
      case ReportTemplateKind.calidad:
        sections = {
          ReportSectionType.portada,
          ReportSectionType.resumenEjecutivo,
          ReportSectionType.indicadoresCalidad,
          ReportSectionType.alertas,
          ReportSectionType.analisisTelar,
          ReportSectionType.analisisLote,
          ReportSectionType.graficas,
          ReportSectionType.conclusiones,
        };
        metrics = ReportMetricId.qualityDefaults();
        charts = ReportChartType.qualityDefaults()
            .map((t) => ReportChartConfiguration(type: t))
            .toList();
        enableComparison = true;
        enableConclusions = true;
      case ReportTemplateKind.seguimiento:
        sections = {
          ReportSectionType.portada,
          ReportSectionType.alertas,
          ReportSectionType.accionesCorrectivas,
          ReportSectionType.observaciones,
          ReportSectionType.graficas,
        };
        metrics = ReportMetricId.trackingDefaults();
        charts = ReportChartType.trackingDefaults()
            .map((t) => ReportChartConfiguration(type: t))
            .toList();
        enableComparison = false;
        enableConclusions = true;
      case ReportTemplateKind.personalizado:
        break;
    }
  }

  void selectAllSections() {
    sections = Set<ReportSectionType>.from(ReportSectionType.values);
  }

  void deselectAllSections() {
    sections = {};
  }

  void selectAllMetrics() {
    metrics = Set<ReportMetricId>.from(ReportMetricId.values);
  }

  void restoreDefaults() {
    applyTemplate(ReportTemplateKind.personalizado);
    sections = _defaultSections();
    metrics = ReportMetricId.executiveDefaults();
    charts = _defaultCharts();
    filters.clear();
    periodPreset = ReportPeriodPreset.esteMes;
    customDateFrom = null;
    customDateTo = null;
    enableComparison = false;
    enableConclusions = true;
    editedConclusions = '';
    manualRecommendations = '';
  }

  ReportConfiguration copy() {
    return ReportConfiguration(
      periodPreset: periodPreset,
      customDateFrom: customDateFrom,
      customDateTo: customDateTo,
      filters: filters.copy(),
      sections: Set<ReportSectionType>.from(sections),
      metrics: Set<ReportMetricId>.from(metrics),
      charts: charts.map((c) => c.copyWith()).toList(),
      tableConfig: tableConfig,
      cover: cover,
      exportOptions: exportOptions,
      templateKind: templateKind,
      temporalGrouping: temporalGrouping,
      enableComparison: enableComparison,
      comparisonPreset: comparisonPreset,
      enableConclusions: enableConclusions,
      editedConclusions: editedConclusions,
      manualRecommendations: manualRecommendations,
      sectionOrder: sectionOrder == null
          ? null
          : List<ReportSectionType>.from(sectionOrder!),
      hiddenSections: List<ReportDetailColumn>.from(hiddenSections),
    );
  }

  Map<String, dynamic> toJson() => {
        'periodPreset': periodPreset.name,
        if (customDateFrom != null)
          'customDateFrom': customDateFrom!.toIso8601String(),
        if (customDateTo != null)
          'customDateTo': customDateTo!.toIso8601String(),
        'filters': filters.toJson(),
        'sections': sections.map((s) => s.name).toList(),
        'metrics': metrics.map((m) => m.name).toList(),
        'charts': charts.map((c) => c.toJson()).toList(),
        'tableConfig': tableConfig.toJson(),
        'cover': cover.toJson(),
        'exportOptions': exportOptions.toJson(),
        'templateKind': templateKind.name,
        'temporalGrouping': temporalGrouping.name,
        'enableComparison': enableComparison,
        if (comparisonPreset != null)
          'comparisonPreset': comparisonPreset!.name,
        'enableConclusions': enableConclusions,
        'editedConclusions': editedConclusions,
        'manualRecommendations': manualRecommendations,
        if (sectionOrder != null)
          'sectionOrder': sectionOrder!.map((s) => s.name).toList(),
      };

  factory ReportConfiguration.fromJson(Map<String, dynamic> json) {
    final presetName = json['periodPreset']?.toString() ?? 'esteMes';
    final preset = ReportPeriodPreset.values.firstWhere(
      (e) => e.name == presetName,
      orElse: () => ReportPeriodPreset.esteMes,
    );
    final config = ReportConfiguration(periodPreset: preset);
    config.customDateFrom = json['customDateFrom'] != null
        ? DateTime.tryParse(json['customDateFrom'].toString())
        : null;
    config.customDateTo = json['customDateTo'] != null
        ? DateTime.tryParse(json['customDateTo'].toString())
        : null;
    if (json['filters'] is Map) {
      config.filters = ReportFilterConfiguration.fromJson(
        Map<String, dynamic>.from(json['filters'] as Map),
      );
    }
    final sectionNames = (json['sections'] as List?)?.map((e) => e.toString());
    if (sectionNames != null) {
      config.sections = sectionNames
          .map(
            (n) =>
                ReportSectionType.values.cast<ReportSectionType?>().firstWhere(
                      (e) => e?.name == n,
                      orElse: () => null,
                    ),
          )
          .whereType<ReportSectionType>()
          .toSet();
    }
    final metricNames = (json['metrics'] as List?)?.map((e) => e.toString());
    if (metricNames != null) {
      config.metrics = metricNames
          .map(
            (n) => ReportMetricId.values.cast<ReportMetricId?>().firstWhere(
                  (e) => e?.name == n,
                  orElse: () => null,
                ),
          )
          .whereType<ReportMetricId>()
          .toSet();
    }
    if (json['charts'] is List) {
      config.charts = (json['charts'] as List)
          .whereType<Map>()
          .map(
            (m) => ReportChartConfiguration.fromJson(
              Map<String, dynamic>.from(m),
            ),
          )
          .toList();
    }
    if (json['tableConfig'] is Map) {
      config.tableConfig = ReportColumnConfiguration.fromJson(
        Map<String, dynamic>.from(json['tableConfig'] as Map),
      );
    }
    if (json['cover'] is Map) {
      config.cover = ReportCoverConfiguration.fromJson(
        Map<String, dynamic>.from(json['cover'] as Map),
      );
    }
    if (json['exportOptions'] is Map) {
      config.exportOptions = ReportExportOptions.fromJson(
        Map<String, dynamic>.from(json['exportOptions'] as Map),
      );
    }
    final kindName = json['templateKind']?.toString() ?? 'personalizado';
    config.templateKind = ReportTemplateKind.values.firstWhere(
      (e) => e.name == kindName,
      orElse: () => ReportTemplateKind.personalizado,
    );
    final groupingName = json['temporalGrouping']?.toString() ?? 'dia';
    config.temporalGrouping = ReportTemporalGrouping.values.firstWhere(
      (e) => e.name == groupingName,
      orElse: () => ReportTemporalGrouping.dia,
    );
    config.enableComparison = json['enableComparison'] as bool? ?? false;
    final compName = json['comparisonPreset']?.toString();
    if (compName != null) {
      config.comparisonPreset =
          ReportPeriodPreset.values.cast<ReportPeriodPreset?>().firstWhere(
                (e) => e?.name == compName,
                orElse: () => null,
              );
    }
    config.enableConclusions = json['enableConclusions'] as bool? ?? true;
    config.editedConclusions = json['editedConclusions']?.toString() ?? '';
    config.manualRecommendations =
        json['manualRecommendations']?.toString() ?? '';
    return config;
  }
}
