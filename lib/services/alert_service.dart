import 'package:flutter/material.dart';

import '../core/alert_config.dart';
import '../core/theme/app_theme.dart';
import '../models/alert_level.dart';
import '../models/nep_record.dart';

/// Clasificación, detección y recomendaciones de alertas por neps.
class AlertService {
  AlertService({AlertConfig config = defaultAlertConfig}) : _config = config;

  AlertConfig _config;

  AlertConfig get config => _config;

  void updateConfig(AlertConfig config) {
    _config = config;
  }

  /// Obtiene el nivel de alerta según la cantidad de neps.
  AlertLevel getAlertLevel(double neps) {
    if (!_config.alertasActivas) return AlertLevel.normal;

    final value = neps.round();
    if (value <= _config.limiteNormalMax) return AlertLevel.normal;
    if (value <= _config.limiteAdvertenciaMax) return AlertLevel.advertencia;
    return AlertLevel.critico;
  }

  /// Evaluación completa de un registro con recomendaciones.
  AlertEvaluation evaluateRecord(
    NepRecord record,
    List<NepRecord> allRecords,
  ) {
    final level = getAlertLevel(record.neps);
    return AlertEvaluation(
      level: level,
      recommendations: generateRecommendations(record, allRecords),
    );
  }

  /// Color recomendado para el estado de alerta.
  Color getAlertColor(AlertLevel level) {
    return switch (level) {
      AlertLevel.normal => AppColors.statusNormal,
      AlertLevel.advertencia => AppColors.statusWarning,
      AlertLevel.critico => AppColors.statusCritical,
    };
  }

  /// Color de fondo suave para filas o tarjetas.
  Color getAlertBackgroundColor(AlertLevel level) {
    return getAlertColor(level).withValues(alpha: 0.12);
  }

  /// Registros con estado crítico.
  List<NepRecord> detectCriticalRecords(List<NepRecord> records) {
    return records
        .where((r) => getAlertLevel(r.neps) == AlertLevel.critico)
        .toList();
  }

  /// Registros en advertencia.
  List<NepRecord> detectWarningRecords(List<NepRecord> records) {
    return records
        .where((r) => getAlertLevel(r.neps) == AlertLevel.advertencia)
        .toList();
  }

