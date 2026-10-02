import 'dart:convert';

import 'package:calculadora_neps/core/constants.dart';
import 'package:calculadora_neps/models/app_user_role.dart';
import 'package:calculadora_neps/models/nep_record.dart';
import 'package:calculadora_neps/models/record_filters.dart';
import 'package:calculadora_neps/models/record_tombstone.dart';
import 'package:calculadora_neps/models/records_page_result.dart';
import 'package:calculadora_neps/models/saved_report.dart';
import 'package:calculadora_neps/models/saved_report_summary.dart';
import 'package:calculadora_neps/services/cloud_sync_port.dart';
import 'package:calculadora_neps/services/report_storage_service.dart';
import 'package:calculadora_neps/utils/report_summary_filters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

NepRecord _rec(String id, DateTime at, {String tela = 'BOLTON'}) {
  return NepRecord(
    id: id,
    telar: '1',
    tela: tela,
    loteTrama: 'L-$id',
    neps: 10,
    createdAt: at,
  );
}

SavedReport _full({
  required String id,
  required String name,
  String? uid,
  List<NepRecord>? records,
}) {
  return SavedReport(
    id: id,
    name: name,
    createdAt: DateTime(2026, 1, 10),
    createdByUid: uid,
    records: records ?? [_rec('r-$id', DateTime(2026, 1, 9))],
  );
}

class _TrackingCloudSync implements CloudSyncPort {
  final summaries = <SavedReportSummary>[];
  final fullById = <String, SavedReport>{};
  int fetchReportsCalls = 0;
  int fetchSummariesCalls = 0;
  int fetchByIdCalls = 0;

  @override
  Future<void> bootstrap() async {}

  @override
  Stream<List<NepRecord>> watchRecords({
    AppUserRole viewerRole = AppUserRole.operario,
    String? viewerRoleCode,
  }) =>
      Stream.value(const []);

  @override
  Stream<RecordsPageResult> watchRecentRecords({
    AppUserRole viewerRole = AppUserRole.operario,
    String? viewerRoleCode,
    int limit = 50,
  }) =>
      Stream.value(const RecordsPageResult(records: []));

  @override
  Stream<RecordsPageResult> watchRecordsByDateRange({
    required DateTime from,
    required DateTime to,
    AppUserRole viewerRole = AppUserRole.operario,
    String? viewerRoleCode,
    int limit = 50,
  }) =>
      Stream.value(const RecordsPageResult(records: []));

  @override
  Stream<RecordsPageResult> watchRecordsByFilters({
    required RecordFilters filters,
    AppUserRole viewerRole = AppUserRole.operario,
    String? viewerRoleCode,
    int limit = 50,
  }) =>
      Stream.value(const RecordsPageResult(records: []));

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
  Future<void> deleteRecord(String recordId, {String? ownerUid}) async {}

  @override
  Stream<List<RecordTombstone>> watchRecordTombstones() =>
      Stream.value(const []);

  @override
  Future<bool> hasRecordTombstone(String recordId) async => false;

  @override
  Future<void> clearRecords() async {}

  @override
  Future<void> replaceRecords(List<NepRecord> records) async {}

  @override
  Future<List<SavedReport>> fetchReports() async {
    fetchReportsCalls++;
    return fullById.values.toList();
  }

  @override
  Future<List<SavedReportSummary>> fetchReportSummaries() async {
    fetchSummariesCalls++;
    return List<SavedReportSummary>.from(summaries);
  }

  @override
  Future<SavedReport?> fetchReportById(String id) async {
    fetchByIdCalls++;
    return fullById[id];
  }

  @override
  Future<List<SavedReport>> fetchReportsByIds(List<String> ids) async {
    return [
      for (final id in ids)
        if (fullById[id] != null) fullById[id]!,
    ];
  }

  @override
  Future<SavedReport> saveReport(SavedReport report) async {
    fullById[report.id] = report;
    summaries.removeWhere((s) => s.id == report.id);
    summaries.add(SavedReportSummary.fromSavedReport(report));
    return report;
  }

  @override
  Future<void> deleteReport(String reportId) async {
    fullById.remove(reportId);
    summaries.removeWhere((s) => s.id == reportId);
  }

  @override
  Future<AppUserRole> fetchUserRole() async => AppUserRole.admin;

  @override
  Future<Map<String, dynamic>?> fetchAlertConfig() async => null;

  @override
  Future<void> saveAlertConfig(Map<String, dynamic> config) async {}

