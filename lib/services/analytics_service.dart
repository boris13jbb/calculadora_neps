import '../models/alert_level.dart';
import '../models/analytics_period.dart';
import '../models/analytics_summary.dart';
import '../models/nep_record.dart';
import '../models/time_series_point.dart';
import '../services/alert_service.dart';
import '../utils/record_filter_helper.dart';

/// Punto diario para gráficas de tendencia.
class DailyNepsPoint {
  const DailyNepsPoint({
    required this.date,
    required this.totalNeps,
    required this.recordCount,
    required this.averageNeps,
  });

  final DateTime date;
  final double totalNeps;
  final int recordCount;
  final double averageNeps;
}

/// Conteo por nivel de alerta.
class AlertDistribution {
  const AlertDistribution({
    required this.normal,
    required this.advertencia,
    required this.critico,
  });

  final int normal;
  final int advertencia;
  final int critico;

  int get total => normal + advertencia + critico;

  double percentage(AlertLevel level) {
    if (total == 0) return 0;
    final count = switch (level) {
      AlertLevel.normal => normal,
      AlertLevel.advertencia => advertencia,
      AlertLevel.critico => critico,
    };
    return (count / total) * 100;
  }
}

/// Cálculos analíticos para dashboard, reportes y alertas.
class AnalyticsService {
  AnalyticsService({AlertService? alerts}) : _alerts = alerts ?? alertService;

  final AlertService _alerts;

  int totalRegistros(List<NepRecord> records) => records.length;

  double totalNeps(List<NepRecord> records) =>
      records.fold(0.0, (sum, r) => sum + r.neps);

  double promedioNeps(List<NepRecord> records) {
    if (records.isEmpty) return 0;
    return totalNeps(records) / records.length;
  }

  int totalTelares(List<NepRecord> records) =>
      RecordFilterHelper.uniqueTelares(records).length;

  List<GroupNepsSummary> resumenPorTelar(List<NepRecord> records) {
    return _alerts
        .detectTopTelarsByTotalNeps(records, limit: records.length)
        .map(
          (s) => GroupNepsSummary(
            key: s.telar,
            totalNeps: s.totalNeps,
            recordCount: s.recordCount,
            averageNeps: s.averageNeps,
            criticalCount: s.criticalCount,
            warningCount: s.warningCount,
          ),
        )
        .toList();
  }

  List<GroupNepsSummary> resumenPorTela(List<NepRecord> records) =>
      _alerts.detectTopTelasByNeps(records, limit: records.length);

  List<GroupNepsSummary> resumenPorLoteTrama(List<NepRecord> records) =>
      _alerts.detectTopLotesByNeps(records, limit: records.length);

  List<DailyNepsPoint> tendenciaDiaria(List<NepRecord> records) {
    final map = <DateTime, List<NepRecord>>{};
    for (final record in records) {
      final day = DateTime(
        record.createdAt.year,
        record.createdAt.month,
        record.createdAt.day,
      );
      map.putIfAbsent(day, () => []).add(record);
    }

    final days = map.keys.toList()..sort();
    return days.map((day) {
      final items = map[day]!;
      final total = items.fold<double>(0, (s, r) => s + r.neps);
      return DailyNepsPoint(
        date: day,
        totalNeps: total,
        recordCount: items.length,
        averageNeps: items.isEmpty ? 0 : total / items.length,
      );
    }).toList();
  }

  /// Registros críticos agrupados por día (para tendencia de alertas).
  List<DailyNepsPoint> tendenciaCriticosDiaria(List<NepRecord> records) {
    final map = <DateTime, List<NepRecord>>{};
    for (final record in records) {
      if (_alerts.getAlertLevel(record.neps) != AlertLevel.critico) continue;
      final day = DateTime(
        record.createdAt.year,
        record.createdAt.month,
        record.createdAt.day,
      );
      map.putIfAbsent(day, () => []).add(record);
    }

    final days = map.keys.toList()..sort();
    return days.map((day) {
      final items = map[day]!;
      final total = items.fold<double>(0, (s, r) => s + r.neps);
      return DailyNepsPoint(
        date: day,
        totalNeps: total,
        recordCount: items.length,
        averageNeps: items.isEmpty ? 0 : total / items.length,
      );
    }).toList();
  }

