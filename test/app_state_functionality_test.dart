import 'package:calculadora_neps/models/app_user.dart';
import 'package:calculadora_neps/models/app_user_role.dart';
import 'package:calculadora_neps/models/nep_record.dart';
import 'package:calculadora_neps/providers/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<AppState> createReadyState(
      {AppUserRole role = AppUserRole.operario}) async {
    final state = AppState();
    state.applyAuthProfile(
      AppUser(
        uid: 'test-uid',
        username: 'tester',
        role: role,
      ),
    );
    await state.initialize();
    await state.ensureCaptureSessionReady();
    return state;
  }

  group('Calculo Mts', () {
    test('Mts = Neps / 0.09', () async {
      final state = await createReadyState();
      expect(state.calculateMts(51), closeTo(566.667, 0.001));
      expect(state.calculateMts(0.09), closeTo(1, 0.001));
      state.dispose();
    });

    test('previewValue refleja neps ingresados', () async {
      final state = await createReadyState();
      state.nepsController.text = '51';
      expect(state.previewValue, closeTo(566.667, 0.001));
      state.dispose();
    });
  });

  group('Captura de registros', () {
    test('agregar registro con tela manual y lote', () async {
      final state = await createReadyState();
      state.useManualFabric = true;
      state.manualTelaController.text = 'BOLTON';
      state.loteFullController.text = '63E264H10A';
      state.telarController.text = '102';
      state.nepsController.text = '53';

      await state.addRecord();

      expect(state.records, hasLength(1));
      expect(state.records.first.telar, '102');
      expect(state.records.first.neps, 53);
      expect(state.records.first.tela, 'BOLTON');
      expect(state.records.first.loteTrama, '63E264H10A');
      expect(state.telarController.text, isEmpty);
      expect(state.nepsController.text, isEmpty);
      expect(state.manualTelaController.text, 'BOLTON');
      expect(state.loteFullController.text, '63E264H10A');
      state.dispose();
    });

    test('tras agregar conserva tela y lote pero limpia campos del registro',
        () async {
      final state = await createReadyState();
      state.useManualFabric = true;
      state.manualTelaController.text = 'BOLTON';
      state.loteFullController.text = '63E264H10A';
      state.telarController.text = '102';
      state.nepsController.text = '53';
      state.turnoController.text = 'A';

      await state.addRecord();

      expect(state.telarController.text, isEmpty);
      expect(state.nepsController.text, isEmpty);
      expect(state.turnoController.text, isEmpty);
      expect(state.manualTelaController.text, 'BOLTON');
      expect(state.loteFullController.text, '63E264H10A');
      state.dispose();
    });

    test('limpiar campos de captura', () async {
      final state = await createReadyState();
      state.telarController.text = '102';
      state.nepsController.text = '53';
      state.clearCaptureFields();
      expect(state.telarController.text, isEmpty);
      expect(state.nepsController.text, isEmpty);
      state.dispose();
    });

    test('nueva sesion conserva historial y vacia captura activa', () async {
      final state = await createReadyState(role: AppUserRole.admin);
      state.useManualFabric = true;
      state.manualTelaController.text = 'BOLTON';
      state.loteFullController.text = '63E264H10A';
      state.telarController.text = '102';
      state.nepsController.text = '53';
      await state.addRecord();
      expect(state.records, hasLength(1));
      expect(state.captureSessionRecords, hasLength(1));
      final previousSession = state.activeCaptureSessionId;

      await state.startNewCaptureSession();
      expect(state.records, hasLength(1),
          reason: 'no debe borrar historial al abrir sesión nueva');
      expect(state.captureSessionRecords, isEmpty);
      expect(state.activeCaptureSessionId, isNot(previousSession));
      expect(state.telarController.text, isEmpty);
      expect(state.nepsController.text, isEmpty);
      expect(state.manualTelaController.text, isEmpty);
      expect(state.loteFullController.text, isEmpty);
      state.dispose();
    });
  });

  group('Registros y filtros', () {
    test('vaciar tabla elimina todos los registros', () async {
      final state = await createReadyState(role: AppUserRole.admin);
      state.records = [
        NepRecord(
          telar: '1',
          neps: 10,
          tela: 'BOLTON',
          loteTrama: '63E264H10A',
        ),
      ];
      await state.clearTable();
      expect(state.records, isEmpty);
      state.dispose();
    });

    test('filtros reducen registros visibles', () async {
      final state = await createReadyState();
      state.records = [
        NepRecord(
          telar: '1',
          neps: 10,
          tela: 'BOLTON',
          loteTrama: '63E264H10A',
        ),
        NepRecord(
          telar: '2',
          neps: 20,
          tela: 'BROKER',
          loteTrama: '63E264H7A',
        ),
      ];
      state.filters.tela = 'BOLTON';
      expect(state.visibleRecords, hasLength(1));
      expect(state.visibleRecords.first.tela, 'BOLTON');
      state.dispose();
    });
  });

  group('Navegacion', () {
    test('setNavigationIndex cambia indice', () async {
      final state = await createReadyState();
      expect(state.navigationIndex, 0);
      state.setNavigationIndex(2);
      expect(state.navigationIndex, 2);
      state.setNavigationIndex(5);
      expect(state.navigationIndex, 5);
      state.dispose();
    });
  });

  group('Catalogo de telas', () {
    test('guardar y cargar telas', () async {
      final state = await createReadyState(role: AppUserRole.admin);
      await state.saveFabrics(['BOLTON', 'BROKER']);
      expect(state.fabrics, containsAll(['BOLTON', 'BROKER']));

      final reloaded = AppState();
      await reloaded.initialize();
      expect(reloaded.fabrics, containsAll(['BOLTON', 'BROKER']));
      state.dispose();
      reloaded.dispose();
    });
    test('persiste lote completo en preferencias por UID', () async {
      final state = await createReadyState();
      state.loteFullController.text = '63E264H7A';
      await Future<void>.delayed(const Duration(milliseconds: 80));

      final reloaded = AppState();
      reloaded.applyAuthProfile(
        AppUser(
          uid: 'test-uid',
          username: 'tester',
          role: AppUserRole.operario,
        ),
      );
      await reloaded.initialize();
      expect(reloaded.loteFullController.text, '63E264H7A');
      state.dispose();
      reloaded.dispose();
    });

    test('lote de otro UID no se restaura en cuenta distinta', () async {
      final stateA = await createReadyState();
      stateA.loteFullController.text = '63E264H7A';
      await Future<void>.delayed(const Duration(milliseconds: 80));

      final stateB = AppState();
      stateB.applyAuthProfile(
        AppUser(
          uid: 'other-uid',
          username: 'other',
          role: AppUserRole.operario,
        ),
      );
      await stateB.initialize();
      expect(stateB.loteFullController.text, isNot('63E264H7A'));
      stateA.dispose();
      stateB.dispose();
    });
  });

  group('Guardar informe', () {
    test('con sourceRecords guarda solo la sesión pendiente, no el workspace',
        () async {
      final state = await createReadyState(role: AppUserRole.admin);
      state.records = [
        for (var i = 0; i < 5; i++)
          NepRecord(
            id: 'hist_$i',
            telar: '$i',
            neps: 10,
            tela: 'BOLTON',
            loteTrama: 'L$i',
            createdAt: DateTime(2026, 9, 1, i),
            captureSessionId: 'ses_old',
          ),
      ];
      state.useManualFabric = true;
      state.manualTelaController.text = 'BOLTON';
      state.loteFullController.text = '63E264H10A';
      state.telarController.text = '99';
      state.nepsController.text = '11';
      await state.addRecord();

      expect(state.records.length, greaterThan(1));
      expect(state.captureSessionRecords, hasLength(1));
      expect(state.pendingCaptureSessionRecords, hasLength(1));

      final ok = await state.saveCaptureReport(
        'Informe sesión QA',
        sourceRecords: state.pendingCaptureSessionRecords,
      );
      expect(ok, isTrue);

      final reports = await state.refreshReports();
      final saved = reports.firstWhere((r) => r.name == 'Informe sesión QA');
      expect(saved.records, hasLength(1));
      expect(saved.records.single.telar, '99');
      expect(state.pendingCaptureSessionRecords, isEmpty);
      state.dispose();
    });
  });
}
