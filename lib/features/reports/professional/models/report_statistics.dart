import 'report_metric_id.dart';

/// Valor calculado de una métrica del reporte.
class ReportMetricValue {
  const ReportMetricValue({
    required this.id,
    required this.label,
    required this.displayValue,
    this.numericValue,
    this.available = true,
  });

  final ReportMetricId id;
  final String label;
  final String displayValue;
  final double? numericValue;
  final bool available;
}

/// Estadísticas completas calculadas para el reporte.
class ReportStatistics {
  const ReportStatistics({
    this.totalRecords = 0,
    this.totalNeps = 0,
    this.averageNeps = 0,
    this.medianNeps = 0,
    this.modeNeps,
    this.minNeps = 0,
    this.maxNeps = 0,
    this.rangeNeps = 0,
    this.variance = 0,
    this.standardDeviation = 0,
    this.percentile25 = 0,
    this.percentile50 = 0,
    this.percentile75 = 0,
    this.percentile90 = 0,
    this.percentile95 = 0,
    this.coefficientOfVariation = 0,
    this.averageMts = 0,
    this.totalMts = 0,
    this.minMts = 0,
    this.maxMts = 0,
    this.normalCount = 0,
    this.warningCount = 0,
    this.criticalCount = 0,
    this.reviewedCount = 0,
    this.pendingReviewCount = 0,
    this.withCorrectiveActionCount = 0,
    this.withoutCorrectiveActionCount = 0,
    this.correctiveActionClosureRate = 0,
    this.telarCount = 0,
    this.fabricCount = 0,
    this.lotCount = 0,
    this.operatorCount = 0,
    this.shiftCount = 0,
    this.lineCount = 0,
    this.alertDistribution = const AlertDistributionStats(),
    this.qualityIndicators = const QualityIndicators(),
  });

  final int totalRecords;
  final double totalNeps;
  final double averageNeps;
  final double medianNeps;
  final double? modeNeps;
  final double minNeps;
  final double maxNeps;
  final double rangeNeps;
  final double variance;
  final double standardDeviation;
  final double percentile25;
  final double percentile50;
  final double percentile75;
  final double percentile90;
  final double percentile95;
  final double coefficientOfVariation;
  final double averageMts;
  final double totalMts;
  final double minMts;
  final double maxMts;
  final int normalCount;
  final int warningCount;
  final int criticalCount;
  final int reviewedCount;
  final int pendingReviewCount;
  final int withCorrectiveActionCount;
  final int withoutCorrectiveActionCount;
  final double correctiveActionClosureRate;
  final int telarCount;
  final int fabricCount;
  final int lotCount;
  final int operatorCount;
  final int shiftCount;
  final int lineCount;
  final AlertDistributionStats alertDistribution;
  final QualityIndicators qualityIndicators;

  double get normalPercentage =>
      totalRecords == 0 ? 0 : (normalCount / totalRecords) * 100;

  double get warningPercentage =>
      totalRecords == 0 ? 0 : (warningCount / totalRecords) * 100;

  double get criticalPercentage =>
      totalRecords == 0 ? 0 : (criticalCount / totalRecords) * 100;

  double get reviewComplianceRate {
    final alertTotal = warningCount + criticalCount;
    if (alertTotal == 0) return 100;
    return (reviewedCount / alertTotal) * 100;
  }

