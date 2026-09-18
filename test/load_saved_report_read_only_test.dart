import 'dart:async';

import 'package:calculadora_neps/core/permissions/role_catalog.dart';
import 'package:calculadora_neps/features/reports/reports_screen.dart';
import 'package:calculadora_neps/models/app_user.dart';
import 'package:calculadora_neps/models/app_user_role.dart';
import 'package:calculadora_neps/models/nep_record.dart';
import 'package:calculadora_neps/models/record_filters.dart';
import 'package:calculadora_neps/models/records_page_result.dart';
import 'package:calculadora_neps/models/record_tombstone.dart';
import 'package:calculadora_neps/models/saved_report.dart';
import 'package:calculadora_neps/providers/app_state.dart';
import 'package:calculadora_neps/services/cloud_sync_port.dart';
import 'package:calculadora_neps/services/saved_capture_ids_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TrackingCloudSync implements CloudSyncPort {
  int replaceCalls = 0;
  int clearCalls = 0;
  int upsertBatchCalls = 0;
  int upsertSingleCalls = 0;
  final _recordsController = StreamController<RecordsPageResult>.broadcast();

  @override
  Future<void> bootstrap() async {}

  @override
  Stream<List<NepRecord>> watchRecords({
    AppUserRole viewerRole = AppUserRole.operario,
    String? viewerRoleCode,
  }) =>
      watchRecentRecords(viewerRole: viewerRole, viewerRoleCode: viewerRoleCode)
          .map((page) => page.records);

  @override
  Stream<RecordsPageResult> watchRecentRecords({
    AppUserRole viewerRole = AppUserRole.operario,
    String? viewerRoleCode,
    int limit = 50,
  }) async* {
    yield const RecordsPageResult(records: []);
    yield* _recordsController.stream;
  }

  @override
  Stream<RecordsPageResult> watchRecordsByDateRange({
    required DateTime from,
    required DateTime to,
    AppUserRole viewerRole = AppUserRole.operario,
    String? viewerRoleCode,
    int limit = 50,
  }) async* {
    yield const RecordsPageResult(records: []);
    yield* _recordsController.stream;
  }

  @override
  Stream<RecordsPageResult> watchRecordsByFilters({
    required RecordFilters filters,
    AppUserRole viewerRole = AppUserRole.operario,
    String? viewerRoleCode,
    int limit = 50,
  }) async* {
    yield const RecordsPageResult(records: []);
    yield* _recordsController.stream;
  }

  @override
  Future<RecordsPageResult> fetchRecordsByFilters({
    required RecordFilters filters,
    AppUserRole viewerRole = AppUserRole.operario,
    String? viewerRoleCode,
    int limit = 50,
  }) async =>
      const RecordsPageResult(records: []);

  @override
  Stream<List<String>> watchFabrics() => Stream.value(const []);

  @override
  Future<void> migrateLocalDataIfNeeded({
    required List<NepRecord> localRecords,
    required List<String> localFabrics,
  }) async {}

  @override
  Future<void> syncFabricsWithLocal(List<String> localFabrics) async {}

  @override
  Future<List<String>> saveFabrics(List<String> fabrics) async => fabrics;

  @override
  Future<void> upsertRecord(NepRecord record) async {
    upsertSingleCalls++;
  }

  @override
  Future<void> upsertRecords(List<NepRecord> records) async {
    upsertBatchCalls++;
  }

  @override
  Future<void> deleteRecord(String recordId, {String? ownerUid}) async {}

  @override
  Stream<List<RecordTombstone>> watchRecordTombstones() =>
      Stream.value(const []);

  @override
  Future<bool> hasRecordTombstone(String recordId) async => false;

  @override
  Future<void> clearRecords() async {
    clearCalls++;
  }

  @override
  Future<void> replaceRecords(List<NepRecord> records) async {
    replaceCalls++;
    clearCalls++;
    if (records.isNotEmpty) upsertBatchCalls++;
  }

  @override
  Future<List<SavedReport>> fetchReports() async => [];

  @override
  Future<SavedReport> saveReport(SavedReport report) async => report;

  @override
  Future<void> deleteReport(String reportId) async {}

  @override
  Future<AppUserRole> fetchUserRole() async => AppUserRole.admin;

  @override
  Future<Map<String, dynamic>?> fetchAlertConfig() async => null;

  @override
  Future<void> saveAlertConfig(Map<String, dynamic> config) async {}

  @override
  Future<void> registerFcmToken(String token) async {}

  void dispose() => _recordsController.close();
}

