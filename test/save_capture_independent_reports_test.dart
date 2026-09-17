import 'package:calculadora_neps/core/theme/app_theme.dart';
import 'package:calculadora_neps/core/widgets/report_actions.dart';
import 'package:calculadora_neps/models/app_user.dart';
import 'package:calculadora_neps/models/app_user_role.dart';
import 'package:calculadora_neps/models/nep_record.dart';
import 'package:calculadora_neps/models/pdf_report_style.dart';
import 'package:calculadora_neps/models/record_filters.dart';
import 'package:calculadora_neps/models/saved_report.dart';
import 'package:calculadora_neps/providers/app_state.dart';
import 'package:calculadora_neps/services/report_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

NepRecord _rec({
  required String id,
  required String uid,
  required String sessionId,
  required DateTime createdAt,
  String telar = '1',
  double neps = 10,
}) {
  return NepRecord(
    id: id,
    telar: telar,
    tela: 'BOLTON',
    loteTrama: 'L-$id',
    neps: neps,
    createdAt: createdAt,
    createdByUid: uid,
    captureSessionId: sessionId,
  );
}

class _ThrowingReportStorage extends ReportStorageService {
  _ThrowingReportStorage() : super();

  @override
  Future<SavedReport> saveReport({
    required String name,
    required List<NepRecord> records,
    RecordFilters? appliedFilters,
    bool saveFiles = true,
    PdfReportStyle exportStyle = PdfReportStyle.completo,
    String? createdByUid,
  }) async {
    throw StateError('simulated save failure');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<AppState> readyState({
    String uid = 'uid-a',
    AppUserRole role = AppUserRole.admin,
    ReportStorageService? reportStorageService,
  }) async {
    final state = AppState(reportStorageService: reportStorageService);
    state.applyAuthProfile(
      AppUser(uid: uid, username: 'user-$uid', role: role),
    );
    await state.initialize();
    await state.ensureCaptureSessionReady();
    return state;
  }

  Future<NepRecord> addSessionRecord(
    AppState state, {
    required String telar,
    required double neps,
  }) async {
    state.useManualFabric = true;
    state.manualTelaController.text = 'BOLTON';
    state.loteFullController.text = '63E264H10A';
    state.telarController.text = telar;
    state.nepsController.text = neps.toStringAsFixed(0);
    final before = state.captureSessionRecords.map((r) => r.id).toSet();
    await state.addRecord();
    final added = state.captureSessionRecords
        .where((r) => !before.contains(r.id))
        .toList();
    expect(added, isNotEmpty, reason: 'addRecord debe crear un registro nuevo');
    added.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return added.last;
  }

  group('Guardados independientes Captura → Guardar', () {
    test('A) guardar R1 → informe contiene solo R1', () async {
      final state = await readyState();
      final r1 = await addSessionRecord(state, telar: '1', neps: 11);

      final ok = await state.saveCaptureReport(
        'Informe A',
        sourceRecords: [r1],
      );
      expect(ok, isTrue);

      final reports = await state.refreshReports();
      final saved = reports.firstWhere((r) => r.name == 'Informe A');
      expect(saved.records.map((r) => r.id), [r1.id]);
      expect(state.savedCaptureRecordIds, contains(r1.id));
      state.dispose();
    });

    test('B) guardar R1 luego R2 → segundo informe solo R2', () async {
      final state = await readyState();
      final r1 = await addSessionRecord(state, telar: '1', neps: 11);
      await state.saveCaptureReport('I1', sourceRecords: [r1]);

      final r2 = await addSessionRecord(state, telar: '2', neps: 22);
      expect(state.pendingCaptureSessionRecords.map((r) => r.id), [r2.id]);

      await state.saveCaptureReport('I2', sourceRecords: [r2]);
      final reports = await state.refreshReports();
      final i2 = reports.firstWhere((r) => r.name == 'I2');
      expect(i2.records.map((r) => r.id), [r2.id]);
      expect(i2.records,
          isNot(contains(predicate((NepRecord r) => r.id == r1.id))));
      state.dispose();
    });

    test('C) 10 registros guardados uno a uno → 10 informes independientes',
        () async {
      final state = await readyState();
      final ids = <String>[];
      for (var i = 1; i <= 10; i++) {
        final r =
            await addSessionRecord(state, telar: '$i', neps: i.toDouble());
        ids.add(r.id);
        await state.saveCaptureReport('Inf $i', sourceRecords: [r]);
      }

      final reports = await state.refreshReports();
      final named = reports.where((r) => r.name.startsWith('Inf ')).toList();
      expect(named, hasLength(10));
      for (var i = 0; i < 10; i++) {
        final report = named.firstWhere((r) => r.name == 'Inf ${i + 1}');
        expect(report.records, hasLength(1));
        expect(report.records.single.id, ids[i]);
      }
      expect(state.pendingCaptureSessionRecords, isEmpty);
      state.dispose();
    });

    testWidgets('D) R1 guardado; diálogo no preselecciona R1', (tester) async {
      final base = DateTime(2026, 9, 16, 10);
      final eligible = [
        _rec(
          id: 'r2',
          uid: 'uid-a',
          sessionId: 'ses',
          createdAt: base.add(const Duration(minutes: 1)),
          telar: '2',
        ),
        _rec(
          id: 'r3',
          uid: 'uid-a',
          sessionId: 'ses',
          createdAt: base.add(const Duration(minutes: 2)),
          telar: '3',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(),
          home: Scaffold(
            body: SaveCaptureSessionReportDialog(
              eligibleRecords: eligible,
              initialName: 'Informe prueba',
              style: PdfReportStyle.completo,
              formatDateTime: (d) => '${d.hour}:${d.minute}',
              formatNeps: (n) => n.toStringAsFixed(0),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dialog = tester.state<SaveCaptureSessionReportDialogState>(
        find.byType(SaveCaptureSessionReportDialog),
      );
      expect(dialog.selectedCount, 1);
      expect(dialog.selectedRecords.single.id, 'r3');
      expect(dialog.selectedRecords.map((r) => r.id), isNot(contains('r1')));
      expect(find.text('Guardar 1 registro'), findsOneWidget);
      expect(
        find.text('Seleccione los registros de esta sesión que desea guardar.'),
        findsOneWidget,
      );
    });

    test('E) multiselect explícito R2+R3 → informe exacto', () async {
      final state = await readyState();
      final r1 = await addSessionRecord(state, telar: '1', neps: 1);
      await state.saveCaptureReport('solo R1', sourceRecords: [r1]);
      final r2 = await addSessionRecord(state, telar: '2', neps: 2);
      final r3 = await addSessionRecord(state, telar: '3', neps: 3);

      await state.saveCaptureReport(
        'R2R3',
        sourceRecords: [r2, r3],
      );
      final report =
          (await state.refreshReports()).firstWhere((r) => r.name == 'R2R3');
      expect(report.records.map((r) => r.id).toSet(), {r2.id, r3.id});
      state.dispose();
    });

    test('F) tras guardar R2/R3 ya no quedan pendientes', () async {
      final state = await readyState();
      final r1 = await addSessionRecord(state, telar: '1', neps: 1);
      await state.saveCaptureReport('R1', sourceRecords: [r1]);
      final r2 = await addSessionRecord(state, telar: '2', neps: 2);
      final r3 = await addSessionRecord(state, telar: '3', neps: 3);
      await state.saveCaptureReport('R2R3', sourceRecords: [r2, r3]);

      expect(state.pendingCaptureSessionRecords, isEmpty);
      expect(
        state.savedCaptureRecordIds,
        containsAll([r1.id, r2.id, r3.id]),
      );
      state.dispose();
    });

    test('G) Nueva sesión no mezcla pendientes de la anterior', () async {
      final state = await readyState();
      final r1 = await addSessionRecord(state, telar: '1', neps: 1);
      await state.saveCaptureReport('A', sourceRecords: [r1]);
      final r2 = await addSessionRecord(state, telar: '2', neps: 2);
      expect(state.pendingCaptureSessionRecords.map((r) => r.id), [r2.id]);

      final rotated = await state.openEmptyCaptureSessionAfterSave();
      expect(rotated, isTrue);
      expect(state.savedCaptureRecordIds, isEmpty);
      expect(state.pendingCaptureSessionRecords, isEmpty);

      final r3 = await addSessionRecord(state, telar: '3', neps: 3);
      expect(state.pendingCaptureSessionRecords.map((r) => r.id), [r3.id]);
      expect(
        state.pendingCaptureSessionRecords.map((r) => r.id),
        isNot(contains(r2.id)),
      );
      state.dispose();
    });

    test('H) Usuario A / Usuario B aislamiento por UID', () async {
      final a = await readyState(uid: 'uid-a');
      final b = await readyState(uid: 'uid-b');
      final sessionA = a.activeCaptureSessionId!;
      final sessionB = b.activeCaptureSessionId!;

      a.records = [
        _rec(
          id: 'a1',
          uid: 'uid-a',
          sessionId: sessionA,
          createdAt: DateTime(2026, 9, 16, 10),
        ),
        _rec(
          id: 'a2',
          uid: 'uid-a',
          sessionId: sessionA,
          createdAt: DateTime(2026, 9, 16, 11),
        ),
        _rec(
          id: 'b-leak',
          uid: 'uid-b',
          sessionId: sessionA,
          createdAt: DateTime(2026, 9, 16, 12),
        ),
      ];
      b.records = [
        _rec(
          id: 'b1',
          uid: 'uid-b',
          sessionId: sessionB,
          createdAt: DateTime(2026, 9, 16, 10),
        ),
        _rec(
          id: 'a-leak',
          uid: 'uid-a',
          sessionId: sessionB,
          createdAt: DateTime(2026, 9, 16, 11),
        ),
      ];

      expect(a.pendingCaptureSessionRecords.map((r) => r.id).toSet(),
          {'a1', 'a2'});
      expect(b.pendingCaptureSessionRecords.map((r) => r.id).toSet(), {'b1'});
      a.dispose();
      b.dispose();
    });

    test('I) si guardar falla, IDs NO quedan marcados', () async {
      final state = await readyState(
        reportStorageService: _ThrowingReportStorage(),
      );
      final r1 = await addSessionRecord(state, telar: '1', neps: 11);

      final ok = await state.saveCaptureReport(
        'fail',
        sourceRecords: [r1],
      );
      expect(ok, isFalse);
      expect(state.savedCaptureRecordIds, isEmpty);
      expect(state.pendingCaptureSessionRecords.map((r) => r.id), [r1.id]);
      state.dispose();
    });

    test('K) Export general sin sourceRecords usa visibleRecords', () async {
      final state = await readyState();
      state.records = [
        _rec(
          id: 'v1',
          uid: 'uid-a',
          sessionId: 'other',
          createdAt: DateTime(2026, 9, 1),
        ),
        _rec(
          id: 'v2',
          uid: 'uid-a',
          sessionId: state.activeCaptureSessionId!,
          createdAt: DateTime(2026, 9, 2),
        ),
      ];
      expect(
        state.resolveExportRecords(null).map((r) => r.id).toSet(),
        state.visibleRecords.map((r) => r.id).toSet(),
      );
      final only = state.records.first;
      expect(state.resolveExportRecords([only]).map((r) => r.id), [only.id]);
      state.dispose();
    });
  });

  group('Diálogo Guardar — selección pendiente', () {
    testWidgets('Seleccionar pendientes marca todos los elegibles',
        (tester) async {
      final base = DateTime(2026, 9, 16, 10);
      final eligible = [
        _rec(
          id: 'p1',
          uid: 'u',
          sessionId: 's',
          createdAt: base,
          telar: '1',
        ),
        _rec(
          id: 'p2',
          uid: 'u',
          sessionId: 's',
          createdAt: base.add(const Duration(minutes: 1)),
          telar: '2',
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(),
          home: Scaffold(
            body: SaveCaptureSessionReportDialog(
              eligibleRecords: eligible,
              initialName: 'X',
              style: PdfReportStyle.completo,
              formatDateTime: (d) => '${d.hour}:${d.minute}',
              formatNeps: (n) => n.toStringAsFixed(0),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dialog = tester.state<SaveCaptureSessionReportDialogState>(
        find.byType(SaveCaptureSessionReportDialog),
      );
      expect(dialog.selectedRecords.single.id, 'p2');

      await tester.tap(find.text('Seleccionar pendientes'));
      await tester.pump();
      expect(dialog.selectedCount, 2);
      expect(find.text('Guardar 2 registros'), findsOneWidget);

      await tester.tap(find.text('Limpiar selección'));
      await tester.pump();
      expect(dialog.selectedCount, 0);
      expect(find.text('Seleccione al menos un registro.'), findsWidgets);
    });
  });
}
