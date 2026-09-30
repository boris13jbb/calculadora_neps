import '../core/neps_quality_criteria.dart';

/// Clasificación oficial de calidad según NEPS/m² y/o puntaje.
///
/// Es la única fuente de verdad semántica para OK / Mención / Crítico /
/// 2da Calidad. [AlertLevel] es un alias de este enum para compatibilidad
/// con el resto de la app (filtros, Firestore, UI).
enum NepsClassification {
  ok(
    label: 'OK',
    displayLabel: 'OK',
    recommendation: null,
    severityRank: 0,
  ),
  mencion(
    label: 'Mención',
    displayLabel: 'Mención',
    recommendation: null,
    severityRank: 1,
  ),
  critico(
    label: 'Crítico',
    displayLabel: 'Crítico — Realizar Ajuste',
    recommendation: 'Realizar Ajuste',
    severityRank: 2,
  ),
  segundaCalidad(
    label: '2da Calidad',
    displayLabel: '2da Calidad',
    recommendation: null,
    severityRank: 3,
  );

  const NepsClassification({
    required this.label,
    required this.displayLabel,
    required this.recommendation,
    required this.severityRank,
  });

  /// Nombre corto visible (chips, columnas, filtros).
  final String label;

  /// Texto completo para detalle / informes (incluye recomendación si aplica).
  final String displayLabel;

  /// Acción recomendada, si existe.
  final String? recommendation;

  /// Orden de severidad (0 = mejor calidad).
  final int severityRank;

  bool get isOk => this == NepsClassification.ok;

  bool get requiresFollowUp => this != NepsClassification.ok;

  bool get isSevere =>
      this == NepsClassification.critico ||
      this == NepsClassification.segundaCalidad;

  /// Código persistido en Firestore / preferencias (`alertLevel`).
  String get storageCode => name;
}

/// Alias histórico: el “nivel de alerta” de la app es la calificación NEPS.
typedef AlertLevel = NepsClassification;

/// Clasifica una medición usando puntaje y/o NEPS/m².
///
/// - Si se aporta [score], es la fuente primaria (coincide con `NepRecord.neps`).
/// - Si solo se aporta [nepsPerM2], se clasifica con los topes inclusivos
///   documentados en [NepsQualityCriteria].
/// - Si se aportan ambos y discrepan, gana el [score] (dato de captura).
NepsClassification classifyNeps({
  double? nepsPerM2,
  int? score,
}) {
  if (score == null && nepsPerM2 == null) {
    throw ArgumentError('Debe indicarse nepsPerM2 y/o score.');
  }

  if (score != null) {
    return classifyNepsByScore(score);
  }
  return classifyNepsByNepsPerM2(nepsPerM2!);
}

NepsClassification classifyNepsByScore(int score) {
  if (score <= NepsQualityCriteria.okMaxScore) {
    return NepsClassification.ok;
  }
  if (score <= NepsQualityCriteria.mencionMaxScore) {
    return NepsClassification.mencion;
  }
  if (score <= NepsQualityCriteria.criticoMaxScore) {
    return NepsClassification.critico;
  }
  return NepsClassification.segundaCalidad;
}

NepsClassification classifyNepsByNepsPerM2(double nepsPerM2) {
  if (nepsPerM2 <= NepsQualityCriteria.okMaxNepsPerM2) {
    return NepsClassification.ok;
  }
  if (nepsPerM2 <= NepsQualityCriteria.mencionMaxNepsPerM2) {
    return NepsClassification.mencion;
  }
  if (nepsPerM2 <= NepsQualityCriteria.criticoMaxNepsPerM2) {
    return NepsClassification.critico;
  }
  return NepsClassification.segundaCalidad;
}
