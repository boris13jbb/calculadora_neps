import 'dart:async';

import 'package:calculadora_neps/core/permissions/permission.dart';
import 'package:calculadora_neps/core/permissions/role_catalog.dart';
import 'package:calculadora_neps/core/theme/app_theme.dart';
import 'package:calculadora_neps/core/widgets/records_table.dart';
import 'package:calculadora_neps/models/app_user.dart';
import 'package:calculadora_neps/models/app_user_role.dart';
import 'package:calculadora_neps/models/nep_record.dart';
import 'package:calculadora_neps/models/record_delete_outcome.dart';
import 'package:calculadora_neps/models/record_filters.dart';
import 'package:calculadora_neps/models/records_page_result.dart';
import 'package:calculadora_neps/models/saved_report.dart';
import 'package:calculadora_neps/providers/app_state.dart';
import 'package:calculadora_neps/services/cloud_sync_port.dart';
import 'package:calculadora_neps/services/cloud_sync_service.dart';
import 'package:calculadora_neps/services/pending_sync_queue_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TrackingCloudSync implements CloudSyncPort {
  final deleted = <({String id, String? ownerUid})>[];
  Object? throwOnDelete;
  bool failBootstrap = false;
  final _recordsController = StreamController<RecordsPageResult>.broadcast();

  void emitRecords(List<NepRecord> records) {
    _recordsController.add(RecordsPageResult(records: records, hasMore: false));
  }

  @override
  Future<void> bootstrap() async {
    if (failBootstrap) {
      throw StateError('cloud offline');
    }
  }

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
  Future<void> upsertRecord(NepRecord record) async {}

  @override
  Future<void> upsertRecords(List<NepRecord> records) async {}

  @override
  Future<void> deleteRecord(String recordId, {String? ownerUid}) async {
    if (throwOnDelete != null) throw throwOnDelete!;
    deleted.add((id: recordId, ownerUid: ownerUid));
  }

  @override
  Future<void> clearRecords() async {}

  @override
  Future<void> replaceRecords(List<NepRecord> records) async {}

  @override
  Future<List<SavedReport>> fetchReports() async => [];

  @override
  Future<SavedReport> saveReport(SavedReport report) async => report;

  @override
  Future<void> deleteReport(String reportId) async {}

  @override
  Future<AppUserRole> fetchUserRole() async => AppUserRole.superAdmin;

  @override
  Future<Map<String, dynamic>?> fetchAlertConfig() async => null;

  @override
  Future<void> saveAlertConfig(Map<String, dynamic> config) async {}

  @override
  Future<void> registerFcmToken(String token) async {}

  void dispose() {
    _recordsController.close();
  }
}

