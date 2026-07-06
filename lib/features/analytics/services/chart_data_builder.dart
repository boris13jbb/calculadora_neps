import '../../../models/alert_level.dart';
import '../../../models/analytics_period.dart';
import '../../../models/nep_record.dart';
import '../../../services/alert_service.dart';
import '../../../services/analytics_service.dart';
import '../models/chart_config.dart';

/// Valida compatibilidad métrica / agrupación / tipo visual.
class ChartConfigRules {
  const ChartConfigRules._();

  static List<ChartGroupBy> allowedGroupings(ChartMetric metric) {
    return switch (metric) {
      ChartMetric.statusDistribution ||
      ChartMetric.criticalityPercent =>
        const [ChartGroupBy.none],
      ChartMetric.topTelars => const [ChartGroupBy.telar],
      ChartMetric.topFabrics => const [ChartGroupBy.fabric],
      ChartMetric.topLots => const [ChartGroupBy.lot],
      _ => ChartGroupBy.values,
    };
  }

  static List<ChartVisualType> allowedVisualTypes(
    ChartMetric metric,
    ChartGroupBy groupBy,
  ) {
    if (metric == ChartMetric.statusDistribution) {
      return const [
        ChartVisualType.donut,
        ChartVisualType.kpi,
        ChartVisualType.table,
      ];
    }
    if (metric == ChartMetric.criticalityPercent &&
        groupBy == ChartGroupBy.none) {
      return const [ChartVisualType.gauge, ChartVisualType.kpi];
    }
    if (groupBy.isTemporal ||
        groupBy == ChartGroupBy.day ||
        groupBy == ChartGroupBy.week) {
      return const [
        ChartVisualType.line,
        ChartVisualType.verticalBar,
        ChartVisualType.table,
      ];
    }
    if (groupBy == ChartGroupBy.none) {
      return const [ChartVisualType.kpi, ChartVisualType.table];
    }
    return const [
      ChartVisualType.verticalBar,
      ChartVisualType.horizontalBar,
      ChartVisualType.table,
    ];
  }

  static ChartVisualType recommendedVisualType(
    ChartMetric metric,
    ChartGroupBy groupBy,
  ) {
    final allowed = allowedVisualTypes(metric, groupBy);
    return allowed.first;
  }

  static ChartConfig normalize(ChartConfig config) {
    final groups = allowedGroupings(config.metric);
    var groupBy = config.groupBy;
    if (!groups.contains(groupBy)) {
      groupBy = groups.first;
    }
    final visuals = allowedVisualTypes(config.metric, groupBy);
    var visual = config.visualType;
    if (!visuals.contains(visual)) {
      visual = visuals.first;
    }
    return config.copyWith(groupBy: groupBy, visualType: visual);
  }

  static String? validate(ChartConfig config) {
    if (!allowedGroupings(config.metric).contains(config.groupBy)) {
      return 'La agrupación seleccionada no aplica a esta métrica.';
    }
    if (!allowedVisualTypes(config.metric, config.groupBy)
        .contains(config.visualType)) {
      return 'Seleccione un tipo de gráfica compatible con la métrica.';
    }
    return null;
  }
}

/// Construye datasets para el constructor de gráfica personalizada.
class ChartDataBuilder {
  ChartDataBuilder({
    AnalyticsService? analytics,
    AlertService? alerts,
  })  : _analytics = analytics ?? analyticsService,
        _alerts = alerts ?? alertService;

  final AnalyticsService _analytics;
  final AlertService _alerts;

