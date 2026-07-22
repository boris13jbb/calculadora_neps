import '../../../../models/alert_level.dart';
import '../../../../models/nep_record.dart';
import '../../../../services/alert_service.dart';
import '../models/report_chart_type.dart';
import 'report_statistics_service.dart';

/// Punto de agrupación temporal para reportes.
class TemporalGroupPoint {
  const TemporalGroupPoint({
    required this.key,
    required this.label,
    required this.recordCount,
    required this.averageNeps,
    required this.minNeps,
    required this.maxNeps,
    required this.totalMts,
    required this.normalCount,
    required this.warningCount,
    required this.criticalCount,
    required this.reviewedCount,
    required this.correctiveActionCount,
    this.pctChangeFromPrevious,
  });

  final DateTime key;
  final String label;
  final int recordCount;
  final double averageNeps;
  final double minNeps;
  final double maxNeps;
  final double totalMts;
  final int normalCount;
  final int warningCount;
  final int criticalCount;
  final int reviewedCount;
  final int correctiveActionCount;
  final double? pctChangeFromPrevious;

  double get criticalPercentage =>
      recordCount == 0 ? 0 : (criticalCount / recordCount) * 100;
}

/// Agrupación detallada por dimensión (telar, tela, etc.).
class DimensionGroupStats {
  const DimensionGroupStats({
    required this.key,
    required this.recordCount,
    required this.averageNeps,
    required this.medianNeps,
    required this.minNeps,
    required this.maxNeps,
    required this.stdDev,
    required this.totalMts,
    required this.normalCount,
    required this.warningCount,
    required this.criticalCount,
    required this.pendingReview,
    required this.pendingCorrective,
    this.pctChangeFromPrevious,
  });

  final String key;
  final int recordCount;
  final double averageNeps;
  final double medianNeps;
  final double minNeps;
  final double maxNeps;
  final double stdDev;
  final double totalMts;
  final int normalCount;
  final int warningCount;
  final int criticalCount;
  final int pendingReview;
  final int pendingCorrective;
  final double? pctChangeFromPrevious;

  double get criticalPercentage =>
      recordCount == 0 ? 0 : (criticalCount / recordCount) * 100;
}

/// Servicio de agrupación para análisis por dimensiones y tiempo.
class ReportGroupingService {
  ReportGroupingService({
    AlertService? alerts,
    ReportStatisticsService? statistics,
  })  : _alerts = alerts ?? alertService,
        _stats = statistics ?? reportStatisticsService;

  final AlertService _alerts;
  final ReportStatisticsService _stats;

  List<TemporalGroupPoint> groupByTemporal(
    List<NepRecord> records,
    ReportTemporalGrouping grouping,
  ) {
    if (records.isEmpty) return const [];

    final map = <DateTime, List<NepRecord>>{};
    for (final r in records) {
      final key = _temporalKey(r.createdAt, grouping);
      map.putIfAbsent(key, () => []).add(r);
    }

    final keys = map.keys.toList()..sort();
    final points = <TemporalGroupPoint>[];
    TemporalGroupPoint? prev;

    for (final key in keys) {
      final items = map[key]!;
      final neps = items.map((r) => r.neps).toList();
      var normal = 0, warn = 0, crit = 0, reviewed = 0, actions = 0;
      for (final r in items) {
        switch (_alerts.getAlertLevel(r.neps)) {
          case AlertLevel.normal:
            normal++;
          case AlertLevel.advertencia:
            warn++;
          case AlertLevel.critico:
            crit++;
        }
        if (r.revisadoPorSupervisor) reviewed++;
        if (r.accionCorrectiva.isNotEmpty || r.historialAcciones.isNotEmpty) {
          actions++;
        }
      }

      final avg = neps.reduce((a, b) => a + b) / neps.length;
      double? pctChange;
      if (prev != null && prev.averageNeps > 0) {
        pctChange = ((avg - prev.averageNeps) / prev.averageNeps) * 100;
      }

      final point = TemporalGroupPoint(
        key: key,
        label: _temporalLabel(key, grouping),
        recordCount: items.length,
        averageNeps: avg,
        minNeps: neps.reduce((a, b) => a < b ? a : b),
        maxNeps: neps.reduce((a, b) => a > b ? a : b),
        totalMts: items.fold<double>(0, (s, r) => s + r.mtsCalculados),
        normalCount: normal,
        warningCount: warn,
        criticalCount: crit,
        reviewedCount: reviewed,
        correctiveActionCount: actions,
        pctChangeFromPrevious: pctChange,
      );
      points.add(point);
      prev = point;
    }
    return points;
  }

