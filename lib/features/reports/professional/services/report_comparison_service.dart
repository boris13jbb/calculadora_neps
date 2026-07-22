import '../../../../models/nep_record.dart';
import '../models/report_comparison.dart';
import '../models/report_period_preset.dart';
import 'report_period_resolver.dart';
import 'report_statistics_service.dart';

/// Compara métricas entre dos periodos.
class ReportComparisonService {
  ReportComparisonService({
    ReportStatisticsService? statistics,
    ReportPeriodResolver? periodResolver,
  })  : _stats = statistics ?? reportStatisticsService,
        _periodResolver = periodResolver ?? reportPeriodResolver;

  final ReportStatisticsService _stats;
  final ReportPeriodResolver _periodResolver;

  ReportComparison compare(
    List<NepRecord> allRecords,
    ReportPeriodPreset currentPreset, {
    ReportPeriodPreset? comparisonPreset,
    DateTime? customFromA,
    DateTime? customToA,
    DateTime? customFromB,
    DateTime? customToB,
  }) {
    final rangeA = _periodResolver.resolve(
      currentPreset,
      customFrom: customFromA,
      customTo: customToA,
    );
    final presetB = comparisonPreset ?? _defaultComparisonPreset(currentPreset);
    final rangeB = presetB == ReportPeriodPreset.rangoPersonalizado
        ? _periodResolver.resolve(
            presetB,
            customFrom: customFromB,
            customTo: customToB,
          )
        : _periodResolver.previousPeriod(presetB) ??
            _periodResolver.resolve(presetB);

    final recordsA = _filterRange(allRecords, rangeA);
    final recordsB = _filterRange(allRecords, rangeB);

    final statsA = _stats.compute(recordsA);
    final statsB = _stats.compute(recordsB);

    final improvedTelars = <String>[];
    final worsenedTelars = <String>[];
    _compareGroups(
      recordsA,
      recordsB,
      (r) => r.telar,
      improvedTelars,
      worsenedTelars,
    );

    final improvedFabrics = <String>[];
    final worsenedFabrics = <String>[];
    _compareGroups(
      recordsA,
      recordsB,
      (r) => r.tela,
      improvedFabrics,
      worsenedFabrics,
    );

    final improvedShifts = <String>[];
    final worsenedShifts = <String>[];
    _compareGroups(
      recordsA,
      recordsB,
      (r) => r.turno,
      improvedShifts,
      worsenedShifts,
    );

    final comparison = ReportComparison(
      periodALabel: rangeA.displayLabel,
      periodBLabel: rangeB.displayLabel,
      recordsA: statsA.totalRecords,
      recordsB: statsB.totalRecords,
      averageNepsA: statsA.averageNeps,
      averageNepsB: statsB.averageNeps,
      criticalA: statsA.criticalCount,
      criticalB: statsB.criticalCount,
      warningA: statsA.warningCount,
      warningB: statsB.warningCount,
      totalMtsA: statsA.totalMts,
      totalMtsB: statsB.totalMts,
      reviewedA: statsA.reviewedCount,
      reviewedB: statsB.reviewedCount,
      correctiveActionsA: statsA.withCorrectiveActionCount,
      correctiveActionsB: statsB.withCorrectiveActionCount,
      improvedTelars: improvedTelars,
      worsenedTelars: worsenedTelars,
      improvedFabrics: improvedFabrics,
      improvedShifts: improvedShifts,
    );

    return ReportComparison(
      periodALabel: comparison.periodALabel,
      periodBLabel: comparison.periodBLabel,
      recordsA: comparison.recordsA,
      recordsB: comparison.recordsB,
      averageNepsA: comparison.averageNepsA,
      averageNepsB: comparison.averageNepsB,
      criticalA: comparison.criticalA,
      criticalB: comparison.criticalB,
      warningA: comparison.warningA,
      warningB: comparison.warningB,
      totalMtsA: comparison.totalMtsA,
      totalMtsB: comparison.totalMtsB,
      reviewedA: comparison.reviewedA,
      reviewedB: comparison.reviewedB,
      correctiveActionsA: comparison.correctiveActionsA,
      correctiveActionsB: comparison.correctiveActionsB,
      improvedTelars: improvedTelars,
      worsenedTelars: worsenedTelars,
      improvedFabrics: improvedFabrics,
      improvedShifts: improvedShifts,
      qualityVariation: comparison.directionFor(
        statsA.averageNeps - statsB.averageNeps,
      ),
    );
  }

  ReportPeriodPreset _defaultComparisonPreset(ReportPeriodPreset current) {
    return switch (current) {
      ReportPeriodPreset.hoy => ReportPeriodPreset.ayer,
      ReportPeriodPreset.estaSemana => ReportPeriodPreset.semanaAnterior,
      ReportPeriodPreset.esteMes => ReportPeriodPreset.mesAnterior,
      ReportPeriodPreset.esteTrimestre => ReportPeriodPreset.trimestreAnterior,
      ReportPeriodPreset.esteAno => ReportPeriodPreset.anoAnterior,
      _ => ReportPeriodPreset.mesAnterior,
    };
  }

  List<NepRecord> _filterRange(
    List<NepRecord> records,
    dynamic range,
  ) {
    if (range.isAll) return records;
    if (range.start == null || range.end == null) return records;
    return records
        .where((r) {
          final local = r.createdAt.toLocal();
          final day = DateTime(local.year, local.month, local.day);
          final startDay = DateTime(
            range.start!.year,
            range.start!.month,
            range.start!.day,
          );
          final endDay = DateTime(
            range.end!.year,
            range.end!.month,
            range.end!.day,
          );
          return !day.isBefore(startDay) && !day.isAfter(endDay);
        })
        .toList();
  }

  void _compareGroups(
    List<NepRecord> recordsA,
    List<NepRecord> recordsB,
    String Function(NepRecord) field,
    List<String> improved,
    List<String> worsened,
  ) {
    final avgA = _avgByField(recordsA, field);
    final avgB = _avgByField(recordsB, field);
    final keys = {...avgA.keys, ...avgB.keys};
    for (final key in keys) {
      final a = avgA[key];
      final b = avgB[key];
      if (a == null || b == null) continue;
      if (a < b - 0.01) {
        improved.add(key);
      } else if (a > b + 0.01) {
        worsened.add(key);
      }
    }
  }

  Map<String, double> _avgByField(
    List<NepRecord> records,
    String Function(NepRecord) field,
  ) {
    final map = <String, List<double>>{};
    for (final r in records) {
      final key = field(r).trim();
      if (key.isEmpty) continue;
      map.putIfAbsent(key, () => []).add(r.neps);
    }
    return map.map(
      (k, v) => MapEntry(k, v.reduce((a, b) => a + b) / v.length),
    );
  }
}

final reportComparisonService = ReportComparisonService();
