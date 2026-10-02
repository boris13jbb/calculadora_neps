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

  /// Interruptor operativo de alertas/notificaciones.
  ///
  /// No altera la calificación de calidad ([getAlertLevel]).
  bool get alertsEnabled => _config.alertasActivas;

  /// Obtiene la calificación oficial según el puntaje (neps crudos).
  ///
  /// [neps] es el valor capturado en el área de prueba (0.09 m²); equivale al
  /// puntaje 0–55+ de los criterios oficiales.
  ///
  /// Siempre usa [classifyNeps]; [alertasActivas] no modifica el resultado.
  AlertLevel getAlertLevel(double neps) {
    return classifyNeps(score: neps.round());
  }

  /// Indica si debe dispararse una alerta/notificación operativa para [level].
  ///
  /// Separado de la clasificación de calidad: con alertas desactivadas la
  /// calificación sigue siendo la oficial, pero no se eleva la alerta.
  bool shouldRaiseAlert(AlertLevel level) =>
      _config.alertasActivas && level != AlertLevel.ok;

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

  /// Color recomendado para el estado de calificación.
  Color getAlertColor(AlertLevel level) {
    return switch (level) {
      AlertLevel.ok => AppColors.statusNormal,
      AlertLevel.mencion => AppColors.statusWarning,
      AlertLevel.critico => AppColors.statusCritical,
      AlertLevel.segundaCalidad => AppColors.statusSecondQuality,
    };
  }

  /// Color de fondo suave para filas o tarjetas.
  Color getAlertBackgroundColor(AlertLevel level) {
    return getAlertColor(level).withValues(alpha: 0.12);
  }

  /// Registros con calificación Crítico.
  List<NepRecord> detectCriticalRecords(List<NepRecord> records) {
    return records
        .where((r) => getAlertLevel(r.neps) == AlertLevel.critico)
        .toList();
  }

  /// Registros con calificación 2da Calidad.
  List<NepRecord> detectSecondQualityRecords(List<NepRecord> records) {
    return records
        .where((r) => getAlertLevel(r.neps) == AlertLevel.segundaCalidad)
        .toList();
  }

  /// Registros severos (Crítico o 2da Calidad).
  List<NepRecord> detectSevereRecords(List<NepRecord> records) {
    return records.where((r) => getAlertLevel(r.neps).isSevere).toList();
  }

  /// Registros en Mención.
  List<NepRecord> detectMencionRecords(List<NepRecord> records) {
    return records
        .where((r) => getAlertLevel(r.neps) == AlertLevel.mencion)
        .toList();
  }

  /// Alias histórico de [detectMencionRecords].
  List<NepRecord> detectWarningRecords(List<NepRecord> records) =>
      detectMencionRecords(records);

  /// Telares que tienen al menos un registro severo.
  List<String> detectCriticalTelars(List<NepRecord> records) {
    return detectSevereRecords(records)
        .map((r) => r.telar.trim())
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  /// Telares con reincidencia de calificaciones severas.
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

  /// Telar más crítico (más severos, desempate por total neps).
  TelarAlertSummary? mostCriticalTelar(List<NepRecord> records) {
    final summaries = _telarSummaries(records)
      ..sort((a, b) {
        final severeA = a.criticalCount + a.segundaCalidadCount;
        final severeB = b.criticalCount + b.segundaCalidadCount;
        final bySevere = severeB.compareTo(severeA);
        if (bySevere != 0) return bySevere;
        return b.totalNeps.compareTo(a.totalNeps);
      });
    if (summaries.isEmpty) return null;
    final best = summaries.first;
    if (best.criticalCount == 0 &&
        best.segundaCalidadCount == 0 &&
        best.mencionCount == 0) {
      return null;
    }
    return best;
  }

  /// Recomendaciones automáticas según contexto del registro.
  List<String> generateRecommendations(
    NepRecord record,
    List<NepRecord> allRecords,
  ) {
    final level = getAlertLevel(record.neps);
    final recommendations = <String>[];

    if (level == AlertLevel.ok) {
      return recommendations;
    }

    if (level.recommendation != null) {
      recommendations.add(level.recommendation!);
    }

    if (level == AlertLevel.mencion || level.isSevere) {
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

    if (level.isSevere) {
      recommendations.add('Notificar a supervisor de calidad de inmediato.');
    }

    return recommendations.toSet().toList();
  }

  /// Indica si un telar es reincidente según configuración.
  bool isTelarReincident(String telar, List<NepRecord> records) {
    final normalized = telar.trim().toLowerCase();
    if (normalized.isEmpty) return false;

    final severeForTelar = records.where((r) {
      return r.telar.trim().toLowerCase() == normalized &&
          getAlertLevel(r.neps).isSevere;
    }).toList();

    if (severeForTelar.length < _config.cantidadReincidenciasCriticas) {
      return false;
    }

    if (_config.diasParaReincidencia <= 0) {
      return severeForTelar.length >= _config.cantidadReincidenciasCriticas;
    }

    severeForTelar.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    for (var i = 0;
        i <= severeForTelar.length - _config.cantidadReincidenciasCriticas;
        i++) {
      final windowStart = severeForTelar[i].createdAt;
      final windowEnd = windowStart.add(
        Duration(days: _config.diasParaReincidencia),
      );
      final countInWindow = severeForTelar
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
      final totalMts = items.fold<double>(0, (s, r) => s + r.mtsCalculados);
      final counts = _countByLevel(items);
      return TelarAlertSummary(
        telar: entry.key,
        totalNeps: total,
        totalMts: totalMts,
        recordCount: items.length,
        averageNeps: items.isEmpty ? 0 : total / items.length,
        okCount: counts.ok,
        mencionCount: counts.mencion,
        criticalCount: counts.critico,
        segundaCalidadCount: counts.segundaCalidad,
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
      final totalMts = items.fold<double>(0, (s, r) => s + r.mtsCalculados);
      final counts = _countByLevel(items);
      return GroupNepsSummary(
        key: entry.key,
        totalNeps: total,
        totalMts: totalMts,
        recordCount: items.length,
        averageNeps: items.isEmpty ? 0 : total / items.length,
        okCount: counts.ok,
        mencionCount: counts.mencion,
        criticalCount: counts.critico,
        segundaCalidadCount: counts.segundaCalidad,
      );
    }).toList();

    summaries.sort((a, b) => b.totalNeps.compareTo(a.totalNeps));
    return summaries;
  }

  ({int ok, int mencion, int critico, int segundaCalidad}) _countByLevel(
    List<NepRecord> items,
  ) {
    var ok = 0;
    var mencion = 0;
    var critico = 0;
    var segundaCalidad = 0;
    for (final r in items) {
      switch (getAlertLevel(r.neps)) {
        case AlertLevel.ok:
          ok++;
        case AlertLevel.mencion:
          mencion++;
        case AlertLevel.critico:
          critico++;
        case AlertLevel.segundaCalidad:
          segundaCalidad++;
      }
    }
    return (
      ok: ok,
      mencion: mencion,
      critico: critico,
      segundaCalidad: segundaCalidad,
    );
  }
}

/// Instancia compartida para uso en UI y exportaciones.
final AlertService alertService = AlertService();
