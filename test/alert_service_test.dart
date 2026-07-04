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
  group('AlertService', () {
    final service = AlertService();

    test('clasifica normal hasta 30 neps', () {
      expect(service.getAlertLevel(0), AlertLevel.normal);
      expect(service.getAlertLevel(30), AlertLevel.normal);
    });

    test('clasifica advertencia entre 31 y 60 neps', () {
      expect(service.getAlertLevel(31), AlertLevel.advertencia);
      expect(service.getAlertLevel(60), AlertLevel.advertencia);
    });

    test('clasifica crítico mayor a 60 neps', () {
      expect(service.getAlertLevel(61), AlertLevel.critico);
      expect(service.getAlertLevel(150), AlertLevel.critico);
    });

    test('detecta registros críticos y advertencias', () {
      final records = [
        _record(telar: '1', neps: 10),
        _record(telar: '2', neps: 45),
        _record(telar: '3', neps: 80),
      ];

      expect(service.detectCriticalRecords(records).length, 1);
      expect(service.detectWarningRecords(records).length, 1);
    });

    test('detecta telar reincidente con múltiples críticos', () {
      final now = DateTime(2026, 6, 29, 10);
      final records = [
        _record(telar: '12', neps: 70, createdAt: now),
        _record(
            telar: '12',
            neps: 90,
            createdAt: now.add(const Duration(hours: 2))),
        _record(
            telar: '12',
            neps: 100,
            createdAt: now.add(const Duration(hours: 4))),
      ];

      expect(service.isTelarReincident('12', records), isTrue);
      final recs = service.generateRecommendations(records.first, records);
      expect(
        recs.any((r) => r.contains('reincidencia')),
        isTrue,
      );
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
    });

    test('respeta límites personalizados en AlertConfig', () {
      const custom = AlertConfig(limiteNormalMax: 10, limiteAdvertenciaMax: 20);
      final customService = AlertService(config: custom);

      expect(customService.getAlertLevel(10), AlertLevel.normal);
      expect(customService.getAlertLevel(11), AlertLevel.advertencia);
      expect(customService.getAlertLevel(21), AlertLevel.critico);
    });
  });
}
