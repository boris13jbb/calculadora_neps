/// Punto de serie temporal para gráficas de tendencia o comparación.
class TimeSeriesPoint {
  const TimeSeriesPoint({
    required this.periodStart,
    required this.label,
    required this.totalNeps,
    required this.recordCount,
    required this.averageNeps,
    required this.totalMts,
  });

  /// Inicio del periodo (día, lunes de semana, primer día del mes o del año).
  final DateTime periodStart;
  final String label;
  final double totalNeps;
  final int recordCount;
  final double averageNeps;
  final double totalMts;
}
