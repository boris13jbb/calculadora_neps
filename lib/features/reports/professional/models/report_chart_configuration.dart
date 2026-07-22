import 'report_chart_type.dart';

/// Configuración individual de una gráfica en el reporte.
class ReportChartConfiguration {
  const ReportChartConfiguration({
    required this.type,
    this.enabled = true,
    this.title = '',
    this.subtitle = '',
    this.showValues = true,
    this.showLegend = true,
    this.showAverage = false,
    this.showAlertLimits = true,
    this.maxCategories = 12,
    this.horizontal = false,
    this.movingAverageWindow = 3,
    this.temporalGrouping = ReportTemporalGrouping.dia,
  });

  final ReportChartType type;
  final bool enabled;
  final String title;
  final String subtitle;
  final bool showValues;
  final bool showLegend;
  final bool showAverage;
  final bool showAlertLimits;
  final int maxCategories;
  final bool horizontal;
  final int movingAverageWindow;
  final ReportTemporalGrouping temporalGrouping;

  String get effectiveTitle => title.isNotEmpty ? title : type.label;

  ReportChartConfiguration copyWith({
    bool? enabled,
    String? title,
    String? subtitle,
    bool? showValues,
    bool? showLegend,
    bool? showAverage,
    bool? showAlertLimits,
    int? maxCategories,
    bool? horizontal,
    int? movingAverageWindow,
    ReportTemporalGrouping? temporalGrouping,
  }) {
    return ReportChartConfiguration(
      type: type,
      enabled: enabled ?? this.enabled,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      showValues: showValues ?? this.showValues,
      showLegend: showLegend ?? this.showLegend,
      showAverage: showAverage ?? this.showAverage,
      showAlertLimits: showAlertLimits ?? this.showAlertLimits,
      maxCategories: maxCategories ?? this.maxCategories,
      horizontal: horizontal ?? this.horizontal,
      movingAverageWindow: movingAverageWindow ?? this.movingAverageWindow,
      temporalGrouping: temporalGrouping ?? this.temporalGrouping,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'enabled': enabled,
        'title': title,
        'subtitle': subtitle,
        'showValues': showValues,
        'showLegend': showLegend,
        'showAverage': showAverage,
        'showAlertLimits': showAlertLimits,
        'maxCategories': maxCategories,
        'horizontal': horizontal,
        'movingAverageWindow': movingAverageWindow,
        'temporalGrouping': temporalGrouping.name,
      };

  factory ReportChartConfiguration.fromJson(Map<String, dynamic> json) {
    final typeName = json['type']?.toString() ?? '';
    final type = ReportChartType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => ReportChartType.tendenciaNeps,
    );
    final groupingName = json['temporalGrouping']?.toString() ?? 'dia';
    final grouping = ReportTemporalGrouping.values.firstWhere(
      (e) => e.name == groupingName,
      orElse: () => ReportTemporalGrouping.dia,
    );
    return ReportChartConfiguration(
      type: type,
      enabled: json['enabled'] as bool? ?? true,
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      showValues: json['showValues'] as bool? ?? true,
      showLegend: json['showLegend'] as bool? ?? true,
      showAverage: json['showAverage'] as bool? ?? false,
      showAlertLimits: json['showAlertLimits'] as bool? ?? true,
      maxCategories: json['maxCategories'] as int? ?? 12,
      horizontal: json['horizontal'] as bool? ?? false,
      movingAverageWindow: json['movingAverageWindow'] as int? ?? 3,
      temporalGrouping: grouping,
    );
  }
}
