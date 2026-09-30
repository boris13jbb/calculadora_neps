import 'package:flutter_test/flutter_test.dart';

import 'package:calculadora_neps/core/alert_config.dart';
import 'package:calculadora_neps/models/alert_level.dart';
import 'package:calculadora_neps/models/nep_record.dart';
import 'package:calculadora_neps/services/alert_service.dart';

NepRecord _record({
  required String telar,
  required double neps,
  String tela = 'ALGODON',
  String lote = '63E264H10A',
  DateTime? createdAt,
}) {
  return NepRecord(
    telar: telar,
    neps: neps,
    tela: tela,
    loteTrama: lote,
    createdAt: createdAt ?? DateTime.now(),
  );
}

void main() {
  group('AlertService criterios oficiales', () {
    final service = AlertService();

    test('clasifica OK hasta 18 neps (puntaje)', () {
      expect(service.getAlertLevel(0), AlertLevel.ok);
      expect(service.getAlertLevel(18), AlertLevel.ok);
    });

    test('clasifica Mención entre 19 y 45 neps', () {
      expect(service.getAlertLevel(19), AlertLevel.mencion);
      expect(service.getAlertLevel(45), AlertLevel.mencion);
    });

    test('clasifica Crítico entre 46 y 54 neps', () {
      expect(service.getAlertLevel(46), AlertLevel.critico);
      expect(service.getAlertLevel(54), AlertLevel.critico);
    });

    test('clasifica 2da Calidad desde 55 neps', () {
      expect(service.getAlertLevel(55), AlertLevel.segundaCalidad);
      expect(service.getAlertLevel(150), AlertLevel.segundaCalidad);
    });

    test('detecta registros por calificación', () {
      final records = [
        _record(telar: '1', neps: 10),
        _record(telar: '2', neps: 30),
        _record(telar: '3', neps: 50),
        _record(telar: '4', neps: 80),
      ];

      expect(service.detectMencionRecords(records).length, 1);
      expect(service.detectCriticalRecords(records).length, 1);
      expect(service.detectSecondQualityRecords(records).length, 1);
      expect(service.detectSevereRecords(records).length, 2);
    });

    test('detecta telar reincidente con múltiples severos', () {
      final now = DateTime(2026, 6, 29, 10);
      final records = [
        _record(telar: '12', neps: 50, createdAt: now),
        _record(
          telar: '12',
          neps: 60,
          createdAt: now.add(const Duration(hours: 2)),
        ),
        _record(
          telar: '12',
          neps: 70,
          createdAt: now.add(const Duration(hours: 4)),
        ),
      ];

      expect(service.isTelarReincident('12', records), isTrue);
      final recs = service.generateRecommendations(records.first, records);
      expect(recs.any((r) => r.contains('reincidencia')), isTrue);
      expect(recs.any((r) => r.contains('Realizar Ajuste')), isTrue);
    });

    test('top telares por total de neps', () {
      final records = [
        _record(telar: '1', neps: 10),
        _record(telar: '2', neps: 100),
        _record(telar: '2', neps: 50),
      ];

      final top = service.detectTopTelarsByTotalNeps(records, limit: 1);
      expect(top.first.telar, '2');
      expect(top.first.totalNeps, 150);
      expect(top.first.segundaCalidadCount, 1);
      expect(top.first.criticalCount, 1);
    });

    test('alertas inactivas fuerzan OK', () {
      final inactive = AlertService(
        config: const AlertConfig(alertasActivas: false),
      );
      expect(inactive.getAlertLevel(99), AlertLevel.ok);
    });
  });
}
