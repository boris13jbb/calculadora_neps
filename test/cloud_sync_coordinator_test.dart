import 'dart:async';

import 'package:calculadora_neps/models/app_user_role.dart';
import 'package:calculadora_neps/models/nep_record.dart';
import 'package:calculadora_neps/models/record_filters.dart';
import 'package:calculadora_neps/models/records_page_result.dart';
import 'package:calculadora_neps/models/saved_report.dart';
import 'package:calculadora_neps/services/cloud_sync_coordinator.dart';
import 'package:calculadora_neps/services/cloud_sync_port.dart';
import 'package:flutter_test/flutter_test.dart';

/// Puerto falso para validar el rol pasado a las suscripciones en nube.
class FakeCloudSyncPort implements CloudSyncPort {
  AppUserRole? lastViewerRole;
  int? lastLimit;
  RecordFilters? lastFilters;

  @override
  Future<void> bootstrap() async {}

  @override
  Stream<List<NepRecord>> watchRecords({
    AppUserRole viewerRole = AppUserRole.operario,
  }) {
    lastViewerRole = viewerRole;
    return Stream.value(const []);
  }

  @override
  Stream<RecordsPageResult> watchRecentRecords({
    AppUserRole viewerRole = AppUserRole.operario,
    int limit = 50,
  }) {
    lastViewerRole = viewerRole;
    lastLimit = limit;
    return Stream.value(const RecordsPageResult(records: []));
  }

  @override
  Stream<RecordsPageResult> watchRecordsByDateRange({
    required DateTime from,
    required DateTime to,
    AppUserRole viewerRole = AppUserRole.operario,
    int limit = 50,
  }) {
    lastViewerRole = viewerRole;
    lastLimit = limit;
    return Stream.value(const RecordsPageResult(records: []));
  }

  @override
  Stream<RecordsPageResult> watchRecordsByFilters({
    required RecordFilters filters,
    AppUserRole viewerRole = AppUserRole.operario,
    int limit = 50,
  }) {
    lastViewerRole = viewerRole;
    lastLimit = limit;
    lastFilters = filters;
    return Stream.value(const RecordsPageResult(records: []));
  }

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
  Future<void> deleteRecord(String recordId, {String? ownerUid}) async {}

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
  Future<AppUserRole> fetchUserRole() async => AppUserRole.operario;

  @override
  Future<Map<String, dynamic>?> fetchAlertConfig() async => null;

  @override
  Future<void> saveAlertConfig(Map<String, dynamic> config) async {}

  @override
  Future<void> registerFcmToken(String token) async {}
}

void main() {
  test('CloudSyncCoordinator reenvía viewerRole al puerto', () async {
    final port = FakeCloudSyncPort();
    final coordinator = CloudSyncCoordinator(port);

    await coordinator.bindSubscriptions(
      viewerRole: AppUserRole.supervisor,
      onRecords: (_) {},
      onFabrics: (_) {},
      limit: 75,
    );

    expect(port.lastViewerRole, AppUserRole.supervisor);
    expect(port.lastLimit, 75);
  });
}
