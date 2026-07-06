import '../../../models/analytics_period.dart';

/// Métrica a visualizar en el constructor de gráfica personalizada.
enum ChartMetric {
  nepsTotal('Total neps'),
  mtsCalculados('Metros calculados'),
  recordCount('Cantidad de registros'),
  averageNeps('Promedio de neps'),
  maxNeps('Neps máximo'),
  minNeps('Neps mínimo'),
  alertCount('Cantidad de alertas'),
  criticalCount('Cantidad de críticos'),
  warningCount('Cantidad de advertencias'),
  normalCount('Cantidad de normales'),
  criticalityPercent('Porcentaje de criticidad'),
  statusDistribution('Distribución de estados'),
  topTelars('Top telares'),
  topFabrics('Top telas'),
  topLots('Top lote/trama');

  const ChartMetric(this.label);
  final String label;
}

/// Dimensión de agrupación para el dataset.
enum ChartGroupBy {
  none('Sin agrupación'),
  day('Por día'),
  week('Por semana'),
  month('Por mes'),
  year('Por año'),
  telar('Por telar'),
  fabric('Por tela'),
  lot('Por lote/trama'),
  shift('Por turno'),
  operator('Por operario'),
  alertStatus('Por estado de alerta');

  const ChartGroupBy(this.label);
  final String label;

  bool get isTemporal =>
      this == day || this == week || this == month || this == year;

  AnalyticsPeriod? get asAnalyticsPeriod => switch (this) {
        ChartGroupBy.day => AnalyticsPeriod.day,
        ChartGroupBy.week => AnalyticsPeriod.week,
        ChartGroupBy.month => AnalyticsPeriod.month,
        ChartGroupBy.year => AnalyticsPeriod.year,
        _ => null,
      };
}

/// Tipo de visualización disponible.
enum ChartVisualType {
  line('Línea'),
  verticalBar('Barras verticales'),
  horizontalBar('Barras horizontales'),
  donut('Dona / pastel'),
  gauge('Índice / gauge'),
  kpi('Tarjeta KPI'),
  table('Tabla resumen');

  const ChartVisualType(this.label);
  final String label;
}

/// Configuración completa del constructor de gráfica.
class ChartConfig {
  const ChartConfig({
    this.metric = ChartMetric.nepsTotal,
    this.groupBy = ChartGroupBy.month,
    this.visualType = ChartVisualType.line,
    this.topLimit = 10,
  });

  final ChartMetric metric;
  final ChartGroupBy groupBy;
  final ChartVisualType visualType;
  final int topLimit;

  ChartConfig copyWith({
    ChartMetric? metric,
    ChartGroupBy? groupBy,
    ChartVisualType? visualType,
    int? topLimit,
  }) {
    return ChartConfig(
      metric: metric ?? this.metric,
      groupBy: groupBy ?? this.groupBy,
      visualType: visualType ?? this.visualType,
      topLimit: topLimit ?? this.topLimit,
    );
  }

  Map<String, dynamic> toJson() => {
        'metric': metric.name,
        'groupBy': groupBy.name,
        'visualType': visualType.name,
        'topLimit': topLimit,
      };

  factory ChartConfig.fromJson(Map<String, dynamic> map) {
    ChartMetric? metric;
    for (final v in ChartMetric.values) {
      if (v.name == map['metric']) metric = v;
    }
    ChartGroupBy? groupBy;
    for (final v in ChartGroupBy.values) {
      if (v.name == map['groupBy']) groupBy = v;
    }
    ChartVisualType? visualType;
    for (final v in ChartVisualType.values) {
      if (v.name == map['visualType']) visualType = v;
    }
    return ChartConfig(
      metric: metric ?? ChartMetric.nepsTotal,
      groupBy: groupBy ?? ChartGroupBy.month,
      visualType: visualType ?? ChartVisualType.line,
      topLimit: (map['topLimit'] as num?)?.toInt() ?? 10,
    );
  }
}

/// Resultado del motor de datos para renderizar o exportar.
class ChartDataResult {
  const ChartDataResult({
    required this.labels,
    required this.values,
    this.title = '',
    this.subtitle = '',
    this.isValid = true,
    this.validationMessage,
    this.suggestedVisualType,
    this.distribution,
    this.singleValue,
    this.tableRows = const [],
  });

  final List<String> labels;
  final List<double> values;
  final String title;
  final String subtitle;
  final bool isValid;
  final String? validationMessage;
  final ChartVisualType? suggestedVisualType;
  final Map<String, double>? distribution;
  final double? singleValue;
  final List<List<String>> tableRows;

  bool get isEmpty =>
      !isValid ||
      (labels.isEmpty && distribution == null && singleValue == null);
}
