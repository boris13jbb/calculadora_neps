/// Resultado de comparación entre dos periodos.
class ReportComparison {
  const ReportComparison({
    required this.periodALabel,
    required this.periodBLabel,
    this.recordsA = 0,
    this.recordsB = 0,
    this.averageNepsA = 0,
    this.averageNepsB = 0,
    this.criticalA = 0,
    this.criticalB = 0,
    this.warningA = 0,
    this.warningB = 0,
    this.totalMtsA = 0,
    this.totalMtsB = 0,
    this.reviewedA = 0,
    this.reviewedB = 0,
    this.correctiveActionsA = 0,
    this.correctiveActionsB = 0,
    this.improvedTelars = const [],
    this.worsenedTelars = const [],
    this.improvedFabrics = const [],
    this.improvedShifts = const [],
    this.qualityVariation = ComparisonDirection.sinCambio,
  });

  final String periodALabel;
  final String periodBLabel;
  final int recordsA;
  final int recordsB;
  final double averageNepsA;
  final double averageNepsB;
  final int criticalA;
  final int criticalB;
  final int warningA;
  final int warningB;
  final double totalMtsA;
  final double totalMtsB;
  final int reviewedA;
  final int reviewedB;
  final int correctiveActionsA;
  final int correctiveActionsB;
  final List<String> improvedTelars;
  final List<String> worsenedTelars;
  final List<String> improvedFabrics;
  final List<String> improvedShifts;
  final ComparisonDirection qualityVariation;

  double get averageNepsDiff => averageNepsA - averageNepsB;

  double get averageNepsPctChange => averageNepsB == 0
      ? 0
      : ((averageNepsA - averageNepsB) / averageNepsB) * 100;

  int get criticalDiff => criticalA - criticalB;

  double get criticalPctChange => criticalB == 0
      ? (criticalA > 0 ? 100 : 0)
      : ((criticalA - criticalB) / criticalB) * 100;

  int get warningDiff => warningA - warningB;

  double get mtsDiff => totalMtsA - totalMtsB;

  double get mtsPctChange =>
      totalMtsB == 0 ? 0 : ((totalMtsA - totalMtsB) / totalMtsB) * 100;

  ComparisonDirection directionFor(double diff, {bool lowerIsBetter = true}) {
    if (diff.abs() < 0.01) return ComparisonDirection.sinCambio;
    if (lowerIsBetter) {
      return diff < 0
          ? ComparisonDirection.mejoro
          : ComparisonDirection.empeoro;
    }
    return diff > 0 ? ComparisonDirection.mejoro : ComparisonDirection.empeoro;
  }
}

enum ComparisonDirection {
  mejoro('Mejoró'),
  empeoro('Empeoró'),
  sinCambio('Sin cambios significativos');

  const ComparisonDirection(this.label);

  final String label;
}