  List<ReportMetricValue> toMetricValues(Set<ReportMetricId> selected) {
    final all = <ReportMetricId, ReportMetricValue>{
      ReportMetricId.totalRegistros: ReportMetricValue(
        id: ReportMetricId.totalRegistros,
        label: ReportMetricId.totalRegistros.label,
        displayValue: '$totalRecords',
        numericValue: totalRecords.toDouble(),
      ),
      ReportMetricId.totalNeps: ReportMetricValue(
        id: ReportMetricId.totalNeps,
        label: ReportMetricId.totalNeps.label,
        displayValue: _fmt(totalNeps),
        numericValue: totalNeps,
      ),
      ReportMetricId.promedioNeps: ReportMetricValue(
        id: ReportMetricId.promedioNeps,
        label: ReportMetricId.promedioNeps.label,
        displayValue: _fmt(averageNeps),
        numericValue: averageNeps,
      ),
      ReportMetricId.medianaNeps: ReportMetricValue(
        id: ReportMetricId.medianaNeps,
        label: ReportMetricId.medianaNeps.label,
        displayValue: totalRecords > 0 ? _fmt(medianNeps) : 'N/D',
        numericValue: totalRecords > 0 ? medianNeps : null,
        available: totalRecords > 0,
      ),
      ReportMetricId.modaNeps: ReportMetricValue(
        id: ReportMetricId.modaNeps,
        label: ReportMetricId.modaNeps.label,
        displayValue: modeNeps != null ? _fmt(modeNeps!) : 'N/D',
        numericValue: modeNeps,
        available: modeNeps != null,
      ),
      ReportMetricId.minNeps: ReportMetricValue(
        id: ReportMetricId.minNeps,
        label: ReportMetricId.minNeps.label,
        displayValue: totalRecords > 0 ? _fmt(minNeps) : 'N/D',
        numericValue: totalRecords > 0 ? minNeps : null,
        available: totalRecords > 0,
      ),
      ReportMetricId.maxNeps: ReportMetricValue(
        id: ReportMetricId.maxNeps,
        label: ReportMetricId.maxNeps.label,
        displayValue: totalRecords > 0 ? _fmt(maxNeps) : 'N/D',
        numericValue: totalRecords > 0 ? maxNeps : null,
        available: totalRecords > 0,
      ),
      ReportMetricId.rangoNeps: ReportMetricValue(
        id: ReportMetricId.rangoNeps,
        label: ReportMetricId.rangoNeps.label,
        displayValue: totalRecords > 0 ? _fmt(rangeNeps) : 'N/D',
        numericValue: totalRecords > 0 ? rangeNeps : null,
        available: totalRecords > 0,
      ),
      ReportMetricId.desviacionEstandar: ReportMetricValue(
        id: ReportMetricId.desviacionEstandar,
        label: ReportMetricId.desviacionEstandar.label,
        displayValue: totalRecords > 1 ? _fmt(standardDeviation) : 'N/D',
        numericValue: totalRecords > 1 ? standardDeviation : null,
        available: totalRecords > 1,
      ),
      ReportMetricId.varianza: ReportMetricValue(
        id: ReportMetricId.varianza,
        label: ReportMetricId.varianza.label,
        displayValue: totalRecords > 1 ? _fmt(variance) : 'N/D',
        numericValue: totalRecords > 1 ? variance : null,
        available: totalRecords > 1,
      ),
      ReportMetricId.percentil25: _percentileMetric(
        ReportMetricId.percentil25,
        percentile25,
      ),
      ReportMetricId.percentil50: _percentileMetric(
        ReportMetricId.percentil50,
        percentile50,
      ),
      ReportMetricId.percentil75: _percentileMetric(
        ReportMetricId.percentil75,
        percentile75,
      ),
      ReportMetricId.percentil90: _percentileMetric(
        ReportMetricId.percentil90,
        percentile90,
      ),
      ReportMetricId.percentil95: _percentileMetric(
        ReportMetricId.percentil95,
        percentile95,
      ),
      ReportMetricId.coeficienteVariacion: ReportMetricValue(
        id: ReportMetricId.coeficienteVariacion,
        label: ReportMetricId.coeficienteVariacion.label,
        displayValue:
            totalRecords > 1 ? '${_fmt(coefficientOfVariation)}%' : 'N/D',
        numericValue: totalRecords > 1 ? coefficientOfVariation : null,
        available: totalRecords > 1,
      ),
      ReportMetricId.promedioMts: ReportMetricValue(
        id: ReportMetricId.promedioMts,
        label: ReportMetricId.promedioMts.label,
        displayValue: _fmt(averageMts),
        numericValue: averageMts,
      ),
      ReportMetricId.totalMts: ReportMetricValue(
        id: ReportMetricId.totalMts,
        label: ReportMetricId.totalMts.label,
        displayValue: _fmt(totalMts),
        numericValue: totalMts,
      ),
      ReportMetricId.minMts: ReportMetricValue(
        id: ReportMetricId.minMts,
        label: ReportMetricId.minMts.label,
        displayValue: totalRecords > 0 ? _fmt(minMts) : 'N/D',
        numericValue: totalRecords > 0 ? minMts : null,
        available: totalRecords > 0,
      ),
      ReportMetricId.maxMts: ReportMetricValue(
        id: ReportMetricId.maxMts,
        label: ReportMetricId.maxMts.label,
        displayValue: totalRecords > 0 ? _fmt(maxMts) : 'N/D',
        numericValue: totalRecords > 0 ? maxMts : null,
        available: totalRecords > 0,
      ),
      ReportMetricId.cantidadNormales: _countMetric(
        ReportMetricId.cantidadNormales,
        normalCount,
      ),
      ReportMetricId.cantidadAdvertencias: _countMetric(
        ReportMetricId.cantidadAdvertencias,
        warningCount,
      ),
      ReportMetricId.cantidadCriticos: _countMetric(
        ReportMetricId.cantidadCriticos,
        criticalCount,
      ),
      ReportMetricId.porcentajeNormales: _pctMetric(
        ReportMetricId.porcentajeNormales,
        normalPercentage,
      ),
      ReportMetricId.porcentajeAdvertencias: _pctMetric(
        ReportMetricId.porcentajeAdvertencias,
        warningPercentage,
      ),
      ReportMetricId.porcentajeCriticos: _pctMetric(
        ReportMetricId.porcentajeCriticos,
        criticalPercentage,
      ),
      ReportMetricId.cantidadRevisados: _countMetric(
        ReportMetricId.cantidadRevisados,
        reviewedCount,
      ),
      ReportMetricId.cantidadPendientes: _countMetric(
        ReportMetricId.cantidadPendientes,
        pendingReviewCount,
      ),
      ReportMetricId.porcentajeCumplimientoRevision: _pctMetric(
        ReportMetricId.porcentajeCumplimientoRevision,
        reviewComplianceRate,
      ),
      ReportMetricId.cantidadConAcciones: _countMetric(
        ReportMetricId.cantidadConAcciones,
        withCorrectiveActionCount,
      ),
      ReportMetricId.cantidadSinAcciones: _countMetric(
        ReportMetricId.cantidadSinAcciones,
        withoutCorrectiveActionCount,
      ),
      ReportMetricId.tasaCierreAcciones: _pctMetric(
        ReportMetricId.tasaCierreAcciones,
        correctiveActionClosureRate,
      ),
      ReportMetricId.cantidadTelares: _countMetric(
        ReportMetricId.cantidadTelares,
        telarCount,
      ),
      ReportMetricId.cantidadTelas: _countMetric(
        ReportMetricId.cantidadTelas,
        fabricCount,
      ),
      ReportMetricId.cantidadLotes: _countMetric(
        ReportMetricId.cantidadLotes,
        lotCount,
      ),
      ReportMetricId.cantidadOperarios: _countMetric(
        ReportMetricId.cantidadOperarios,
        operatorCount,
      ),
      ReportMetricId.cantidadTurnos: _countMetric(
        ReportMetricId.cantidadTurnos,
        shiftCount,
      ),
      ReportMetricId.cantidadLineas: _countMetric(
        ReportMetricId.cantidadLineas,
        lineCount,
      ),
    };

    return selected
        .map((id) => all[id])
        .whereType<ReportMetricValue>()
        .where((m) => m.available)
        .toList();
  }