  @override
  Future<void> registerFcmToken(String token) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('listado usa summaries y no llama fetchReports', () async {
    final cloud = _TrackingCloudSync()
      ..summaries.add(
        SavedReportSummary.fromSavedReport(
          _full(id: 'cloud-1', name: 'Cloud', uid: 'uid-a'),
        ),
      );

    final storage = ReportStorageService(
      cloudSync: cloud,
      isSessionActive: () => true,
    );
    final result = await storage.loadReportSummariesResult(
      viewerUid: 'uid-a',
      canViewTeamReports: true,
    );

    expect(cloud.fetchSummariesCalls, 1);
    expect(cloud.fetchReportsCalls, 0);
    expect(result.metrics.usedFetchReportsForList, isFalse);
    expect(result.metrics.cloudRecordsDeserializedOnList, 0);
    expect(result.summaries.map((s) => s.id), contains('cloud-1'));
  });

  test('puente local: legacy sin summary aparece desde cache', () async {
    final legacy = _full(id: 'legacy-1', name: 'Legacy local', uid: 'uid-a');
    SharedPreferences.setMockInitialValues({
      savedReportsStorageKey: jsonEncode([legacy.toJson()]),
    });

    final cloud = _TrackingCloudSync();
    final storage = ReportStorageService(
      cloudSync: cloud,
      isSessionActive: () => true,
    );
    final result = await storage.loadReportSummariesResult(
      viewerUid: 'uid-a',
      canViewTeamReports: true,
    );

    expect(cloud.fetchReportsCalls, 0);
    expect(result.metrics.localSyntheticSummaries, 1);
    expect(result.summaries.single.id, 'legacy-1');
    expect(result.summaries.single.recordCount, 1);
  });

  test('visibilidad UID aplica a summaries', () async {
    final cloud = _TrackingCloudSync()
      ..summaries.addAll([
        SavedReportSummary.fromSavedReport(
          _full(id: 'mine', name: 'Mío', uid: 'uid-a'),
        ),
        SavedReportSummary.fromSavedReport(
          _full(id: 'other', name: 'Ajeno', uid: 'uid-b'),
        ),
      ]);

    final storage = ReportStorageService(
      cloudSync: cloud,
      isSessionActive: () => true,
    );
    final result = await storage.loadReportSummariesResult(
      viewerUid: 'uid-a',
      canViewTeamReports: false,
    );

    expect(result.summaries.map((s) => s.id), ['mine']);
  });

  test('resolveFullReport usa fetchReportById y no fetchReports', () async {
    final report = _full(id: 'full-1', name: 'Full', uid: 'uid-a');
    final cloud = _TrackingCloudSync()..fullById[report.id] = report;
    final storage = ReportStorageService(
      cloudSync: cloud,
      isSessionActive: () => true,
    );

    final resolved = await storage.resolveFullReport('full-1');
    expect(resolved?.id, 'full-1');
    expect(cloud.fetchByIdCalls, 1);
    expect(cloud.fetchReportsCalls, 0);
  });

  test('filtros livianos funcionan sobre summary sin full', () {
    final summaries = [
      SavedReportSummary(
        id: 'a',
        name: 'Alpha',
        createdAt: DateTime(2026, 1, 5),
        recordCount: 2,
      ),
      SavedReportSummary(
        id: 'b',
        name: 'Beta',
        createdAt: DateTime(2026, 2, 5),
        recordCount: 1,
      ),
    ];
    final filters = RecordFilters()
      ..searchText = 'alp'
      ..dateFrom = DateTime(2026, 1, 1);

    final visible = filterVisibleReportSummaries(summaries, filters);
    expect(visible.map((s) => s.id), ['a']);
  });

  test('filtro de contenido no incluye summary sin full local', () {
    final summaries = [
      SavedReportSummary(
        id: 'a',
        name: 'Alpha',
        createdAt: DateTime(2026, 1, 5),
        recordCount: 1,
      ),
    ];
    final filters = RecordFilters()..tela = 'BOLTON';
    final visible = filterVisibleReportSummaries(summaries, filters);
    expect(visible, isEmpty);

    final withFull = filterVisibleReportSummaries(
      summaries,
      filters,
      fullById: {
        'a': _full(
          id: 'a',
          name: 'Alpha',
          records: [_rec('r1', DateTime(2026, 1, 4), tela: 'BOLTON')],
        ),
      },
    );
    expect(withFull.map((s) => s.id), ['a']);
  });
}
