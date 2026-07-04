import '../models/alert_level.dart';
import '../models/nep_record.dart';
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
}

/// Instancia compartida.
final AnalyticsService analyticsService = AnalyticsService();