  /// Telares que tienen al menos un registro crítico.
  List<String> detectCriticalTelars(List<NepRecord> records) {
    return detectCriticalRecords(records)
        .map((r) => r.telar.trim())
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  /// Telares con reincidencia de alertas críticas.
  List<String> detectReincidentTelars(List<NepRecord> records) {
    return _telarSummaries(records)
        .where((s) => s.isReincident)
        .map((s) => s.telar)
        .toList();
  }

  /// Telares ordenados por total de neps descendente.
  List<TelarAlertSummary> detectTopTelarsByTotalNeps(
    List<NepRecord> records, {
    int limit = 10,
  }) {
    final sorted = _telarSummaries(records)
      ..sort((a, b) => b.totalNeps.compareTo(a.totalNeps));
    return sorted.take(limit).toList();
  }

  /// Telares ordenados por promedio de neps descendente.
  List<TelarAlertSummary> detectTopTelarsByAverageNeps(
    List<NepRecord> records, {
    int limit = 10,
  }) {
    final sorted = _telarSummaries(records)
      ..sort((a, b) => b.averageNeps.compareTo(a.averageNeps));
    return sorted.take(limit).toList();
  }

  /// Telas con mayor total de neps.
  List<GroupNepsSummary> detectTopTelasByNeps(
    List<NepRecord> records, {
    int limit = 10,
  }) {
    return _groupSummaries(records, (r) => r.tela).take(limit).toList();
  }

  /// Lotes/tramas más problemáticos por total de neps.
  List<GroupNepsSummary> detectTopLotesByNeps(
    List<NepRecord> records, {
    int limit = 10,
  }) {
    return _groupSummaries(records, (r) => r.loteTrama).take(limit).toList();
  }

  /// Tela más problemática (mayor total de neps).
  GroupNepsSummary? mostProblematicTela(List<NepRecord> records) {
    final top = detectTopTelasByNeps(records, limit: 1);
    return top.isEmpty ? null : top.first;
  }

  /// Lote/trama más problemático.
  GroupNepsSummary? mostProblematicLote(List<NepRecord> records) {
    final top = detectTopLotesByNeps(records, limit: 1);
    return top.isEmpty ? null : top.first;
  }

  /// Telar más crítico (más registros críticos, desempate por total neps).
  TelarAlertSummary? mostCriticalTelar(List<NepRecord> records) {
    final summaries = _telarSummaries(records)
      ..sort((a, b) {
        final byCritical = b.criticalCount.compareTo(a.criticalCount);
        if (byCritical != 0) return byCritical;
        return b.totalNeps.compareTo(a.totalNeps);
      });
    if (summaries.isEmpty) return null;
    final best = summaries.first;
    if (best.criticalCount == 0 && best.warningCount == 0) return null;
    return best;
  }

  /// Recomendaciones automáticas según contexto del registro.
  List<String> generateRecommendations(
    NepRecord record,
    List<NepRecord> allRecords,
  ) {
    final level = getAlertLevel(record.neps);
    final recommendations = <String>[];

    if (level == AlertLevel.normal) {
      return recommendations;
    }

    if (level == AlertLevel.advertencia || level == AlertLevel.critico) {
      recommendations.add('Revisar calibración del telar.');
    }

    if (record.loteTrama.trim().isNotEmpty) {
      recommendations.add('Verificar lote/trama.');
    }

    if (record.tela.trim().isNotEmpty) {
      recommendations.add('Inspeccionar tela asociada.');
    }

    if (isTelarReincident(record.telar, allRecords)) {
      recommendations.add(
        'Este telar presenta reincidencia, requiere revisión técnica.',
      );
    }

    if (level == AlertLevel.critico) {
      recommendations.add('Notificar a supervisor de calidad de inmediato.');
    }

    return recommendations.toSet().toList();
  }

  /// Indica si un telar es reincidente según configuración.
  bool isTelarReincident(String telar, List<NepRecord> records) {
    final normalized = telar.trim().toLowerCase();
    if (normalized.isEmpty) return false;

    final criticalForTelar = records.where((r) {
      return r.telar.trim().toLowerCase() == normalized &&
          getAlertLevel(r.neps) == AlertLevel.critico;
    }).toList();

    if (criticalForTelar.length < _config.cantidadReincidenciasCriticas) {
      return false;
    }

    if (_config.diasParaReincidencia <= 0) {
      return criticalForTelar.length >= _config.cantidadReincidenciasCriticas;
    }

    criticalForTelar.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    for (var i = 0;
        i <= criticalForTelar.length - _config.cantidadReincidenciasCriticas;
        i++) {
      final windowStart = criticalForTelar[i].createdAt;
      final windowEnd = windowStart.add(
        Duration(days: _config.diasParaReincidencia),
      );
      final countInWindow = criticalForTelar
          .where(
            (r) =>
                !r.createdAt.isBefore(windowStart) &&
                !r.createdAt.isAfter(windowEnd),
          )
          .length;
      if (countInWindow >= _config.cantidadReincidenciasCriticas) {
        return true;
      }
    }

    return false;
  }

  List<TelarAlertSummary> _telarSummaries(List<NepRecord> records) {
    final map = <String, List<NepRecord>>{};
    for (final record in records) {
      final key = record.telar.trim();
      if (key.isEmpty) continue;
      map.putIfAbsent(key, () => []).add(record);
    }

    return map.entries.map((entry) {
      final items = entry.value;
      final total = items.fold<double>(0, (s, r) => s + r.neps);
      final critical = items
          .where((r) => getAlertLevel(r.neps) == AlertLevel.critico)
          .length;
      final warning = items
          .where((r) => getAlertLevel(r.neps) == AlertLevel.advertencia)
          .length;
      return TelarAlertSummary(
        telar: entry.key,
        totalNeps: total,
        recordCount: items.length,
        averageNeps: items.isEmpty ? 0 : total / items.length,
        criticalCount: critical,
        warningCount: warning,
        isReincident: isTelarReincident(entry.key, records),
      );
    }).toList();
  }

  List<GroupNepsSummary> _groupSummaries(
    List<NepRecord> records,
    String Function(NepRecord) keySelector,
  ) {
    final map = <String, List<NepRecord>>{};
    for (final record in records) {
      final key = keySelector(record).trim();
      if (key.isEmpty) continue;
      map.putIfAbsent(key, () => []).add(record);
    }

    final summaries = map.entries.map((entry) {
      final items = entry.value;
      final total = items.fold<double>(0, (s, r) => s + r.neps);
      final critical = items
          .where((r) => getAlertLevel(r.neps) == AlertLevel.critico)
          .length;
      final warning = items
          .where((r) => getAlertLevel(r.neps) == AlertLevel.advertencia)
          .length;
      return GroupNepsSummary(
        key: entry.key,
        totalNeps: total,
        recordCount: items.length,
        averageNeps: items.isEmpty ? 0 : total / items.length,
        criticalCount: critical,
        warningCount: warning,
      );
    }).toList();

    summaries.sort((a, b) => b.totalNeps.compareTo(a.totalNeps));
    return summaries;
  }
}

/// Instancia compartida para uso en UI y exportaciones.
final AlertService alertService = AlertService();