  List<DimensionGroupStats> groupByField(
    List<NepRecord> records,
    String Function(NepRecord) field, {
    List<NepRecord>? previousRecords,
  }) {
    final map = <String, List<NepRecord>>{};
    for (final r in records) {
      final key = field(r).trim();
      if (key.isEmpty) continue;
      map.putIfAbsent(key, () => []).add(r);
    }

    final prevMap = <String, double>{};
    if (previousRecords != null) {
      for (final entry in _avgByField(previousRecords, field).entries) {
        prevMap[entry.key] = entry.value;
      }
    }

    final result = <DimensionGroupStats>[];
    for (final entry in map.entries) {
      final items = entry.value;
      final neps = items.map((r) => r.neps).toList();
      var normal = 0, warn = 0, crit = 0, pendingRev = 0, pendingCorr = 0;
      for (final r in items) {
        final level = _alerts.getAlertLevel(r.neps);
        switch (level) {
          case AlertLevel.normal:
            normal++;
          case AlertLevel.advertencia:
            warn++;
          case AlertLevel.critico:
            crit++;
        }
        if (level != AlertLevel.normal && !r.revisadoPorSupervisor) {
          pendingRev++;
        }
        if (level != AlertLevel.normal &&
            r.accionCorrectiva.isEmpty &&
            r.historialAcciones.isEmpty) {
          pendingCorr++;
        }
      }

      final avg = neps.reduce((a, b) => a + b) / neps.length;
      double? pctChange;
      final prevAvg = prevMap[entry.key];
      if (prevAvg != null && prevAvg > 0) {
        pctChange = ((avg - prevAvg) / prevAvg) * 100;
      }

      result.add(
        DimensionGroupStats(
          key: entry.key,
          recordCount: items.length,
          averageNeps: avg,
          medianNeps: _stats.median(neps),
          minNeps: neps.reduce((a, b) => a < b ? a : b),
          maxNeps: neps.reduce((a, b) => a > b ? a : b),
          stdDev: _stats.standardDeviation(neps),
          totalMts: items.fold<double>(0, (s, r) => s + r.mtsCalculados),
          normalCount: normal,
          warningCount: warn,
          criticalCount: crit,
          pendingReview: pendingRev,
          pendingCorrective: pendingCorr,
          pctChangeFromPrevious: pctChange,
        ),
      );
    }

    result.sort((a, b) => b.averageNeps.compareTo(a.averageNeps));
    return result;
  }

  List<DimensionGroupStats> byTelar(
    List<NepRecord> records, {
    List<NepRecord>? previous,
  }) =>
      groupByField(records, (r) => r.telar, previousRecords: previous);

  List<DimensionGroupStats> byTela(
    List<NepRecord> records, {
    List<NepRecord>? previous,
  }) =>
      groupByField(records, (r) => r.tela, previousRecords: previous);

  List<DimensionGroupStats> byLote(
    List<NepRecord> records, {
    List<NepRecord>? previous,
  }) =>
      groupByField(records, (r) => r.loteTrama, previousRecords: previous);

  List<DimensionGroupStats> byTurno(
    List<NepRecord> records, {
    List<NepRecord>? previous,
  }) =>
      groupByField(records, (r) => r.turno, previousRecords: previous);

  List<DimensionGroupStats> byOperario(
    List<NepRecord> records, {
    List<NepRecord>? previous,
  }) =>
      groupByField(records, (r) => r.operario, previousRecords: previous);

  List<DimensionGroupStats> byLinea(
    List<NepRecord> records, {
    List<NepRecord>? previous,
  }) =>
      groupByField(records, (r) => r.lineaProduccion,
          previousRecords: previous);

  Map<String, double> _avgByField(
    List<NepRecord> records,
    String Function(NepRecord) field,
  ) {
    final map = <String, List<double>>{};
    for (final r in records) {
      final key = field(r).trim();
      if (key.isEmpty) continue;
      map.putIfAbsent(key, () => []).add(r.neps);
    }
    return map.map(
      (k, v) => MapEntry(k, v.reduce((a, b) => a + b) / v.length),
    );
  }

  DateTime _temporalKey(DateTime date, ReportTemporalGrouping grouping) {
    return switch (grouping) {
      ReportTemporalGrouping.hora => DateTime(
          date.year,
          date.month,
          date.day,
          date.hour,
        ),
      ReportTemporalGrouping.dia => DateTime(date.year, date.month, date.day),
      ReportTemporalGrouping.semana => () {
          final day = DateTime(date.year, date.month, date.day);
          return day.subtract(Duration(days: day.weekday - 1));
        }(),
      ReportTemporalGrouping.mes => DateTime(date.year, date.month),
      ReportTemporalGrouping.trimestre => () {
          final qMonth = ((date.month - 1) ~/ 3) * 3 + 1;
          return DateTime(date.year, qMonth);
        }(),
      ReportTemporalGrouping.semestre => DateTime(
          date.year,
          date.month <= 6 ? 1 : 7,
        ),
      ReportTemporalGrouping.ano => DateTime(date.year),
    };
  }

  String _temporalLabel(DateTime key, ReportTemporalGrouping grouping) {
    String two(int n) => n.toString().padLeft(2, '0');
    return switch (grouping) {
      ReportTemporalGrouping.hora =>
        '${two(key.day)}/${two(key.month)} ${two(key.hour)}:00',
      ReportTemporalGrouping.dia =>
        '${two(key.day)}/${two(key.month)}/${key.year}',
      ReportTemporalGrouping.semana =>
        'Sem ${two(key.day)}/${two(key.month)}/${key.year}',
      ReportTemporalGrouping.mes => '${_monthName(key.month)} ${key.year}',
      ReportTemporalGrouping.trimestre =>
        'T${((key.month - 1) ~/ 3) + 1} ${key.year}',
      ReportTemporalGrouping.semestre =>
        'S${key.month <= 6 ? 1 : 2} ${key.year}',
      ReportTemporalGrouping.ano => '${key.year}',
    };
  }

  String _monthName(int month) {
    const names = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    return names[month - 1];
  }

  /// Promedio móvil sobre serie temporal.
  List<double> movingAverage(List<double> values, int window) {
    if (values.isEmpty || window < 1) return values;
    final result = <double>[];
    for (var i = 0; i < values.length; i++) {
      final start = (i - window + 1).clamp(0, i);
      final slice = values.sublist(start, i + 1);
      result.add(slice.reduce((a, b) => a + b) / slice.length);
    }
    return result;
  }
}

final reportGroupingService = ReportGroupingService();
