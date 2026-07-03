import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:calculadora_neps/models/corrective_action_entry.dart';
import 'package:calculadora_neps/models/nep_record.dart';
import 'package:calculadora_neps/providers/app_state.dart';
import 'package:calculadora_neps/services/import_template_service.dart';
import 'package:calculadora_neps/services/record_import_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RecordImportService preview', () {
    test('detecta filas válidas, duplicadas y errores', () {
      const csv = '''
NRO,FECHA,LOTE DE TRAMA,NOMBRE DE TELA,TELAR,NEPS,MTS CALCULADOS
1,05/06/2026 07:09,63E264H15F,DENIM CLARO,004,49,544
2,05/06/2026 07:09,63E264H15F,DENIM CLARO,004,49,544
3,05/06/2026 07:09,,DENIM CLARO,005,49,544
''';

      final result = RecordImportService().importFromCsv(csv);

      expect(result.validCount, 1);
      expect(result.duplicateRows, 1);
      expect(result.errorRows, 1);
      expect(result.importableRecords, hasLength(1));
      expect(result.importableRecords.single.telar, '004');
    });

    test('marca duplicados contra registros existentes', () {
      const csv = '''
NRO,FECHA,LOTE DE TRAMA,NOMBRE DE TELA,TELAR,NEPS,MTS CALCULADOS
1,05/06/2026 07:09,63E264H15F,DENIM CLARO,004,49,544
''';

      final existing = [
        NepRecord(
          telar: '004',
          neps: 49,
          tela: 'DENIM CLARO',
          loteTrama: '63E264H15F',
          createdAt: DateTime(2026, 6, 5, 7, 9),
        ),
      ];

      final result = RecordImportService().importFromCsv(
        csv,
        existingRecords: existing,
      );

      expect(result.validCount, 0);
      expect(result.duplicateRows, 1);
      expect(result.importableRecords, isEmpty);
    });

    test('importa nombre de tela separado del numero de telar', () {
      const csv = '''
NRO,FECHA,LOTE DE TRAMA,NOMBRE DE TELA,TELAR,NEPS,MTS CALCULADOS
1,05/06/2026 07:09,63E264H15F,DENIM CLARO,004,49,544
''';

      final result = RecordImportService().importFromCsv(csv);

      expect(result.records, hasLength(1));
      expect(result.records.single.tela, 'DENIM CLARO');
      expect(result.records.single.telar, '004');
    });
  });

  test('ImportTemplateService genera bytes Excel', () {
    final bytes = ImportTemplateService().buildExcelTemplate();
    expect(bytes, isNotEmpty);
    expect(bytes.length, greaterThan(100));
  });

  test('NepRecord persiste historial de acciones correctivas', () {
    final entry = CorrectiveActionEntry(
      fecha: DateTime(2026, 6, 29, 10),
      responsable: 'Supervisor',
      accion: 'Calibración revisada',
    );

    final record = NepRecord(
      telar: '12',
      neps: 80,
      tela: 'ALGODON',
      loteTrama: '63E264H10A',
      historialAcciones: [entry],
      revisadoPorSupervisor: true,
      responsableRevision: 'Supervisor',
      accionCorrectiva: 'Calibración revisada',
      fechaRevision: DateTime(2026, 6, 29, 10),
    );

    final restored = NepRecord.fromJson(record.toJson());
    expect(restored.historialAcciones, hasLength(1));
    expect(restored.historialAcciones.single.accion, 'Calibración revisada');
    expect(restored.responsableRevision, 'Supervisor');
    expect(restored.requiereSeguimiento, isFalse);
  });

  test('AppState.applyCorrectiveAction agrega historial y marca revisado', () async {
    SharedPreferences.setMockInitialValues({});
    final appState = AppState();
    appState.records = [
      NepRecord(
        id: 'r1',
        telar: '10',
        neps: 75,
        tela: 'DENIM',
        loteTrama: '63E264H15F',
      ),
    ];

    await appState.applyCorrectiveAction(
      recordId: 'r1',
      accion: 'Se limpió mecanismo.',
      responsable: 'Ana López',
      marcarRevisado: true,
    );

    final updated = appState.records.single;
    expect(updated.revisadoPorSupervisor, isTrue);
    expect(updated.accionCorrectiva, 'Se limpió mecanismo.');
    expect(updated.responsableRevision, 'Ana López');
    expect(updated.historialAcciones, hasLength(1));
    expect(updated.historialAcciones.single.responsable, 'Ana López');
  });
}