  static String _fmt(double v) {
    if (v == v.roundToDouble()) return v.round().toString();
    return v.toStringAsFixed(2);
  }

  static ReportMetricValue _countMetric(ReportMetricId id, int count) {
    return ReportMetricValue(
      id: id,
      label: id.label,
      displayValue: '$count',
      numericValue: count.toDouble(),
    );
  }

  static ReportMetricValue _pctMetric(ReportMetricId id, double pct) {
    return ReportMetricValue(
      id: id,
      label: id.label,
      displayValue: '${_fmt(pct)}%',
      numericValue: pct,
    );
  }

  static ReportMetricValue _percentileMetric(ReportMetricId id, double value) {
    return ReportMetricValue(
      id: id,
      label: id.label,
      displayValue: _fmt(value),
      numericValue: value,
      available: value > 0 || id == ReportMetricId.percentil25,
    );
  }
}

class AlertDistributionStats {
  const AlertDistributionStats({
    this.normal = 0,
    this.advertencia = 0,
    this.critico = 0,
  });

  final int normal;
  final int advertencia;
  final int critico;

  int get total => normal + advertencia + critico;
}

/// Indicadores de calidad destacados.
class QualityIndicators {
  const QualityIndicators({
    this.telarMayorPromedio,
    this.telarMenorPromedio,
    this.telarMayorCriticos,
    this.telarMayorAdvertencias,
    this.telaMayorPromedio,
    this.telaMenorPromedio,
    this.loteMayorPromedio,
    this.loteMayorAlertas,
    this.turnoMayorPromedio,
    this.turnoMenorPromedio,
    this.operarioMayorPromedio,
    this.operarioMenorPromedio,
    this.lineaMayorPromedio,
    this.diaMayorValor,
    this.diaMenorPromedio,
    this.periodoMayorCriticos,
    this.mejorPeriodo,
    this.peorPeriodo,
    this.porcentajeDentroLimite = 0,
    this.indiceCalidadGeneral = 0,
    this.tendenciaGeneral = QualityTrend.estable,
  });

  final String? telarMayorPromedio;
  final String? telarMenorPromedio;
  final String? telarMayorCriticos;
  final String? telarMayorAdvertencias;
  final String? telaMayorPromedio;
  final String? telaMenorPromedio;
  final String? loteMayorPromedio;
  final String? loteMayorAlertas;
  final String? turnoMayorPromedio;
  final String? turnoMenorPromedio;
  final String? operarioMayorPromedio;
  final String? operarioMenorPromedio;
  final String? lineaMayorPromedio;
  final String? diaMayorValor;
  final String? diaMenorPromedio;
  final String? periodoMayorCriticos;
  final String? mejorPeriodo;
  final String? peorPeriodo;
  final double porcentajeDentroLimite;
  final double indiceCalidadGeneral;
  final QualityTrend tendenciaGeneral;
}

enum QualityTrend {
  mejorando('Mejorando'),
  estable('Estable'),
  empeorando('Empeorando');

  const QualityTrend(this.label);

  final String label;
}
