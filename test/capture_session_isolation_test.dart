import 'package:calculadora_neps/models/app_user.dart';
import 'package:calculadora_neps/models/app_user_role.dart';
import 'package:calculadora_neps/models/nep_record.dart';
import 'package:calculadora_neps/providers/app_state.dart';
import 'package:calculadora_neps/services/capture_draft_storage_service.dart';
import 'package:calculadora_neps/services/personal_session_archive_service.dart';
import 'package:calculadora_neps/utils/stable_id.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<AppState> createState({
    required String uid,
    AppUserRole role = AppUserRole.operario,
    String username = 'user',
  }) async {
    final state = AppState();
    state.applyAuthProfile(
      AppUser(uid: uid, username: username, role: role),
    );
    await state.initialize();
    await state.ensureCaptureSessionReady();
    // Cada AppState comparte el storage local del proceso: aísla memoria.
    state.recordsScope.clear();
    state.clearCaptureFields(preserveCatalogDefaults: false);
    return state;
  }

  void fillValidMeasurement(AppState state, {String telar = '100'}) {
    state.useManualFabric = true;
    state.manualTelaController.text = 'BOLTON';
    state.loteFullController.text = '63E264H10A';
    state.telarController.text = telar;
    state.nepsController.text = '40';
  }

  group('Aislamiento multiusuario y sesión', () {
    test('A y B con mismo telar/lote mantienen registros distintos', () async {
      final a = await createState(uid: 'uid-a', username: 'operarioA');
      final b = await createState(uid: 'uid-b', username: 'operarioB');

      fillValidMeasurement(a, telar: '55');
      fillValidMeasurement(b, telar: '55');
      await a.addRecord();
      await b.addRecord();

      expect(a.records.single.telar, '55');
      expect(b.records.single.telar, '55');
      expect(a.records.single.id, isNot(b.records.single.id));
      expect(a.records.single.createdByUid, 'uid-a');
      expect(b.records.single.createdByUid, 'uid-b');
      expect(a.records.single.captureSessionId, isNotNull);
      expect(
        a.records.single.captureSessionId,
        isNot(b.records.single.captureSessionId),
      );

      a.dispose();
      b.dispose();
    });

    test('A inicia nueva sesión y B conserva lista y formulario', () async {
      final a = await createState(uid: 'uid-a', role: AppUserRole.admin);
      final b = await createState(uid: 'uid-b');

      fillValidMeasurement(a);
      await a.addRecord();
      fillValidMeasurement(b, telar: '77');
      await b.addRecord();
      b.telarController.text = '88';
      b.nepsController.text = '12';

      final bSessionBefore = b.activeCaptureSessionId;
      final bRecordId = b.records.single.id;

      await a.startNewCaptureSession();

      expect(a.captureSessionRecords, isEmpty);
      expect(b.records.single.id, bRecordId);
      expect(b.captureSessionRecords, hasLength(1));
      expect(b.activeCaptureSessionId, bSessionBefore);
      expect(b.telarController.text, '88');
      expect(b.nepsController.text, '12');

      a.dispose();
      b.dispose();
    });

    test('cambiar de cuenta limpia estado visible sin mezclar', () async {
      final state = await createState(uid: 'uid-a');
      fillValidMeasurement(state);
      await state.addRecord();
      expect(state.records, hasLength(1));

      state.applyAuthProfile(
        AppUser(uid: 'uid-b', username: 'otro', role: AppUserRole.operario),
      );
      await state.ensureCaptureSessionReady();

      expect(state.records, isEmpty);
      expect(state.captureSessionRecords, isEmpty);
      expect(state.telarController.text, isEmpty);
      expect(state.authUid, 'uid-b');
      state.dispose();
    });

    test('cancelar flujo: hasCaptureSessionWork detecta lista y borrador',
        () async {
      final state = await createState(uid: 'uid-a');
      expect(state.hasCaptureSessionWork, isFalse);

      state.telarController.text = '10';
      expect(state.hasCaptureFormDraft, isTrue);
      expect(state.hasCaptureSessionWork, isTrue);

      state.telarController.clear();
      fillValidMeasurement(state);
      await state.addRecord();
      // Tras agregar, tela/lote se conservan para captura continua.
      expect(state.hasCaptureFormDraft, isTrue);
      expect(state.captureSessionRecords, hasLength(1));
      expect(state.hasCaptureSessionWork, isTrue);
      state.dispose();
    });

    test('guardar abre sesión vacía y conserva historial', () async {
      final state = await createState(uid: 'uid-a', role: AppUserRole.admin);
      fillValidMeasurement(state);
      await state.addRecord();
      final oldSession = state.activeCaptureSessionId!;

      final saved = await state.persistActiveCaptureSession();
      expect(saved, isTrue);
      final opened = await state.openEmptyCaptureSessionAfterSave();
      expect(opened, isTrue);

      expect(state.records, hasLength(1));
      expect(state.records.single.captureSessionId, oldSession);
      expect(state.captureSessionRecords, isEmpty);
      expect(state.activeCaptureSessionId, isNot(oldSession));
      expect(state.manualTelaController.text, isEmpty);
      expect(state.loteFullController.text, isEmpty);
      expect(state.selectedFabric, isNull);
      state.dispose();
    });

    test(
      'descartar sin guardar vacía formulario y conserva registros locales',
      () async {
        final state = await createState(uid: 'uid-a', role: AppUserRole.admin);
        fillValidMeasurement(state);
        await state.addRecord();
        final savedRecordId = state.records.single.id;
        final oldSession = state.activeCaptureSessionId!;

        // Borrador pendiente (aún no es NepRecord).
        fillValidMeasurement(state, telar: '303');
        state.turnoController.text = 'A';
        state.observacionController.text = 'pendiente';
        expect(state.hasCaptureFormDraft, isTrue);
        expect(state.captureSessionRecords, hasLength(1));

        final discarded =
            await state.discardUnsavedDraftAndOpenEmptyCaptureSession();
        expect(discarded, isTrue);

        expect(state.activeCaptureSessionId, isNot(oldSession));
        expect(state.captureSessionRecords, isEmpty);
        expect(state.records, hasLength(1));
        expect(state.records.single.id, savedRecordId);
        expect(state.records.single.captureSessionId, oldSession);
        expect(state.telarController.text, isEmpty);
        expect(state.nepsController.text, isEmpty);
        expect(state.manualTelaController.text, isEmpty);
        expect(state.loteFullController.text, isEmpty);
        expect(state.lotePrefixController.text, isEmpty);
        expect(state.loteSuffixController.text, isEmpty);
        expect(state.turnoController.text, isEmpty);
        expect(state.observacionController.text, isEmpty);
        expect(state.selectedFabric, isNull);
        expect(state.hasCaptureFormDraft, isFalse);
        expect(state.hasCaptureSessionWork, isFalse);

        // El borrador en disco del UID no debe poder restaurarse.
        final draft = await captureDraftStorageService.loadForUid('uid-a');
        expect(draft, isNull);
        state.dispose();
      },
    );

    test(
      'descartar en A no afecta registros ni formulario de B',
      () async {
        final a = await createState(uid: 'uid-a', role: AppUserRole.admin);
        final b = await createState(uid: 'uid-b');

        fillValidMeasurement(a);
        await a.addRecord();
        a.telarController.text = '111';
        a.nepsController.text = '9';

        fillValidMeasurement(b, telar: '77');
        await b.addRecord();
        b.telarController.text = '88';
        b.nepsController.text = '12';
        final bSessionBefore = b.activeCaptureSessionId;
        final bRecordId = b.records.single.id;

        final discarded =
            await a.discardUnsavedDraftAndOpenEmptyCaptureSession();
        expect(discarded, isTrue);

        expect(a.captureSessionRecords, isEmpty);
        expect(a.telarController.text, isEmpty);
        expect(b.records.single.id, bRecordId);
        expect(b.captureSessionRecords, hasLength(1));
        expect(b.activeCaptureSessionId, bSessionBefore);
        expect(b.telarController.text, '88');
        expect(b.nepsController.text, '12');

        a.dispose();
        b.dispose();
      },
    );

    test('medición pendiente válida se guarda una sola vez al persistir sesión',
        () async {
      final state = await createState(uid: 'uid-a', role: AppUserRole.admin);
      fillValidMeasurement(state);
      await state.addRecord();
      expect(state.captureSessionRecords, hasLength(1));

      fillValidMeasurement(state, telar: '201');
      final pending = state.buildCaptureRecord();
      expect(pending, isNotNull);
      await state.submitCaptureRecord(pending!);
      expect(state.captureSessionRecords, hasLength(2));

      await state.persistActiveCaptureSession();
      await state.persistActiveCaptureSession(); // reintento idempotente
      expect(state.captureSessionRecords, hasLength(2));
      state.dispose();
    });

    test('medición incompleta no se pierde al fallar validación', () async {
      final state = await createState(uid: 'uid-a');
      state.useManualFabric = true;
      state.manualTelaController.text = 'BOLTON';
      state.loteFullController.text = '63E264H10A';
      state.telarController.text = '102';
      // neps vacío → incompleto
      final record = state.buildCaptureRecord();
      expect(record, isNull);
      expect(state.telarController.text, '102');
      expect(state.manualTelaController.text, 'BOLTON');
      expect(state.loteFullController.text, '63E264H10A');
      state.dispose();
    });

    test('reintento de nueva sesión no duplica informe pendiente', () async {
      final state = await createState(uid: 'uid-a', role: AppUserRole.admin);
      fillValidMeasurement(state);
      await state.addRecord();

      expect(await state.persistActiveCaptureSession(), isTrue);
      final firstId = state.authGeneration;
      expect(await state.persistActiveCaptureSession(), isTrue);
      expect(state.authGeneration, firstId);
      // Tras abrir vacía, el id pendiente se limpia.
      await state.openEmptyCaptureSessionAfterSave();
      expect(state.captureSessionRecords, isEmpty);
      state.dispose();
    });

    test('evento remoto de sesión cerrada no rellena captura activa', () async {
      final state = await createState(uid: 'uid-a', role: AppUserRole.admin);
      fillValidMeasurement(state);
      await state.addRecord();
      final closedSession = state.activeCaptureSessionId!;
      await state.persistActiveCaptureSession();
      await state.openEmptyCaptureSessionAfterSave();

      final lateRemote = NepRecord(
        id: generateStableId(prefix: 'rec'),
        telar: '999',
        neps: 11,
        tela: 'BOLTON',
        loteTrama: '63E264H10A',
        createdByUid: 'uid-a',
        captureSessionId: closedSession,
      );
      state.recordsScope.upsert(lateRemote);
      expect(state.captureSessionRecords, isEmpty);
      expect(state.records.any((r) => r.id == lateRemote.id), isTrue);
      state.dispose();
    });

    test('operario guarda sesión personal sin informe de equipo', () async {
      final state = await createState(uid: 'uid-op');
      fillValidMeasurement(state);
      await state.addRecord();

      expect(state.canManageReports, isFalse);
      final saved = await state.persistActiveCaptureSession();
      expect(saved, isTrue);

      final archives = await personalSessionArchiveService.loadForUid('uid-op');
      expect(archives, isNotEmpty);
      expect(archives.first.ownerUid, 'uid-op');
      expect(archives.first.records, hasLength(1));

      final opened = await state.openEmptyCaptureSessionAfterSave();
      expect(opened, isTrue);
      expect(state.captureSessionRecords, isEmpty);
      expect(state.manualTelaController.text, isEmpty);
      expect(state.loteFullController.text, isEmpty);
      state.dispose();
    });

    test('ids estables no usan telar ni lote', () async {
      final a = NepRecord(telar: '1', neps: 1, tela: 'T', loteTrama: 'L');
      final b = NepRecord(telar: '1', neps: 1, tela: 'T', loteTrama: 'L');
      expect(a.id, isNot(b.id));
      expect(a.id, isNot(a.telar));
      expect(a.id, isNot(a.loteTrama));
      expect(a.id.startsWith('rec_'), isTrue);
    });
  });
}
