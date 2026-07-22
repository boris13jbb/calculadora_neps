import '../../../../models/alert_level.dart';
import '../../../../models/nep_record.dart';
import '../../../../services/alert_service.dart';
import '../../../../services/analytics_service.dart';
import '../../../../utils/record_filter_helper.dart';
import '../models/report_filter_configuration.dart';
import '../models/report_period_preset.dart';
import '../models/report_statistics.dart';
import 'report_period_resolver.dart';

/// Cálculos estadísticos avanzados para reportes profesionales.
class ReportStatisticsService {
  ReportStatisticsService({
    AlertService? alerts,
    AnalyticsService? analytics,
    ReportPeriodResolver? periodResolver,
  })  : _alerts = alerts ?? alertService,
        _analytics = analytics ?? analyticsService,
        _periodResolver = periodResolver ?? reportPeriodResolver;

  final AlertService _alerts;
  final AnalyticsService _analytics;
  final ReportPeriodResolver _periodResolver;

  /// Mediana de una lista numérica.
  double median(List<double> values) {
    if (values.isEmpty) return 0;
    final sorted = List<double>.from(values)..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return (sorted[mid - 1] + sorted[mid]) / 2;
  }

  /// Moda; devuelve null si no hay moda única o datos insuficientes.
  double? mode(List<double> values) {
    if (values.isEmpty) return null;
    final rounded = values.map((v) => v.roundToDouble()).toList();
    final counts = <double, int>{};
    for (final v in rounded) {
      counts[v] = (counts[v] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    final maxCount = counts.values.reduce((a, b) => a > b ? a : b);
    if (maxCount <= 1) return null;
    final modes = counts.entries.where((e) => e.value == maxCount).toList();
    if (modes.length != 1) return null;
    return modes.first.key;
  }

  /// Percentil con interpolación lineal (p en 0–100).
  double percentile(List<double> values, double p) {
    if (values.isEmpty) return 0;
    if (values.length == 1) return values.first;
    final sorted = List<double>.from(values)..sort();
    final rank = (p / 100) * (sorted.length - 1);
    final lower = rank.floor();
    final upper = rank.ceil();
    if (lower == upper) return sorted[lower];
    final weight = rank - lower;
    return sorted[lower] * (1 - weight) + sorted[upper] * weight;
  }

  double variance(List<double> values) {
    if (values.length < 2) return 0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final sumSq = values.fold<double>(
      0,
      (s, v) => s + (v - mean) * (v - mean),
    );
    return sumSq / values.length;
  }

  double standardDeviation(List<double> values) =>
      variance(values) <= 0 ? 0 : variance(values).sqrt();

  double coefficientOfVariation(List<double> values) {
    if (values.isEmpty) return 0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    if (mean == 0) return 0;
    return (standardDeviation(values) / mean.abs()) * 100;
  }

  List<NepRecord> filterByPeriod(
    List<NepRecord> records,
    ReportPeriodPreset preset, {
    DateTime? customFrom,
    DateTime? customTo,
  }) {
    final range = _periodResolver.resolve(
      preset,
      customFrom: customFrom,
      customTo: customTo,
    );
    if (range.isAll) return records;
    if (range.start == null || range.end == null) return records;

    // Comparación por día calendario local (incluye desde y hasta).
    // Evita perder registros por desfases UTC vs hora local.
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

    if (startDay.isAfter(endDay)) {
      return const [];
    }

    return records.where((r) {
      final local = r.createdAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      return !day.isBefore(startDay) && !day.isAfter(endDay);
    }).toList();
  }

  List<NepRecord> applyFilters(
    List<NepRecord> records,
    ReportFilterConfiguration filters,
  ) {
    return records.where((r) => _matches(r, filters)).toList();
  }

  bool _matches(NepRecord record, ReportFilterConfiguration f) {
    if (f.telares.isNotEmpty && !f.telares.contains(record.telar)) {
      return false;
    }
    if (f.telas.isNotEmpty && !f.telas.contains(record.tela)) return false;
    if (f.lotes.isNotEmpty && !f.lotes.contains(record.loteTrama)) {
      return false;
    }
    if (f.turnos.isNotEmpty && !f.turnos.contains(record.turno)) return false;
    if (f.operarios.isNotEmpty && !f.operarios.contains(record.operario)) {
      return false;
    }
    if (f.lineas.isNotEmpty && !f.lineas.contains(record.lineaProduccion)) {
      return false;
    }
    if (f.alertLevel != null &&
        _alerts.getAlertLevel(record.neps) != f.alertLevel) {
      return false;
    }
    if (f.revisadoSupervisor != null &&
        record.revisadoPorSupervisor != f.revisadoSupervisor) {
      return false;
    }
    if (f.conAccionCorrectiva != null) {
      final has = record.accionCorrectiva.trim().isNotEmpty ||
          record.historialAcciones.isNotEmpty;
      if (has != f.conAccionCorrectiva) return false;
    }
    if (f.responsableRevision != null &&
        f.responsableRevision!.isNotEmpty &&
        record.responsableRevision != f.responsableRevision) {
      return false;
    }
    if (f.usuarioCreador != null &&
        f.usuarioCreador!.isNotEmpty &&
        (record.createdByEmail ?? record.createdByUid ?? '') !=
            f.usuarioCreador) {
      return false;
    }
    if (f.rolCreador != null &&
        f.rolCreador!.isNotEmpty &&
        record.createdByRole != f.rolCreador) {
      return false;
    }
    if (f.conObservaciones != null) {
      final has = record.observacion.trim().isNotEmpty;
      if (has != f.conObservaciones) return false;
    }
    if (f.nepsMin != null && record.neps < f.nepsMin!) return false;
    if (f.nepsMax != null && record.neps > f.nepsMax!) return false;
    final mts = record.mtsCalculados;
    if (f.mtsMin != null && mts < f.mtsMin!) return false;
    if (f.mtsMax != null && mts > f.mtsMax!) return false;

    final search = f.searchText.trim().toLowerCase();
    if (search.isNotEmpty) {
      final haystack = [
        record.tela,
        record.loteTrama,
        record.telar,
        record.turno,
        record.operario,
        record.lineaProduccion,
        record.observacion,
        record.accionCorrectiva,
        record.neps.toString(),
      ].join(' ').toLowerCase();
      if (!haystack.contains(search)) return false;
    }
    return true;
  }

  ReportStatistics compute(List<NepRecord> records) {
    if (records.isEmpty) return const ReportStatistics();

    final nepsValues = records.map((r) => r.neps).toList();
    final mtsValues = records.map((r) => r.mtsCalculados).toList();
    final dist = _analytics.distribucionPorEstado(records);

    var reviewed = 0;
    var pending = 0;
    var withAction = 0;
    var withoutAction = 0;
    var closedActions = 0;

    for (final r in records) {
      final level = _alerts.getAlertLevel(r.neps);
      if (level != AlertLevel.normal) {
        if (r.revisadoPorSupervisor) {
          reviewed++;
        } else {
          pending++;
        }
      }
      final hasAction = r.accionCorrectiva.trim().isNotEmpty ||
          r.historialAcciones.isNotEmpty;
      if (hasAction) {
        withAction++;
        if (r.revisadoPorSupervisor) closedActions++;
      } else {
        withoutAction++;
      }
    }

    final quality = _computeQualityIndicators(records);

    return ReportStatistics(
      totalRecords: records.length,
      totalNeps: nepsValues.reduce((a, b) => a + b),
      averageNeps: nepsValues.reduce((a, b) => a + b) / records.length,
      medianNeps: median(nepsValues),
      modeNeps: mode(nepsValues),
      minNeps: nepsValues.reduce((a, b) => a < b ? a : b),
      maxNeps: nepsValues.reduce((a, b) => a > b ? a : b),
      rangeNeps: nepsValues.reduce((a, b) => a > b ? a : b) -
          nepsValues.reduce((a, b) => a < b ? a : b),
      variance: variance(nepsValues),
      standardDeviation: standardDeviation(nepsValues),
      percentile25: percentile(nepsValues, 25),
      percentile50: percentile(nepsValues, 50),
      percentile75: percentile(nepsValues, 75),
      percentile90: percentile(nepsValues, 90),
      percentile95: percentile(nepsValues, 95),
      coefficientOfVariation: coefficientOfVariation(nepsValues),
      averageMts: mtsValues.reduce((a, b) => a + b) / records.length,
      totalMts: mtsValues.reduce((a, b) => a + b),
      minMts: mtsValues.reduce((a, b) => a < b ? a : b),
      maxMts: mtsValues.reduce((a, b) => a > b ? a : b),
      normalCount: dist.normal,
      warningCount: dist.advertencia,
      criticalCount: dist.critico,
      reviewedCount: reviewed,
      pendingReviewCount: pending,
      withCorrectiveActionCount: withAction,
      withoutCorrectiveActionCount: withoutAction,
      correctiveActionClosureRate:
          withAction == 0 ? 0 : (closedActions / withAction) * 100,
      telarCount: RecordFilterHelper.uniqueTelares(records).length,
      fabricCount: RecordFilterHelper.uniqueTelas(records).length,
      lotCount: RecordFilterHelper.uniqueLotes(records).length,
      operatorCount: RecordFilterHelper.uniqueOperarios(records).length,
      shiftCount: RecordFilterHelper.uniqueTurnos(records).length,
      lineCount: RecordFilterHelper.uniqueLineas(records).length,
      alertDistribution: AlertDistributionStats(
        normal: dist.normal,
        advertencia: dist.advertencia,
        critico: dist.critico,
      ),
      qualityIndicators: quality,
    );
  }

  QualityIndicators _computeQualityIndicators(List<NepRecord> records) {
    final byTelar = _analytics.promedioPorTelar(records);
    final byTela = _analytics.resumenPorTela(records);
    final byLote = _analytics.resumenPorLoteTrama(records);
    final byTurno = _analytics.resumenPorTurno(records);
    final byOperario = _analytics.resumenPorOperario(records);
    final byLinea = _groupByLine(records);

    String? maxAvg(List<dynamic> items, String Function(dynamic) key) {
      if (items.isEmpty) return null;
      items.sort((a, b) => b.averageNeps.compareTo(a.averageNeps));
      return key(items.first);
    }

    String? minAvg(List<dynamic> items, String Function(dynamic) key) {
      if (items.isEmpty) return null;
      final valid = items.where((s) => s.averageNeps > 0).toList();
      if (valid.isEmpty) return null;
      valid.sort((a, b) => a.averageNeps.compareTo(b.averageNeps));
      return key(valid.first);
    }

    final telarCrit = List.from(byTelar)
      ..sort((a, b) => b.criticalCount.compareTo(a.criticalCount));
    final telarWarn = List.from(byTelar)
      ..sort((a, b) => b.warningCount.compareTo(a.warningCount));

    final daily = _analytics.tendenciaDiaria(records);
    String? bestDay;
    String? worstDay;
    if (daily.isNotEmpty) {
      daily.sort((a, b) => b.averageNeps.compareTo(a.averageNeps));
      worstDay = _formatDay(daily.first.date);
      daily.sort((a, b) => a.averageNeps.compareTo(b.averageNeps));
      bestDay = _formatDay(daily.first.date);
    }

    final normalPct = records.isEmpty
        ? 0.0
        : (_analytics.distribucionPorEstado(records).normal / records.length) *
            100;

    final qualityIndex = (100 - _analytics.porcentajeCriticos(records))
        .toDouble()
        .clamp(0.0, 100.0);

    return QualityIndicators(
      telarMayorPromedio: maxAvg(byTelar, (s) => s.key),
      telarMenorPromedio: minAvg(byTelar, (s) => s.key),
      telarMayorCriticos: telarCrit.isNotEmpty ? telarCrit.first.key : null,
      telarMayorAdvertencias: telarWarn.isNotEmpty ? telarWarn.first.key : null,
      telaMayorPromedio: maxAvg(byTela, (s) => s.key),
      telaMenorPromedio: minAvg(byTela, (s) => s.key),
      loteMayorPromedio: maxAvg(byLote, (s) => s.key),
      loteMayorAlertas: byLote.isNotEmpty
          ? (byLote
                ..sort(
                  (a, b) => (b.criticalCount + b.warningCount)
                      .compareTo(a.criticalCount + a.warningCount),
                ))
              .first
              .key
          : null,
      turnoMayorPromedio: maxAvg(byTurno, (s) => s.key),
      turnoMenorPromedio: minAvg(byTurno, (s) => s.key),
      operarioMayorPromedio: maxAvg(byOperario, (s) => s.key),
      operarioMenorPromedio: minAvg(byOperario, (s) => s.key),
      lineaMayorPromedio: maxAvg(byLinea, (s) => s.key),
      diaMayorValor: worstDay,
      diaMenorPromedio: bestDay,
      porcentajeDentroLimite: normalPct,
      indiceCalidadGeneral: qualityIndex,
      tendenciaGeneral: _detectTrend(records),
    );
  }

  List<dynamic> _groupByLine(List<NepRecord> records) {
    return _analytics.resumenPorTurno(
      records.where((r) => r.lineaProduccion.trim().isNotEmpty).toList(),
    );
  }

  QualityTrend _detectTrend(List<NepRecord> records) {
    final series = _analytics.tendenciaDiaria(records);
    if (series.length < 3) return QualityTrend.estable;
    final firstHalf = series.take(series.length ~/ 2).toList();
    final secondHalf = series.skip(series.length ~/ 2).toList();
    final avgFirst = firstHalf.isEmpty
        ? 0.0
        : firstHalf.fold<double>(0, (s, p) => s + p.averageNeps) /
            firstHalf.length;
    final avgSecond = secondHalf.isEmpty
        ? 0.0
        : secondHalf.fold<double>(0, (s, p) => s + p.averageNeps) /
            secondHalf.length;
    final diff = avgSecond - avgFirst;
    if (diff.abs() < 1) return QualityTrend.estable;
    return diff < 0 ? QualityTrend.mejorando : QualityTrend.empeorando;
  }

  String _formatDay(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

extension on double {
  double sqrt() {
    if (this <= 0) return 0;
    var x = this;
    var y = (x + 1) / 2;
    while ((y - x).abs() > 1e-10) {
      x = y;
      y = (x + this / x) / 2;
    }
    return x;
  }
}

final reportStatisticsService = ReportStatisticsService();
