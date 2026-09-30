export 'neps_classification.dart';

import '../core/constants.dart';
import 'neps_classification.dart';

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
    this.okCount = 0,
    this.mencionCount = 0,
    this.criticalCount = 0,
    this.segundaCalidadCount = 0,
  });

  final String key;
  final double totalNeps;
  final double totalMts;
  final int recordCount;
  final double averageNeps;
  final int okCount;
  final int mencionCount;
  final int criticalCount;
  final int segundaCalidadCount;

  /// Alias histórico: “advertencia” → Mención.
  int get warningCount => mencionCount;

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
    required this.okCount,
    required this.mencionCount,
    required this.criticalCount,
    required this.segundaCalidadCount,
    required this.isReincident,
  });

  final String telar;
  final double totalNeps;
  final double totalMts;
  final int recordCount;
  final double averageNeps;
  final int okCount;
  final int mencionCount;
  final int criticalCount;
  final int segundaCalidadCount;
  final bool isReincident;

  /// Alias histórico: “advertencia” → Mención.
  int get warningCount => mencionCount;

  /// Promedio de neps por metro cuadrado (área de prueba = 0.09 m²).
  double get nepsPorM2 =>
      recordCount <= 0 || averageNeps <= 0 ? 0 : averageNeps / testLengthM;
}
