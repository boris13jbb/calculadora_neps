import 'constants.dart';

/// Criterios oficiales de calificación NEPS (fuente única de umbrales).
///
/// Relación canónica: `NEPS/m² = puntaje / [testLengthM]` y
/// `puntaje = neps` capturados en el área de prueba (0.09 m²).
///
/// Convención de límites (inclusivos en el tope de cada rango de puntaje):
/// - OK: puntaje 0–18 ⇔ NEPS/m² ≤ 200 (incluye exactamente 200)
/// - Mención: 19–45 ⇔ 200 < NEPS/m² ≤ 500 (incluye exactamente 500)
/// - Crítico: 46–54 ⇔ 500 < NEPS/m² ≤ 600 (incluye exactamente 600)
/// - 2da Calidad: ≥ 55 ⇔ NEPS/m² > 600
///
/// Esta convención cierra la ambigüedad de los criterios redactados con
/// desigualdades estrictas en NEPS/m², alineándolos con los rangos de puntaje
/// oficiales y con el patrón histórico `value <= limite` del proyecto.
class NepsQualityCriteria {
  NepsQualityCriteria._();

  /// Tope inclusivo de NEPS/m² para OK.
  static const double okMaxNepsPerM2 = 200;

  /// Tope inclusivo de NEPS/m² para Mención.
  static const double mencionMaxNepsPerM2 = 500;

  /// Tope inclusivo de NEPS/m² para Crítico.
  static const double criticoMaxNepsPerM2 = 600;

  /// Tope inclusivo de puntaje (neps crudos) para OK.
  static const int okMaxScore = 18;

  /// Tope inclusivo de puntaje para Mención.
  static const int mencionMaxScore = 45;

  /// Tope inclusivo de puntaje para Crítico.
  static const int criticoMaxScore = 54;

  /// Convierte puntaje (neps en 0.09 m²) a NEPS/m².
  static double nepsPerM2FromScore(num score) => score / testLengthM;

  /// Estima puntaje entero desde NEPS/m² (redondeo al entero más cercano).
  static int scoreFromNepsPerM2(double nepsPerM2) =>
      (nepsPerM2 * testLengthM).round();
}