NepRecord _record({
  required String id,
  required String? ownerUid,
  String telar = '1',
}) {
  return NepRecord(
    id: id,
    telar: telar,
    neps: 10,
    tela: 'Denim',
    loteTrama: 'L1',
    createdAt: DateTime.utc(2026, 9, 11, 12),
    createdByUid: ownerUid,
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

  group('Owner resolution', () {
    test('G) legacy owner desde workspace doc', () {
      expect(
        CloudSyncService.resolveOwnerUidForDelete(
          providedOwnerUid: null,
          workspaceDocData: {'ownerUid': 'user_A', 'createdByUid': 'other'},
        ),
        'user_A',
      );
      expect(
        CloudSyncService.resolveOwnerUidForDelete(
          providedOwnerUid: null,
          workspaceDocData: {'createdByUid': 'user_B'},
        ),
        'user_B',
      );
      expect(
        CloudSyncService.resolveOwnerUidForDelete(
          providedOwnerUid: 'provided',
          workspaceDocData: {'ownerUid': 'user_A'},
        ),
        'provided',
      );
      expect(
        CloudSyncService.resolveOwnerUidForDelete(
          providedOwnerUid: null,
          workspaceDocData: {},
        ),
        isNull,
      );
    });
  });

  group('Permisos UI', () {
    test('A) super_admin canDeleteRecords = true', () {
      expect(
        RoleCatalog.instance
            .hasPermission('super_admin', Permission.deleteRecords),
        isTrue,
      );
      final state = AppState();
      state.applyAuthProfile(
        AppUser(
          uid: 'sa',
          username: 'admin',
          role: AppUserRole.superAdmin,
        ),
      );
      expect(state.authRoleCode, 'super_admin');
      expect(state.canDeleteRecords, isTrue);
      state.dispose();
    });

    testWidgets('B) sin deleteRecords botón disabled y sin callback',
        (tester) async {
      final state = AppState();
      state.applyAuthProfile(
        AppUser(
          uid: 'op',
          username: 'oper',
          role: AppUserRole.operario,
        ),
      );
      expect(state.canDeleteRecords, isFalse);

      var deleted = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(),
          home: Scaffold(
            body: SizedBox(
              width: 900,
              height: 600,
              child: RecordsTable(
                appState: state,
                records: [_record(id: 'r1', ownerUid: 'op')],
                onDelete: (_) async => deleted = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Sin permiso para eliminar'), findsOneWidget);
      final deleteButtons = tester
          .widgetList<IconButton>(find.byType(IconButton))
          .where((button) => button.tooltip == 'Sin permiso para eliminar');
      expect(deleteButtons, isNotEmpty);
      expect(deleteButtons.every((button) => button.onPressed == null), isTrue);
      expect(deleted, isFalse);
      state.dispose();
    });
  });

  group('Delete cloud-first', () {
    test('C) eliminar propio pasa owner correcto y quita local', () async {
      final cloud = _TrackingCloudSync();
      final state = AppState(cloudSyncService: cloud);
      state.applyAuthProfile(
        AppUser(uid: 'user_A', username: 'a', role: AppUserRole.admin),
      );
      await state.initialize();
      state.records = [_record(id: 'r1', ownerUid: 'user_A')];

      final outcome = await state.deleteRecord('r1');
      expect(outcome, RecordDeleteOutcome.deletedRemote);
      expect(cloud.deleted, hasLength(1));
      expect(cloud.deleted.single.id, 'r1');
      expect(cloud.deleted.single.ownerUid, 'user_A');
      expect(state.records.any((r) => r.id == 'r1'), isFalse);
      cloud.dispose();
      state.dispose();
    });

    test('D) super_admin elimina registro ajeno sin usar su UID', () async {
      final cloud = _TrackingCloudSync();
      final state = AppState(cloudSyncService: cloud);
      state.applyAuthProfile(
        AppUser(
          uid: 'super_admin_uid',
          username: 'sa',
          role: AppUserRole.superAdmin,
        ),
      );
      await state.initialize();
      state.records = [_record(id: 'r2', ownerUid: 'user_A')];

      final outcome = await state.deleteRecord('r2');
      expect(outcome, RecordDeleteOutcome.deletedRemote);
      expect(cloud.deleted.single.ownerUid, 'user_A');
      expect(cloud.deleted.single.ownerUid, isNot('super_admin_uid'));
      expect(state.records, isEmpty);
      cloud.dispose();
      state.dispose();
    });

    test('E) permission-denied no borra local ni trata como offline', () async {
      final cloud = _TrackingCloudSync()
        ..throwOnDelete = FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'denied',
        );
      final state = AppState(cloudSyncService: cloud);
      state.applyAuthProfile(
        AppUser(
          uid: 'sa',
          username: 'sa',
          role: AppUserRole.superAdmin,
        ),
      );
      await state.initialize();
      state.records = [_record(id: 'r3', ownerUid: 'user_A')];

      final outcome = await state.deleteRecord('r3');
      expect(outcome, RecordDeleteOutcome.permissionDenied);
      expect(state.records.any((r) => r.id == 'r3'), isTrue);
      expect(cloud.deleted, isEmpty);
      final pending = await pendingSyncQueueService.loadForUid('sa');
      expect(pending, isEmpty);
      cloud.dispose();
      state.dispose();
    });

    test('F) offline real elimina local y encola PendingDelete', () async {
      final cloud = _TrackingCloudSync()..failBootstrap = true;
      final state = AppState(cloudSyncService: cloud);
      state.applyAuthProfile(
        AppUser(uid: 'user_A', username: 'a', role: AppUserRole.admin),
      );
      await state.initialize();
      state.records = [_record(id: 'r4', ownerUid: 'user_A')];

      final outcome = await state.deleteRecord('r4');
      expect(outcome, RecordDeleteOutcome.deletedLocalPendingSync);
      expect(state.records.any((r) => r.id == 'r4'), isFalse);
      final pending = await pendingSyncQueueService.loadForUid('user_A');
      expect(pending, hasLength(1));
      expect(pending.single.type, PendingSyncOpType.delete);
      expect(pending.single.recordId, 'r4');
      expect(pending.single.ownerUid, 'user_A');
      cloud.dispose();
      state.dispose();
    });

    test('H) tras delete remoto el registro no reaparece en memoria', () async {
      final cloud = _TrackingCloudSync();
      final state = AppState(cloudSyncService: cloud);
      state.applyAuthProfile(
        AppUser(
          uid: 'sa',
          username: 'sa',
          role: AppUserRole.superAdmin,
        ),
      );
      await state.initialize();
      final record = _record(id: 'r5', ownerUid: 'user_A');
      state.records = [record];

      await state.deleteRecord('r5');
      expect(state.records.any((r) => r.id == 'r5'), isFalse);

      // Un snapshot remoto sin el registro no lo reintroduce.
      cloud.emitRecords(const []);
      await Future<void>.delayed(Duration.zero);
      expect(state.records.any((r) => r.id == 'r5'), isFalse);

      cloud.dispose();
      state.dispose();
    });
  });
}