NepRecord _live({required String id, required String uid}) {
  return NepRecord(
    id: id,
    telar: 'L-$id',
    neps: 10,
    tela: 'LIVE',
    loteTrama: 'LIVE-LOTE',
    createdAt: DateTime(2026, 9, 16, 10),
    createdByUid: uid,
    captureSessionId: 'ses-live',
  );
}

NepRecord _hist({required String id}) {
  return NepRecord(
    id: id,
    telar: 'H-$id',
    neps: 99,
    tela: 'HIST',
    loteTrama: 'HIST-LOTE',
    createdAt: DateTime(2026, 8, 1, 8),
    createdByUid: 'other',
    captureSessionId: 'ses-hist',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RoleCatalog.instance.resetAuthorization();
    RoleCatalog.instance.replaceAll(RoleCatalog.baseRoles);
    RoleCatalog.instance.markAuthorizationReady();
  });

  Future<AppState> readyState({CloudSyncPort? cloud}) async {
    final state = AppState(cloudSyncService: cloud);
    state.applyAuthProfile(
      AppUser(uid: 'admin-uid', username: 'admin', role: AppUserRole.admin),
    );
    await state.initialize();
    await state.ensureCaptureSessionReady();
    if (cloud != null) {
      state.cloudSyncEnabled = true;
    }
    return state;
  }

  group('H1 SavedReport read-only', () {
    test('H1-A abrir informe NO reemplaza AppState.records', () async {
      final state = await readyState();
      final live1 = _live(id: 'LIVE1', uid: 'admin-uid');
      final live2 = _live(id: 'LIVE2', uid: 'admin-uid');
      state.records = [live1, live2];
      await state.recordsScope.persistLocally();

      final report = SavedReport(
        id: 'rep1',
        name: 'Histórico',
        createdAt: DateTime(2026, 8, 2),
        records: [_hist(id: 'HIST1')],
        createdByUid: 'admin-uid',
      );

      final sessionBefore = state.activeCaptureSessionId;
      // Acción de visualización: no debe mutar el dataset operativo.
      await state.openSavedReportView(report);

      expect(state.records.map((r) => r.id).toSet(), {'LIVE1', 'LIVE2'});
      expect(state.records.any((r) => r.id == 'HIST1'), isFalse);
      expect(state.activeCaptureSessionId, sessionBefore);
      state.dispose();
    });

    test('H1-B abrir informe NO cambia activeCaptureSessionId', () async {
      final state = await readyState();
      state.records = [_live(id: 'LIVE1', uid: 'admin-uid')];
      final sessionBefore = state.activeCaptureSessionId;
      expect(sessionBefore, isNotNull);

      await state.openSavedReportView(
        SavedReport(
          id: 'rep1',
          name: 'Histórico',
          createdAt: DateTime(2026, 8, 2),
          records: [_hist(id: 'HIST1')],
          createdByUid: 'admin-uid',
        ),
      );

      expect(state.activeCaptureSessionId, sessionBefore);
      state.dispose();
    });

    test('H1-C abrir informe NO cambia savedCaptureRecordIds', () async {
      final state = await readyState();
      state.records = [_live(id: 'LIVE1', uid: 'admin-uid')];
      await savedCaptureIdsStorageService.save(
        uid: 'admin-uid',
        captureSessionId: state.activeCaptureSessionId!,
        ids: {'LIVE1'},
      );
      await state.ensureCaptureSessionReady();
      expect(state.savedCaptureRecordIds, contains('LIVE1'));
      final before = Set<String>.from(state.savedCaptureRecordIds);

      await state.openSavedReportView(
        SavedReport(
          id: 'rep1',
          name: 'Histórico',
          createdAt: DateTime(2026, 8, 2),
          records: [_hist(id: 'HIST1')],
          createdByUid: 'admin-uid',
        ),
      );

      expect(state.savedCaptureRecordIds, before);
      state.dispose();
    });

    test('H1-D abrir informe NO modifica persistencia operativa', () async {
      final state = await readyState();
      final live1 = _live(id: 'LIVE1', uid: 'admin-uid');
      final live2 = _live(id: 'LIVE2', uid: 'admin-uid');
      state.records = [live1, live2];
      await state.recordsScope.persistLocally();

      await state.openSavedReportView(
        SavedReport(
          id: 'rep1',
          name: 'Histórico',
          createdAt: DateTime(2026, 8, 2),
          records: [_hist(id: 'HIST1')],
          createdByUid: 'admin-uid',
        ),
      );

      final reloaded = await state.recordsScope.loadFromPreferences();
      expect(reloaded.map((r) => r.id).toSet(), {'LIVE1', 'LIVE2'});
      expect(reloaded.any((r) => r.id == 'HIST1'), isFalse);
      state.dispose();
    });

    test('H1-E abrir informe NO llama replace/clear/upsert cloud', () async {
      final cloud = _TrackingCloudSync();
      final state = await readyState(cloud: cloud);
      state.records = [
        _live(id: 'LIVE1', uid: 'admin-uid'),
        _live(id: 'LIVE2', uid: 'admin-uid'),
      ];
      await state.recordsScope.persistLocally();

      await state.openSavedReportView(
        SavedReport(
          id: 'rep1',
          name: 'Histórico',
          createdAt: DateTime(2026, 8, 2),
          records: [_hist(id: 'HIST1')],
          createdByUid: 'admin-uid',
        ),
      );

      expect(cloud.replaceCalls, 0);
      expect(cloud.clearCalls, 0);
      expect(cloud.upsertBatchCalls, 0);
      expect(cloud.upsertSingleCalls, 0);
      cloud.dispose();
      state.dispose();
    });

    test('H1-F report.records sigue disponible para visualización', () async {
      final state = await readyState();
      final hist = _hist(id: 'HIST1');
      final report = SavedReport(
        id: 'rep1',
        name: 'Histórico QA',
        createdAt: DateTime(2026, 8, 2, 12, 30),
        records: [hist],
        createdByUid: 'admin-uid',
      );

      final opened = await state.openSavedReportView(report);
      expect(opened, isTrue);
      expect(state.viewingSavedReport, isNotNull);
      expect(state.viewingSavedReport!.id, 'rep1');
      expect(state.viewingSavedReport!.name, 'Histórico QA');
      expect(state.viewingSavedReport!.records.map((r) => r.id), ['HIST1']);
      expect(state.viewingSavedReport!.records.first.telar, 'H-HIST1');
      // Dataset operativo intacto.
      expect(state.records, isEmpty);
      state.dispose();
    });
  });

  group('VIEW-AUTH aislamiento viewingSavedReport', () {
    test('VIEW-AUTH-1 cambio de UID limpia viewingSavedReport', () async {
      final cloud = _TrackingCloudSync();
      final state = await readyState(cloud: cloud);
      final liveA = _live(id: 'LIVE-A1', uid: 'user-a');
      state.records = [liveA];
      await state.recordsScope.persistLocally();

      final reportA = SavedReport(
        id: 'rep-a',
        name: 'Informe A',
        createdAt: DateTime(2026, 8, 2),
        records: [_hist(id: 'HIST-A')],
        createdByUid: 'user-a',
      );
      final opened = await state.openSavedReportView(reportA);
      expect(opened, isTrue);
      expect(state.viewingSavedReport, isNotNull);
      expect(state.viewingSavedReport!.id, 'rep-a');

      final replaceBefore = cloud.replaceCalls;
      final clearBefore = cloud.clearCalls;
      final upsertBatchBefore = cloud.upsertBatchCalls;
      final upsertSingleBefore = cloud.upsertSingleCalls;

      // Reinicia perfil como usuario B (cambio real de UID).
      state.applyAuthProfile(
        AppUser(uid: 'user-b', username: 'userb', role: AppUserRole.admin),
      );

      expect(state.viewingSavedReport, isNull);
      // Registros del usuario A no se transfieren al cambiar UID.
      expect(state.records.any((r) => r.id == 'LIVE-A1'), isFalse);
      // Limpiar la vista no dispara escritura cloud.
      expect(cloud.replaceCalls, replaceBefore);
      expect(cloud.clearCalls, clearBefore);
      expect(cloud.upsertBatchCalls, upsertBatchBefore);
      expect(cloud.upsertSingleCalls, upsertSingleBefore);

      cloud.dispose();
      state.dispose();
    });

    test('VIEW-AUTH-2 logout limpia viewingSavedReport', () async {
      final state = await readyState();
      final opened = await state.openSavedReportView(
        SavedReport(
          id: 'rep-logout',
          name: 'Informe logout',
          createdAt: DateTime(2026, 8, 2),
          records: [_hist(id: 'HIST-L')],
          createdByUid: 'admin-uid',
        ),
      );
      expect(opened, isTrue);
      expect(state.viewingSavedReport, isNotNull);

      state.resetCloudSession();

      expect(state.viewingSavedReport, isNull);
      state.dispose();
    });

    test(
      'SAVED_REPORT_USER_ISOLATION A→B nunca observa informe de A',
      () async {
        final state = await readyState();
        final reportA = SavedReport(
          id: 'rep-a',
          name: 'Informe A',
          createdAt: DateTime(2026, 8, 1),
          records: [_hist(id: 'HIST-A')],
          createdByUid: 'user-a',
        );
        final reportB = SavedReport(
          id: 'rep-b',
          name: 'Informe B',
          createdAt: DateTime(2026, 8, 2),
          records: [_hist(id: 'HIST-B')],
          createdByUid: 'user-b',
        );

        state.applyAuthProfile(
          AppUser(uid: 'user-a', username: 'usera', role: AppUserRole.admin),
        );
        await Future<void>.delayed(Duration.zero);
        final openedA = await state.openSavedReportView(reportA);
        expect(openedA, isTrue);
        expect(state.viewingSavedReport?.id, 'rep-a');

        state.applyAuthProfile(
          AppUser(uid: 'user-b', username: 'userb', role: AppUserRole.admin),
        );
        expect(state.viewingSavedReport, isNull);

        final openedB = await state.openSavedReportView(reportB);
        expect(openedB, isTrue);
        expect(state.viewingSavedReport?.id, 'rep-b');
        expect(state.viewingSavedReport?.id, isNot('rep-a'));

        state.dispose();
      },
    );
  });

  group('LEGACY loadReport read-only', () {
    test('LEGACY-1 loadReport NO reemplaza records vivos', () async {
      final state = await readyState();
      state.records = [
        _live(id: 'LIVE1', uid: 'admin-uid'),
        _live(id: 'LIVE2', uid: 'admin-uid'),
      ];
      await state.recordsScope.persistLocally();

      await state.loadReport(
        SavedReport(
          id: 'rep-legacy',
          name: 'Histórico legacy',
          createdAt: DateTime(2026, 8, 2),
          records: [_hist(id: 'HIST1')],
          createdByUid: 'admin-uid',
        ),
      );

      expect(state.records.map((r) => r.id).toSet(), {'LIVE1', 'LIVE2'});
      expect(state.records.any((r) => r.id == 'HIST1'), isFalse);
      state.dispose();
    });

    test('LEGACY-2 loadReport NO cambia activeCaptureSessionId', () async {
      final state = await readyState();
      final sessionBefore = state.activeCaptureSessionId;
      expect(sessionBefore, isNotNull);

      await state.loadReport(
        SavedReport(
          id: 'rep-legacy',
          name: 'Histórico legacy',
          createdAt: DateTime(2026, 8, 2),
          records: [_hist(id: 'HIST1')],
          createdByUid: 'admin-uid',
        ),
      );

      expect(state.activeCaptureSessionId, sessionBefore);
      state.dispose();
    });

    test('LEGACY-3 loadReport NO cambia savedCaptureRecordIds', () async {
      final state = await readyState();
      state.records = [_live(id: 'LIVE1', uid: 'admin-uid')];
      await savedCaptureIdsStorageService.save(
        uid: 'admin-uid',
        captureSessionId: state.activeCaptureSessionId!,
        ids: {'LIVE1'},
      );
      await state.ensureCaptureSessionReady();
      final before = Set<String>.from(state.savedCaptureRecordIds);
      expect(before, contains('LIVE1'));

      await state.loadReport(
        SavedReport(
          id: 'rep-legacy',
          name: 'Histórico legacy',
          createdAt: DateTime(2026, 8, 2),
          records: [_hist(id: 'HIST1')],
          createdByUid: 'admin-uid',
        ),
      );

      expect(state.savedCaptureRecordIds, before);
      state.dispose();
    });

    test('LEGACY-4 loadReport NO llama replace/clear/upsert cloud', () async {
      final cloud = _TrackingCloudSync();
      final state = await readyState(cloud: cloud);
      state.records = [
        _live(id: 'LIVE1', uid: 'admin-uid'),
        _live(id: 'LIVE2', uid: 'admin-uid'),
      ];

      await state.loadReport(
        SavedReport(
          id: 'rep-legacy',
          name: 'Histórico legacy',
          createdAt: DateTime(2026, 8, 2),
          records: [_hist(id: 'HIST1')],
          createdByUid: 'admin-uid',
        ),
      );

      expect(cloud.replaceCalls, 0);
      expect(cloud.clearCalls, 0);
      expect(cloud.upsertBatchCalls, 0);
      expect(cloud.upsertSingleCalls, 0);
      cloud.dispose();
      state.dispose();
    });

    test('LEGACY-5 loadReport deja viewingSavedReport para vista read-only',
        () async {
      final state = await readyState();
      await state.loadReport(
        SavedReport(
          id: 'rep-legacy',
          name: 'Histórico legacy',
          createdAt: DateTime(2026, 8, 2),
          records: [_hist(id: 'HIST1')],
          createdByUid: 'admin-uid',
        ),
      );

      expect(state.viewingSavedReport, isNotNull);
      expect(state.viewingSavedReport!.id, 'rep-legacy');
      expect(state.viewingSavedReport!.records.map((r) => r.id), ['HIST1']);
      state.dispose();
    });
  });

  group('VIEW-LIFECYCLE visor', () {
    test(
      'apertura exitosa sin diálogo (!mounted) deja viewingSavedReport null',
      () async {
        final state = await readyState();
        var presentCalled = false;

        await runSavedReportViewLifecycle(
          appState: state,
          report: SavedReport(
            id: 'rep-life',
            name: 'Lifecycle',
            createdAt: DateTime(2026, 8, 2),
            records: [_hist(id: 'HIST-L')],
            createdByUid: 'admin-uid',
          ),
          isMounted: () => false,
          present: (_) async {
            presentCalled = true;
          },
        );

        expect(presentCalled, isFalse);
        expect(state.viewingSavedReport, isNull);
        state.dispose();
      },
    );

    test(
      'apertura denegada no deja viewingSavedReport y no llama present',
      () async {
        final state = await readyState();
        // operario sin manageReports no abre informes de terceros.
        state.applyAuthProfile(
          AppUser(
            uid: 'op-uid',
            username: 'operario',
            role: AppUserRole.operario,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        var presentCalled = false;
        await runSavedReportViewLifecycle(
          appState: state,
          report: SavedReport(
            id: 'rep-other',
            name: 'Ajeno',
            createdAt: DateTime(2026, 8, 2),
            records: [_hist(id: 'HIST-X')],
            createdByUid: 'other-uid',
          ),
          isMounted: () => true,
          present: (_) async {
            presentCalled = true;
          },
        );

        expect(presentCalled, isFalse);
        expect(state.viewingSavedReport, isNull);
        state.dispose();
      },
    );
  });
}
