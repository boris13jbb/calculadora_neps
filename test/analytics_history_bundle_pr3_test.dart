import 'dart:convert';

import 'package:calculadora_neps/core/constants.dart';
import 'package:calculadora_neps/core/permissions/role_catalog.dart';
import 'package:calculadora_neps/models/analytics_period.dart';
import 'package:calculadora_neps/models/app_user.dart';
import 'package:calculadora_neps/models/app_user_role.dart';
import 'package:calculadora_neps/models/nep_record.dart';
import 'package:calculadora_neps/models/record_filters.dart';
import 'package:calculadora_neps/models/record_tombstone.dart';
import 'package:calculadora_neps/models/records_page_result.dart';
import 'package:calculadora_neps/models/saved_report.dart';
import 'package:calculadora_neps/models/saved_report_summary.dart';
import 'package:calculadora_neps/providers/app_state.dart';
import 'package:calculadora_neps/services/analytics_service.dart';
import 'package:calculadora_neps/services/cloud_sync_port.dart';
import 'package:calculadora_neps/services/report_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

NepRecord _rec(String id, DateTime at) {
  return NepRecord(
    id: id,
    telar: '1',
    tela: 'T',
    loteTrama: 'L',
    neps: 10,
    createdAt: at,
  );
}

SavedReport _report({
  required String id,
  required DateTime recordAt,
  String? uid,
  DateTime? createdAt,
}) {
  return SavedReport(
    id: id,
    name: id,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
    createdByUid: uid ?? 'admin-uid',
    records: [_rec('r-$id', recordAt)],
  );
}

class _TrackingCloudSync implements CloudSyncPort {
  final summaries = <SavedReportSummary>[];
  final fullById = <String, SavedReport>{};
  int fetchReportsCalls = 0;
  int fetchSummariesCalls = 0;
  int fetchByIdsCalls = 0;
  final fetchedByIdsArgs = <List<String>>[];

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
  Future<SavedReport?> fetchReportById(String id) async => fullById[id];

  @override
  Future<List<SavedReport>> fetchReportsByIds(List<String> ids) async {
    fetchByIdsCalls++;
    fetchedByIdsArgs.add(List<String>.from(ids));
    return [
      for (final id in ids)
        if (fullById[id] != null) fullById[id]!,
    ];
  }

  @override
  Future<SavedReport> saveReport(SavedReport report) async {
    fullById[report.id] = report;
    return report;
  }

