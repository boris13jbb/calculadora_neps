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
    this.bestTelar,
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

  /// Telar con menor neps/m² en el periodo evaluado.
  final GroupNepsSummary? bestTelar;

  int get criticalCount => alertDistribution.critico;
  int get warningCount => alertDistribution.mencion;
  int get normalCount => alertDistribution.ok;
  int get mencionCount => alertDistribution.mencion;
  int get segundaCalidadCount => alertDistribution.segundaCalidad;
  int get okCount => alertDistribution.ok;

  double get normalPercentage =>
      alertDistribution.percentage(AlertLevel.ok);

  double get criticalPercentage =>
      alertDistribution.percentage(AlertLevel.critico);

  double get mencionPercentage =>
      alertDistribution.percentage(AlertLevel.mencion);

  double get segundaCalidadPercentage =>
      alertDistribution.percentage(AlertLevel.segundaCalidad);

  /// Promedio simple de los promedios por telar (un telar = un valor).
  double? get averageNepsPerTelar {
    if (byTelar.isEmpty) return null;
    final sum = byTelar.fold<double>(0, (s, g) => s + g.averageNeps);
    return sum / byTelar.length;
  }

  /// Promedio simple de los promedios por turno.
  double? get averageNepsPerTurno {
    if (byTurno.isEmpty) return null;
    final sum = byTurno.fold<double>(0, (s, g) => s + g.averageNeps);
    return sum / byTurno.length;
  }
}
