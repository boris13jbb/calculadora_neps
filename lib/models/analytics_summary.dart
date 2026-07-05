import 'alert_level.dart';
import '../services/analytics_service.dart';
import 'time_series_point.dart';

/// Resumen analítico listo para KPIs, gráficas y exportación.
class AnalyticsSummary {
  const AnalyticsSummary({
    required this.totalRecords,
    required this.totalNeps,
    required this.averageNeps,
    required this.minNeps,
    required this.maxNeps,
    required this.totalMts,
    required this.alertDistribution,
    required this.timeSeries,
    required this.byTelar,
    required this.byTurno,
    required this.byOperario,
  });

  final int totalRecords;
  final double totalNeps;
  final double averageNeps;
  final double minNeps;
  final double maxNeps;
  final double totalMts;
  final AlertDistribution alertDistribution;
  final List<TimeSeriesPoint> timeSeries;
  final List<GroupNepsSummary> byTelar;
  final List<GroupNepsSummary> byTurno;
  final List<GroupNepsSummary> byOperario;

  int get criticalCount => alertDistribution.critico;
  int get warningCount => alertDistribution.advertencia;
  int get normalCount => alertDistribution.normal;

  double get normalPercentage =>
      alertDistribution.percentage(AlertLevel.normal);

  double get criticalPercentage =>
      alertDistribution.percentage(AlertLevel.critico);
}