  /// Top telares con desglose normal / advertencia / crítico.
  List<TelarAlertSummary> topTelaresConAlertas(
    List<NepRecord> records, {
    int limit = 6,
  }) =>
      _alerts.detectTopTelarsByTotalNeps(records, limit: limit);

  List<GroupNepsSummary> topTelaresPorNeps(
    List<NepRecord> records, {
    int limit = 10,
  }) {
    return _alerts
        .detectTopTelarsByTotalNeps(records, limit: limit)
        .map(
          (s) => GroupNepsSummary(
            key: s.telar,
            totalNeps: s.totalNeps,
            recordCount: s.recordCount,
            averageNeps: s.averageNeps,
            criticalCount: s.criticalCount,
            warningCount: s.warningCount,
          ),
        )
        .toList();
  }

  List<GroupNepsSummary> topTelasPorNeps(
    List<NepRecord> records, {
    int limit = 10,
  }) =>
      _alerts.detectTopTelasByNeps(records, limit: limit);

  List<GroupNepsSummary> topLotesPorNeps(
    List<NepRecord> records, {
    int limit = 10,
  }) =>
      _alerts.detectTopLotesByNeps(records, limit: limit);

  double porcentajeCriticos(List<NepRecord> records) {
    if (records.isEmpty) return 0;
    final critical = _alerts.detectCriticalRecords(records).length;
    return (critical / records.length) * 100;
  }

  AlertDistribution distribucionPorEstado(List<NepRecord> records) {
    var normal = 0;
    var advertencia = 0;
    var critico = 0;

    for (final record in records) {
      switch (_alerts.getAlertLevel(record.neps)) {
        case AlertLevel.normal:
          normal++;
        case AlertLevel.advertencia:
          advertencia++;
        case AlertLevel.critico:
          critico++;
      }
    }

    return AlertDistribution(
      normal: normal,
      advertencia: advertencia,
      critico: critico,
    );
  }

  List<GroupNepsSummary> promedioPorTelar(List<NepRecord> records) {
    final summaries = resumenPorTelar(records)
      ..sort((a, b) => b.averageNeps.compareTo(a.averageNeps));
    return summaries;
  }

  int countTelaresCriticos(List<NepRecord> records) =>
      _alerts.detectCriticalTelars(records).length;

  NepRecord? ultimaAlertaCritica(List<NepRecord> records) {
    final critical = _alerts.detectCriticalRecords(records);
    if (critical.isEmpty) return null;
    critical.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return critical.first;
  }

  double totalMtsCalculados(List<NepRecord> records) =>
      records.fold(0.0, (sum, r) => sum + r.mtsCalculados);

  double minNeps(List<NepRecord> records) {
    if (records.isEmpty) return 0;
    return records.map((r) => r.neps).reduce((a, b) => a < b ? a : b);
  }

  double maxNeps(List<NepRecord> records) {
    if (records.isEmpty) return 0;
    return records.map((r) => r.neps).reduce((a, b) => a > b ? a : b);
  }

  List<GroupNepsSummary> resumenPorTurno(List<NepRecord> records) =>
      _groupByField(records, (r) => r.turno);

  List<GroupNepsSummary> resumenPorOperario(List<NepRecord> records) =>
      _groupByField(records, (r) => r.operario);

  /// Agrupa registros según el periodo temporal seleccionado.
  List<TimeSeriesPoint> tendenciaPorPeriodo(
    List<NepRecord> records,
    AnalyticsPeriod period,
  ) {
    if (records.isEmpty) return const [];

    final effective =
        period == AnalyticsPeriod.custom ? AnalyticsPeriod.day : period;

    final map = <DateTime, List<NepRecord>>{};
    for (final record in records) {
      final key = _periodKey(record.createdAt, effective);
      map.putIfAbsent(key, () => []).add(record);
    }

    final keys = map.keys.toList()..sort();
    return keys
        .map((key) => _toTimeSeriesPoint(key, map[key]!, effective))
        .toList();
  }

