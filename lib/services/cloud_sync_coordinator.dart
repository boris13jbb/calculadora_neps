import 'dart:async';

import '../models/app_user_role.dart';
import '../models/nep_record.dart';
import '../models/saved_report.dart';
import 'cloud_sync_port.dart';

/// Orquesta bootstrap, migraciones y suscripciones en tiempo real de Firestore.
///
/// [AppState] conserva el estado visible (records, fabrics, flags) y delega
/// la conexión persistente a este coordinador.
class CloudSyncCoordinator {
  CloudSyncCoordinator(this._cloud);

  final CloudSyncPort _cloud;

  StreamSubscription<List<NepRecord>>? _recordsSubscription;
  StreamSubscription<List<String>>? _fabricsSubscription;

  Future<void> bootstrap() => _cloud.bootstrap();

  Future<void> migrateLocalData({
    required List<NepRecord> localRecords,
    required List<String> localFabrics,
  }) {
    return _cloud.migrateLocalDataIfNeeded(
      localRecords: localRecords,
      localFabrics: localFabrics,
    );
  }

  Future<void> syncFabricsWithLocal(List<String> localFabrics) {
    return _cloud.syncFabricsWithLocal(localFabrics);
  }

  Future<AppUserRole> fetchUserRole() => _cloud.fetchUserRole();

  Future<Map<String, dynamic>?> fetchAlertConfig() => _cloud.fetchAlertConfig();

  Future<void> saveAlertConfig(Map<String, dynamic> config) =>
      _cloud.saveAlertConfig(config);

  Future<void> registerFcmToken(String token) => _cloud.registerFcmToken(token);

  Future<List<String>> saveFabrics(List<String> fabrics) =>
      _cloud.saveFabrics(fabrics);

  Future<void> upsertRecord(NepRecord record) => _cloud.upsertRecord(record);

  Future<void> upsertRecords(List<NepRecord> records) =>
      _cloud.upsertRecords(records);

  Future<void> deleteRecord(String recordId) => _cloud.deleteRecord(recordId);

  Future<void> clearRecords() => _cloud.clearRecords();

  Future<void> replaceRecords(List<NepRecord> records) =>
      _cloud.replaceRecords(records);

  Future<List<SavedReport>> fetchReports() => _cloud.fetchReports();

  Future<SavedReport> saveReport(SavedReport report) =>
      _cloud.saveReport(report);

  Future<void> deleteReport(String reportId) => _cloud.deleteReport(reportId);

  /// Escucha registros y telas. Opcionalmente espera el primer snapshot.
  Future<void> bindSubscriptions({
    required void Function(List<NepRecord> records) onRecords,
    required void Function(List<String> fabrics) onFabrics,
    bool waitForFirstSnapshot = false,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    _recordsSubscription?.cancel();
    _fabricsSubscription?.cancel();

    final recordsReady = Completer<void>();
    final fabricsReady = Completer<void>();

    _recordsSubscription = _cloud.watchRecords().listen(
      (data) {
        onRecords(data);
        if (!recordsReady.isCompleted) recordsReady.complete();
      },
      onError: (Object error) {
        if (!recordsReady.isCompleted) recordsReady.completeError(error);
      },
    );

    _fabricsSubscription = _cloud.watchFabrics().listen(
      (data) {
        onFabrics(data);
        if (!fabricsReady.isCompleted) fabricsReady.complete();
      },
      onError: (Object error) {
        if (!fabricsReady.isCompleted) fabricsReady.completeError(error);
      },
    );

    if (!waitForFirstSnapshot) return;

    try {
      await Future.wait([
        recordsReady.future,
        fabricsReady.future,
      ]).timeout(timeout);
    } on TimeoutException {
      if (!recordsReady.isCompleted) recordsReady.complete();
      if (!fabricsReady.isCompleted) fabricsReady.complete();
    }
  }

  void dispose() {
    _recordsSubscription?.cancel();
    _fabricsSubscription?.cancel();
    _recordsSubscription = null;
    _fabricsSubscription = null;
  }
}
