import '../core/constants.dart';

/// Nivel de alerta según cantidad de neps.
enum AlertLevel {  normal('Normal'),
  advertencia('Advertencia'),
  critico('Crítico');

  const AlertLevel(this.label);

  final String label;
}

/// Resultado de evaluación de alerta para un registro.
class AlertEvaluation {
  const AlertEvaluation({
    required this.level,
    required this.recommendations,
  });

  final AlertLevel level;
  final List<String> recommendations;
}

/// Resumen agrupado por clave (telar, tela, lote, etc.).
class GroupNepsSummary {
  const GroupNepsSummary({
    required this.key,
    required this.totalNeps,
    this.totalMts = 0,
    required this.recordCount,
    required this.averageNeps,
    this.criticalCount = 0,
    this.warningCount = 0,
  });

  final String key;
  final double totalNeps;
  final double totalMts;
  final int recordCount;
  final double averageNeps;
  final int criticalCount;
  final int warningCount;

  /// Promedio de neps por metro cuadrado (área de prueba = 0.09 m²).
  double get nepsPorM2 =>
      recordCount <= 0 || averageNeps <= 0 ? 0 : averageNeps / testLengthM;
}

/// Información de alerta para un telar.
class TelarAlertSummary {
  const TelarAlertSummary({
    required this.telar,
    required this.totalNeps,
    required this.totalMts,
    required this.recordCount,
    required this.averageNeps,
    required this.criticalCount,
    required this.warningCount,
    required this.isReincident,
  });

  final String telar;
  final double totalNeps;
  final double totalMts;
  final int recordCount;
  final double averageNeps;
  final int criticalCount;
  final int warningCount;
  final bool isReincident;

  /// Promedio de neps por metro cuadrado (área de prueba = 0.09 m²).
  double get nepsPorM2 =>
      recordCount <= 0 || averageNeps <= 0 ? 0 : averageNeps / testLengthM;
}