  /// Construye un resumen completo para pantalla de gráficas y exportación.
  AnalyticsSummary buildSummary(
    List<NepRecord> records,
    AnalyticsPeriod period,
  ) {
    return AnalyticsSummary(
      totalRecords: totalRegistros(records),
      totalNeps: totalNeps(records),
      averageNeps: promedioNeps(records),
      minNeps: minNeps(records),
      maxNeps: maxNeps(records),
      totalMts: totalMtsCalculados(records),
      alertDistribution: distribucionPorEstado(records),
      timeSeries: tendenciaPorPeriodo(records, period),
      byTelar: topTelaresPorNeps(records, limit: 12),
      byTurno: resumenPorTurno(records),
      byOperario: resumenPorOperario(records),
    );
  }

  List<GroupNepsSummary> _groupByField(
    List<NepRecord> records,
    String Function(NepRecord) field,
  ) {
    final map = <String, List<NepRecord>>{};
    for (final record in records) {
      final key = field(record).trim();
      if (key.isEmpty) continue;
      map.putIfAbsent(key, () => []).add(record);
    }

    final summaries = map.entries.map((entry) {
      final items = entry.value;
      final total = items.fold<double>(0, (s, r) => s + r.neps);
      var critical = 0;
      var warning = 0;
      for (final item in items) {
        switch (_alerts.getAlertLevel(item.neps)) {
          case AlertLevel.normal:
            break;
          case AlertLevel.advertencia:
            warning++;
          case AlertLevel.critico:
            critical++;
        }
      }
      return GroupNepsSummary(
        key: entry.key,
        totalNeps: total,
        recordCount: items.length,
        averageNeps: items.isEmpty ? 0 : total / items.length,
        criticalCount: critical,
        warningCount: warning,
      );
    }).toList();

    summaries.sort((a, b) => b.totalNeps.compareTo(a.totalNeps));
    return summaries;
  }

  DateTime _periodKey(DateTime date, AnalyticsPeriod period) {
    final day = DateTime(date.year, date.month, date.day);
    return switch (period) {
      AnalyticsPeriod.day || AnalyticsPeriod.custom => day,
      AnalyticsPeriod.week => _weekStart(day),
      AnalyticsPeriod.month => DateTime(day.year, day.month),
      AnalyticsPeriod.year => DateTime(day.year),
    };
  }

  DateTime _weekStart(DateTime day) =>
      day.subtract(Duration(days: day.weekday - 1));

  TimeSeriesPoint _toTimeSeriesPoint(
    DateTime key,
    List<NepRecord> items,
    AnalyticsPeriod period,
  ) {
    final total = items.fold<double>(0, (s, r) => s + r.neps);
    final mts = items.fold<double>(0, (s, r) => s + r.mtsCalculados);
    return TimeSeriesPoint(
      periodStart: key,
      label: _periodLabel(key, period),
      totalNeps: total,
      recordCount: items.length,
      averageNeps: items.isEmpty ? 0 : total / items.length,
      totalMts: mts,
    );
  }

  String _periodLabel(DateTime key, AnalyticsPeriod period) {
    String two(int n) => n.toString().padLeft(2, '0');
    return switch (period) {
      AnalyticsPeriod.day ||
      AnalyticsPeriod.custom =>
        '${two(key.day)}/${two(key.month)}/${key.year}',
      AnalyticsPeriod.week => 'Sem ${key.day}/${two(key.month)}/${key.year}',
      AnalyticsPeriod.month => '${_monthName(key.month)} ${key.year}',
      AnalyticsPeriod.year => key.year.toString(),
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
}

/// Instancia compartida.
final AnalyticsService analyticsService = AnalyticsService();
