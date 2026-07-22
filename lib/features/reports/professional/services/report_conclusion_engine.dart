import '../models/report_comparison.dart';
import '../models/report_conclusion.dart';
import '../models/report_statistics.dart';

/// Motor local de conclusiones basado en reglas (sin IA externa).
class ReportConclusionEngine {
  const ReportConclusionEngine();

  ReportConclusion generate({
    required ReportStatistics statistics,
    ReportComparison? comparison,
    bool includeOperatorNote = true,
  }) {
    if (statistics.totalRecords == 0) {
      return const ReportConclusion(
        autoSummary:
            'No existen registros en el periodo y filtros seleccionados. '
            'Ajuste el rango o los criterios de filtrado para generar conclusiones.',
        enabled: true,
      );
    }

    final findings = <ReportFinding>[];

    // Resultado general
    final generalBuffer = StringBuffer();
    generalBuffer.write(
      'En el periodo analizado se registraron ${statistics.totalRecords} '
      'mediciones con un promedio de neps de '
      '${_fmt(statistics.averageNeps)}. ',
    );
    generalBuffer.write(
      'El ${statistics.normalPercentage.toStringAsFixed(1)}% de los registros '
      'se encuentra en estado normal. ',
    );

    // Tendencia
    final trend = statistics.qualityIndicators.tendenciaGeneral;
    generalBuffer.write(
      'La tendencia general detectada es: ${trend.label}. ',
    );
    findings.add(
      ReportFinding(
        category: 'Tendencia',
        text: 'Tendencia general: ${trend.label}.',
      ),
    );

    // Críticos
    if (statistics.criticalCount > 0) {
      findings.add(
        ReportFinding(
          category: 'Alertas',
          text:
              'Se identificaron ${statistics.criticalCount} registros críticos '
              '(${statistics.criticalPercentage.toStringAsFixed(1)}% del total).',
          severity: FindingSeverity.critical,
        ),
      );
    }

    // Pendientes de revisión
    if (statistics.pendingReviewCount > 0) {
      findings.add(
        ReportFinding(
          category: 'Seguimiento',
          text: 'Hay ${statistics.pendingReviewCount} registros con alerta '
              'pendientes de revisión por supervisor.',
          severity: FindingSeverity.warning,
        ),
      );
      generalBuffer.write(
        'Existen ${statistics.pendingReviewCount} revisiones pendientes. ',
      );
    }

    // Telares que requieren atención
    final q = statistics.qualityIndicators;
    if (q.telarMayorCriticos != null) {
      findings.add(
        ReportFinding(
          category: 'Telares',
          text: 'El telar ${q.telarMayorCriticos} presenta la mayor cantidad '
              'de registros críticos y requiere atención prioritaria.',
          severity: FindingSeverity.warning,
        ),
      );
    }

    if (q.telaMayorPromedio != null) {
      findings.add(
        ReportFinding(
          category: 'Telas',
          text:
              'La tela ${q.telaMayorPromedio} muestra el mayor promedio de neps, '
              'lo que sugiere mayor variabilidad en el proceso.',
        ),
      );
    }

    if (q.turnoMayorPromedio != null) {
      findings.add(
        ReportFinding(
          category: 'Turnos',
          text:
              'El turno ${q.turnoMayorPromedio} concentra la mayor incidencia '
              'promedio de neps en el periodo.',
        ),
      );
    }

    // Acciones correctivas
    if (statistics.withCorrectiveActionCount > 0) {
      findings.add(
        ReportFinding(
          category: 'Acciones correctivas',
          text:
              'Se registraron ${statistics.withCorrectiveActionCount} acciones '
              'correctivas con una tasa de cierre del '
              '${statistics.correctiveActionClosureRate.toStringAsFixed(1)}%.',
        ),
      );
    }

    // Comparación con periodo anterior
    if (comparison != null) {
      final dir = comparison.qualityVariation;
      findings.add(
        ReportFinding(
          category: 'Comparación',
          text: 'Frente al periodo anterior (${comparison.periodBLabel}), '
              'el promedio de neps ${dir == ComparisonDirection.mejoro ? 'disminuyó' : dir == ComparisonDirection.empeoro ? 'aumentó' : 'se mantuvo estable'} '
              '(${comparison.averageNepsPctChange.toStringAsFixed(1)}%).',
        ),
      );
      generalBuffer.write(
        'Comparado con ${comparison.periodBLabel}: variación de calidad ${dir.label}. ',
      );
    }

    // Nota sobre operarios
    if (includeOperatorNote && q.operarioMayorPromedio != null) {
      findings.add(
        ReportFinding(
          category: 'Proceso',
          text: 'El análisis por operario es informativo para el proceso. '
              'Los datos no constituyen valoración personal del desempeño individual.',
        ),
      );
    }

    // Recomendaciones preventivas automáticas
    final recommendations = <String>[];
    if (statistics.criticalPercentage > 10) {
      recommendations.add(
        'Revisar telares con mayor concentración de críticos y verificar '
        'condiciones de hilo y ajustes de máquina.',
      );
    }
    if (statistics.pendingReviewCount > 0) {
      recommendations.add(
        'Priorizar la revisión de alertas pendientes para cumplir con el '
        'protocolo de seguimiento.',
      );
    }
    if (trend == QualityTrend.empeorando) {
      recommendations.add(
        'Implementar acciones preventivas ante la tendencia al alza de neps.',
      );
    }
    if (statistics.correctiveActionClosureRate < 80 &&
        statistics.withCorrectiveActionCount > 0) {
      recommendations.add(
        'Fortalecer el cierre de acciones correctivas abiertas.',
      );
    }

    return ReportConclusion(
      findings: findings,
      autoSummary: generalBuffer.toString().trim(),
      manualRecommendations: recommendations.join('\n'),
      enabled: true,
    );
  }

  static String _fmt(double v) {
    if (v == v.roundToDouble()) return v.round().toString();
    return v.toStringAsFixed(2);
  }
}

const reportConclusionEngine = ReportConclusionEngine();
