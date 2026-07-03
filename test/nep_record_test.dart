import 'package:flutter_test/flutter_test.dart';

import 'package:calculadora_neps/models/nep_record.dart';

void main() {
  test('fromJson compatible con registros antiguos sin campos nuevos', () {
    final record = NepRecord.fromJson({
      'id': '1',
      'telar': '12',
      'neps': 45,
      'tela': 'ALGODON',
      'loteTrama': '63E264H10A',
      'createdAt': '2026-06-29T10:00:00.000',
    });

    expect(record.turno, '');
    expect(record.operario, '');
    expect(record.lineaProduccion, '');
    expect(record.observacion, '');
    expect(record.revisadoPorSupervisor, isFalse);
    expect(record.accionCorrectiva, '');
    expect(record.responsableRevision, '');
    expect(record.historialAcciones, isEmpty);
    expect(record.fechaRevision, isNull);
    expect(record.estadoAlerta, 'Advertencia');
  });

  test('toJson omite campos vacíos opcionales', () {
    final record = NepRecord(telar: '1', neps: 10, tela: 'T', loteTrama: 'L');
    final json = record.toJson();

    expect(json.containsKey('turno'), isFalse);
    expect(json.containsKey('operario'), isFalse);
    expect(json['telar'], '1');
  });

  test('copyWith preserva campos de seguimiento', () {
    final original = NepRecord(
      telar: '1',
      neps: 80,
      tela: 'T',
      loteTrama: 'L',
      revisadoPorSupervisor: true,
      accionCorrectiva: 'Calibración revisada',
      fechaRevision: DateTime(2026, 6, 29),
    );

    final updated = original.copyWith(neps: 85);
    expect(updated.revisadoPorSupervisor, isTrue);
    expect(updated.accionCorrectiva, 'Calibración revisada');
    expect(updated.neps, 85);
  });
}