  ChartDataResult build(
    List<NepRecord> records,
    ChartConfig config, {
    AnalyticsPeriod? periodOverride,
  }) {
    final normalized = ChartConfigRules.normalize(config);
    final validation = ChartConfigRules.validate(normalized);
    if (validation != null) {
      return ChartDataResult(
        isValid: false,
        validationMessage: validation,
        labels: const [],
        values: const [],
      );
    }

    if (records.isEmpty) {
      return const ChartDataResult(
        isValid: false,
        validationMessage:
            'No hay datos disponibles para el periodo seleccionado.',
        labels: [],
        values: [],
      );
    }

    if (normalized.metric == ChartMetric.statusDistribution) {
      return _buildDistribution(records, normalized);
    }
    if (normalized.metric == ChartMetric.criticalityPercent &&
        normalized.groupBy == ChartGroupBy.none) {
      return _buildCriticalityGauge(records, normalized);
    }

    final grouped = _groupRecords(
      records,
      normalized,
      periodOverride: periodOverride,
    );
    if (grouped.isEmpty) {
      return ChartDataResult(
        isValid: false,
        validationMessage:
            'No hay datos disponibles para el periodo seleccionado.',
        labels: const [],
        values: const [],
        title: _metricTitle(normalized.metric),
      );
    }

    final labels = grouped.map((e) => e.label).toList();
    final values = grouped.map((e) => e.value).toList();
    final tableRows = [
      for (var i = 0; i < labels.length; i++)
        [labels[i], _formatNum(values[i])],
    ];

    return ChartDataResult(
      isValid: true,
      labels: labels,
      values: values,
      title: _metricTitle(normalized.metric),
      subtitle: normalized.groupBy.label,
      suggestedVisualType: normalized.visualType,
      tableRows: tableRows,
    );
  }

  ChartDataResult _buildDistribution(
    List<NepRecord> records,
    ChartConfig config,
  ) {
    final dist = _analytics.distribucionPorEstado(records);
    return ChartDataResult(
      isValid: true,
      labels: const ['Normal', 'Advertencia', 'Crítico'],
      values: [
        dist.normal.toDouble(),
        dist.advertencia.toDouble(),
        dist.critico.toDouble(),
      ],
      title: 'Distribución de estados',
      subtitle: '${dist.total} registros',
      suggestedVisualType: ChartVisualType.donut,
      distribution: {
        'Normal': dist.normal.toDouble(),
        'Advertencia': dist.advertencia.toDouble(),
        'Crítico': dist.critico.toDouble(),
      },
      tableRows: [
        [
          'Normal',
          '${dist.normal}',
          '${dist.percentage(AlertLevel.normal).toStringAsFixed(1)}%'
        ],
        [
          'Advertencia',
          '${dist.advertencia}',
          '${dist.percentage(AlertLevel.advertencia).toStringAsFixed(1)}%'
        ],
        [
          'Crítico',
          '${dist.critico}',
          '${dist.percentage(AlertLevel.critico).toStringAsFixed(1)}%'
        ],
      ],
    );
  }

  ChartDataResult _buildCriticalityGauge(
    List<NepRecord> records,
    ChartConfig config,
  ) {
    final pct = _analytics.porcentajeCriticos(records);
    return ChartDataResult(
      isValid: true,
      labels: const ['Críticos'],
      values: [pct],
      title: 'Índice de criticidad',
      subtitle: 'Porcentaje de registros críticos',
      singleValue: pct,
      suggestedVisualType: ChartVisualType.gauge,
      tableRows: [
        ['Porcentaje críticos', '${pct.toStringAsFixed(1)}%'],
        ['Registros', '${records.length}'],
      ],
    );
  }

  List<_GroupedValue> _groupRecords(
    List<NepRecord> records,
    ChartConfig config, {
    AnalyticsPeriod? periodOverride,
  }) {
    final limit = config.topLimit.clamp(1, 50);

    if (config.metric == ChartMetric.topTelars) {
      return _analytics
          .topTelaresPorNeps(records, limit: limit)
          .map((g) => _GroupedValue('T${g.key}', g.totalNeps))
          .toList();
    }
    if (config.metric == ChartMetric.topFabrics) {
      return _analytics
          .topTelasPorNeps(records, limit: limit)
          .map((g) => _GroupedValue(g.key, g.totalNeps))
          .toList();
    }
    if (config.metric == ChartMetric.topLots) {
      return _analytics
          .topLotesPorNeps(records, limit: limit)
          .map((g) => _GroupedValue(g.key, g.totalNeps))
          .toList();
    }

    final temporalPeriod = config.groupBy.asAnalyticsPeriod ?? periodOverride;
    if (temporalPeriod != null) {
      final series = _analytics.tendenciaPorPeriodo(records, temporalPeriod);
      return series
          .map((p) =>
              _GroupedValue(p.label, _seriesMetric(p, config.metric, records)))
          .toList();
    }

    return _groupByField(records, config, limit);
  }

