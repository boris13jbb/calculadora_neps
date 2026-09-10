import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';

import 'package:calculadora_neps/core/errors/app_exception.dart';
import 'package:calculadora_neps/models/app_user.dart';
import 'package:calculadora_neps/models/app_user_role.dart';
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

    test('lanza ImportException con bytes Excel inválidos', () {
      expect(
        () => RecordImportService().importFromBytes(
          Uint8List.fromList([0, 1, 2, 3]),
          fileName: 'corrupto.xlsx',
        ),
        throwsA(isA<ImportException>()),
      );
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

  group('AppState.applyCorrectiveAction y aislamiento por UID', () {
    Future<AppState> createBoundState({
      required String uid,
      required AppUserRole role,
      String username = 'user',
    }) async {
      final appState = AppState();
      appState.applyAuthProfile(
        AppUser(uid: uid, username: username, role: role),
      );
      await appState.initialize();
      await appState.ensureCaptureSessionReady();
      appState.recordsScope.clear();
      return appState;
    }

    test('con usuario autenticado agrega historial y marca revisado', () async {
      SharedPreferences.setMockInitialValues({});
      final appState = await createBoundState(
        uid: 'supervisor-uid',
        role: AppUserRole.supervisor,
        username: 'supervisor',
      );
      appState.records = [
        NepRecord(
          id: 'r1',
          telar: '10',
          neps: 75,
          tela: 'DENIM',
          loteTrama: '63E264H15F',
          createdByUid: 'supervisor-uid',
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
      appState.dispose();
    });

    test('sin usuario no escribe ni atribuye acción a otro UID', () async {
      SharedPreferences.setMockInitialValues({});
      final appState = AppState();
      appState.records = [
        NepRecord(
          id: 'r-orphan',
          telar: '10',
          neps: 75,
          tela: 'DENIM',
          loteTrama: '63E264H15F',
          createdByUid: 'otro-uid',
        ),
      ];

      await appState.applyCorrectiveAction(
        recordId: 'r-orphan',
        accion: 'No debe persistirse',
        responsable: 'Nadie',
        marcarRevisado: true,
      );

      final record = appState.records.single;
      expect(record.historialAcciones, isEmpty);
      expect(record.revisadoPorSupervisor, isFalse);
      expect(record.accionCorrectiva, isEmpty);
      appState.dispose();
    });

    test('usuario B no lee la acción correctiva local de A', () async {
      SharedPreferences.setMockInitialValues({});
      final a = await createBoundState(
        uid: 'uid-a',
        role: AppUserRole.supervisor,
        username: 'supA',
      );
      a.records = [
        NepRecord(
          id: 'rec-a',
          telar: '11',
          neps: 80,
          tela: 'DENIM',
          loteTrama: '63E264H15F',
          createdByUid: 'uid-a',
        ),
      ];
      await a.applyCorrectiveAction(
        recordId: 'rec-a',
        accion: 'Acción de A',
        responsable: 'Supervisor A',
        marcarRevisado: true,
      );
      expect(a.records.single.historialAcciones, hasLength(1));

      final b = await createBoundState(
        uid: 'uid-b',
        role: AppUserRole.supervisor,
        username: 'supB',
      );
      expect(b.records, isEmpty);
      expect(
        b.records.any((r) => r.historialAcciones.isNotEmpty),
        isFalse,
      );

      a.dispose();
      b.dispose();
    });

    test('cambio de usuario reenlaza storage sin mezclar acciones', () async {
      SharedPreferences.setMockInitialValues({});
      final state = await createBoundState(
        uid: 'uid-first',
        role: AppUserRole.supervisor,
        username: 'first',
      );
      state.records = [
        NepRecord(
          id: 'rec-first',
          telar: '20',
          neps: 70,
          tela: 'DENIM',
          loteTrama: '63E264H15F',
          createdByUid: 'uid-first',
        ),
      ];
      await state.applyCorrectiveAction(
        recordId: 'rec-first',
        accion: 'Acción primer usuario',
        responsable: 'Primero',
        marcarRevisado: true,
      );

      state.applyAuthProfile(
        AppUser(
          uid: 'uid-second',
          username: 'second',
          role: AppUserRole.supervisor,
        ),
      );
      await state.ensureCaptureSessionReady();
      expect(state.authUid, 'uid-second');
      // Tras rebind, la UI/local del segundo usuario no hereda el historial de A.
      expect(
        state.records.any(
          (r) => r.historialAcciones
              .any((e) => e.accion == 'Acción primer usuario'),
        ),
        isFalse,
      );
      state.dispose();
    });
  });
}