  @override
  Future<void> deleteReport(String reportId) async {
    fullById.remove(reportId);
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

class _FixedAnalytics extends AnalyticsService {
  _FixedAnalytics(this.now);
  final DateTime now;

  @override
  ({DateTime start, DateTime end})? periodInclusiveBounds(
    AnalyticsPeriod period, {
    DateTime? reference,
    DateTime? customFrom,
    DateTime? customTo,
  }) {
    return super.periodInclusiveBounds(
      period,
      reference: reference ?? now,
      customFrom: customFrom,
      customTo: customTo,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RoleCatalog.instance.resetAuthorization();
    RoleCatalog.instance.replaceAll(RoleCatalog.baseRoles);
    RoleCatalog.instance.markAuthorizationReady();
  });

  Future<AppState> readyState({
    required _TrackingCloudSync cloud,
    AppUser? user,
  }) async {
    final storage = ReportStorageService(
      cloudSync: cloud,
      isSessionActive: () => true,
    );
    final state = AppState(
      cloudSyncService: cloud,
      reportStorageService: storage,
    );
    state.applyAuthProfile(
      user ??
          AppUser(
            uid: 'admin-uid',
            username: 'admin',
            role: AppUserRole.admin,
          ),
    );
    await state.initialize();
    state.cloudSyncEnabled = true;
    return state;
  }

  void seedReport(
    _TrackingCloudSync cloud,
    SavedReport report,
  ) {
    cloud.fullById[report.id] = report;
    cloud.summaries.add(SavedReportSummary.fromSavedReport(report));
  }

  final ref = DateTime(2026, 3, 15);
  final analytics = _FixedAnalytics(ref);

  test('camino PR3: summaries + byIds y fetchReports == 0', () async {
    final cloud = _TrackingCloudSync();
    seedReport(
      cloud,
      _report(id: 'a', recordAt: DateTime(2026, 3, 10)),
    );
    seedReport(
      cloud,
      _report(id: 'b', recordAt: DateTime(2026, 1, 5)),
    );

    final state = await readyState(cloud: cloud);
    final bundle = await state.loadAnalyticsHistoryBundleForPeriod(
      period: AnalyticsPeriod.month,
      reference: ref,
      analytics: analytics,
    );

    expect(cloud.fetchSummariesCalls, greaterThanOrEqualTo(1));
    expect(cloud.fetchReportsCalls, 0);
    expect(bundle.metrics.usedFetchReports, isFalse);
    expect(cloud.fetchByIdsCalls, 1);
    expect(cloud.fetchedByIdsArgs.single, ['a']);
    expect(bundle.historyReports.map((r) => r.id), contains('a'));
    expect(bundle.historyReports.map((r) => r.id), isNot(contains('b')));
    state.dispose();
  });

  test('59 candidatos: fetchReportsByIds recibe 59 IDs', () async {
    final cloud = _TrackingCloudSync();
    for (var i = 0; i < 59; i++) {
      seedReport(
        cloud,
        _report(id: 'r$i', recordAt: DateTime(2026, 3, 1 + (i % 28))),
      );
    }

    final state = await readyState(cloud: cloud);
    final bundle = await state.loadAnalyticsHistoryBundleForPeriod(
      period: AnalyticsPeriod.month,
      reference: ref,
      analytics: analytics,
    );

    expect(cloud.fetchReportsCalls, 0);
    expect(bundle.metrics.reportsCandidates, 59);
    expect(cloud.fetchedByIdsArgs.single.length, 59);
    state.dispose();
  });

  test('parcial: solo 5 intersectan → 5 IDs, no 59', () async {
    final cloud = _TrackingCloudSync();
    for (var i = 0; i < 54; i++) {
      seedReport(
        cloud,
        _report(id: 'out$i', recordAt: DateTime(2025, 6, 1)),
      );
    }
    for (var i = 0; i < 5; i++) {
      seedReport(
        cloud,
        _report(id: 'in$i', recordAt: DateTime(2026, 3, 10 + i)),
      );
    }

    final state = await readyState(cloud: cloud);
    final bundle = await state.loadAnalyticsHistoryBundleForPeriod(
      period: AnalyticsPeriod.month,
      reference: ref,
      analytics: analytics,
    );

    expect(cloud.fetchReportsCalls, 0);
    expect(bundle.metrics.reportsCandidates, 5);
    expect(cloud.fetchedByIdsArgs.single.toSet(), {
      'in0',
      'in1',
      'in2',
      'in3',
      'in4',
    });
    state.dispose();
  });

  test('caché: segunda carga mismo período → 0 nuevos fetch', () async {
    final cloud = _TrackingCloudSync();
    for (var i = 0; i < 5; i++) {
      seedReport(
        cloud,
        _report(id: 'c$i', recordAt: DateTime(2026, 3, 10)),
      );
    }

    final state = await readyState(cloud: cloud);
    final first = await state.loadAnalyticsHistoryBundleForPeriod(
      period: AnalyticsPeriod.month,
      reference: ref,
      analytics: analytics,
    );
    expect(first.metrics.reportsHydrated, 5);
    expect(cloud.fetchByIdsCalls, 1);

    final second = await state.loadAnalyticsHistoryBundleForPeriod(
      period: AnalyticsPeriod.month,
      reference: ref,
      analytics: analytics,
    );
    expect(cloud.fetchByIdsCalls, 1);
    expect(second.metrics.reportsHydrated, 0);
    expect(second.metrics.reportsReusedFromCache, 5);
    expect(cloud.fetchReportsCalls, 0);
    state.dispose();
  });

  test('cambio de período: semana A B C → mes pide solo D E', () async {
    final cloud = _TrackingCloudSync();
    // Semana del 15-mar-2026: lunes 9 → domingo 15
    seedReport(cloud, _report(id: 'A', recordAt: DateTime(2026, 3, 10)));
    seedReport(cloud, _report(id: 'B', recordAt: DateTime(2026, 3, 12)));
    seedReport(cloud, _report(id: 'C', recordAt: DateTime(2026, 3, 14)));
    seedReport(cloud, _report(id: 'D', recordAt: DateTime(2026, 3, 2)));
    seedReport(cloud, _report(id: 'E', recordAt: DateTime(2026, 3, 20)));

    final state = await readyState(cloud: cloud);
    final week = await state.loadAnalyticsHistoryBundleForPeriod(
      period: AnalyticsPeriod.week,
      reference: ref,
      analytics: analytics,
    );
    expect(week.metrics.reportsCandidates, 3);
    expect(cloud.fetchedByIdsArgs.last.toSet(), {'A', 'B', 'C'});

    final month = await state.loadAnalyticsHistoryBundleForPeriod(
      period: AnalyticsPeriod.month,
      reference: ref,
      analytics: analytics,
    );
    expect(month.metrics.reportsCandidates, 5);
    expect(month.metrics.reportsReusedFromCache, 3);
    expect(cloud.fetchedByIdsArgs.last.toSet(), {'D', 'E'});
    expect(cloud.fetchReportsCalls, 0);
    state.dispose();
  });

  test('visibilidad: operario no hidrata reports ajenos', () async {
    final cloud = _TrackingCloudSync();
    seedReport(
      cloud,
      _report(id: 'mine', recordAt: DateTime(2026, 3, 10), uid: 'op-uid'),
    );
    seedReport(
      cloud,
      _report(id: 'theirs', recordAt: DateTime(2026, 3, 10), uid: 'other'),
    );

    final state = await readyState(
      cloud: cloud,
      user: AppUser(
        uid: 'op-uid',
        username: 'op',
        role: AppUserRole.operario,
      ),
    );
    final bundle = await state.loadAnalyticsHistoryBundleForPeriod(
      period: AnalyticsPeriod.month,
      reference: ref,
      analytics: analytics,
    );

    expect(cloud.fetchReportsCalls, 0);
    expect(bundle.historyReports.map((r) => r.id).toSet(), {'mine'});
    expect(bundle.metrics.reportsCandidates, 1);
    state.dispose();
  });

  test(
      'legacy: summary missing + SavedReport local → usa local sin fetchReports',
      () async {
    final local = _report(
      id: 'legacy-local',
      recordAt: DateTime(2026, 3, 10),
      uid: 'admin-uid',
    );
    SharedPreferences.setMockInitialValues({
      savedReportsStorageKey: jsonEncode([local.toJson()]),
    });

    final cloud = _TrackingCloudSync();
    final state = await readyState(cloud: cloud);
    final bundle = await state.loadAnalyticsHistoryBundleForPeriod(
      period: AnalyticsPeriod.month,
      reference: ref,
      analytics: analytics,
    );

    expect(cloud.fetchReportsCalls, 0);
    expect(bundle.historyReports.map((r) => r.id), contains('legacy-local'));
    state.dispose();
  });

  test('legacy: summary missing + local missing → NO fetchReports', () async {
    final cloud = _TrackingCloudSync();
    // Sin summaries ni fulls: camino vacío, sin fallback global.
    final state = await readyState(cloud: cloud);
    final bundle = await state.loadAnalyticsHistoryBundleForPeriod(
      period: AnalyticsPeriod.month,
      reference: ref,
      analytics: analytics,
    );

    expect(cloud.fetchReportsCalls, 0);
    expect(cloud.fetchByIdsCalls, 0);
    expect(bundle.metrics.usedFetchReports, isFalse);
    state.dispose();
  });

  test('caché se invalida al cerrar sesión', () async {
    final cloud = _TrackingCloudSync();
    seedReport(
      cloud,
      _report(id: 'x', recordAt: DateTime(2026, 3, 10)),
    );
    final state = await readyState(cloud: cloud);
    await state.loadAnalyticsHistoryBundleForPeriod(
      period: AnalyticsPeriod.month,
      reference: ref,
      analytics: analytics,
    );
    expect(state.analyticsHydratedCacheSize, 1);

    state.resetCloudSession();
    expect(state.analyticsHydratedCacheSize, 0);
    state.dispose();
  });
}