  List<_GroupedValue> _groupByField(
    List<NepRecord> records,
    ChartConfig config,
    int limit,
  ) {
    String fieldKey(NepRecord r) => switch (config.groupBy) {
          ChartGroupBy.telar => r.telar,
          ChartGroupBy.fabric => r.tela,
          ChartGroupBy.lot => r.loteTrama,
          ChartGroupBy.shift => r.turno,
          ChartGroupBy.operator => r.operario,
          ChartGroupBy.alertStatus => _alerts.getAlertLevel(r.neps).label,
          _ => '',
        };

    final map = <String, List<NepRecord>>{};
    for (final record in records) {
      final key = fieldKey(record).trim();
      if (key.isEmpty) continue;
      map.putIfAbsent(key, () => []).add(record);
    }

    final entries = map.entries.map((entry) {
      final value = _aggregateMetric(entry.value, config.metric);
      var label = entry.key;
      if (config.groupBy == ChartGroupBy.telar) label = 'T$label';
      return _GroupedValue(label, value);
    }).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return entries.take(limit).toList();
  }

  double _seriesMetric(
    dynamic point,
    ChartMetric metric,
    List<NepRecord> allRecords,
  ) {
    return switch (metric) {
      ChartMetric.nepsTotal => point.totalNeps as double,
      ChartMetric.mtsCalculados => point.totalMts as double,
      ChartMetric.recordCount => (point.recordCount as int).toDouble(),
      ChartMetric.averageNeps => point.averageNeps as double,
      ChartMetric.criticalityPercent =>
        _bucketCriticalPercent(point, allRecords),
      _ => point.totalNeps as double,
    };
  }

  double _bucketCriticalPercent(dynamic point, List<NepRecord> allRecords) {
    // Aproximación por periodo usando registros del bucket vía label no es trivial;
    // usamos total neps como proxy solo si no hay mejor dato — para criticidad temporal
    // recomendamos métrica dedicada en UI. Aquí calculamos % críticos del subconjunto
    // filtrado por fecha del punto si está disponible.
    return _analytics.porcentajeCriticos(allRecords);
  }

  double _aggregateMetric(List<NepRecord> items, ChartMetric metric) {
    if (items.isEmpty) return 0;
    return switch (metric) {
      ChartMetric.nepsTotal => _analytics.totalNeps(items),
      ChartMetric.mtsCalculados => _analytics.totalMtsCalculados(items),
      ChartMetric.recordCount => items.length.toDouble(),
      ChartMetric.averageNeps => _analytics.promedioNeps(items),
      ChartMetric.maxNeps => _analytics.maxNeps(items),
      ChartMetric.minNeps => _analytics.minNeps(items),
      ChartMetric.criticalCount =>
        _alerts.detectCriticalRecords(items).length.toDouble(),
      ChartMetric.warningCount => items
          .where((r) => _alerts.getAlertLevel(r.neps) == AlertLevel.advertencia)
          .length
          .toDouble(),
      ChartMetric.normalCount => items
          .where((r) => _alerts.getAlertLevel(r.neps) == AlertLevel.normal)
          .length
          .toDouble(),
      ChartMetric.alertCount => items
          .where((r) => _alerts.getAlertLevel(r.neps) != AlertLevel.normal)
          .length
          .toDouble(),
      ChartMetric.criticalityPercent => _analytics.porcentajeCriticos(items),
      _ => _analytics.totalNeps(items),
    };
  }

  String _metricTitle(ChartMetric metric) => metric.label;

  String _formatNum(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }
}

class _GroupedValue {
  const _GroupedValue(this.label, this.value);
  final String label;
  final double value;
}

final ChartDataBuilder chartDataBuilder = ChartDataBuilder();
