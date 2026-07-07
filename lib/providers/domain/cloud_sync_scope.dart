import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/errors/error_handler.dart';
import '../../models/app_user_role.dart';
import '../../models/nep_record.dart';
import '../../models/records_page_result.dart';
import '../../models/record_filters.dart';
import '../../models/sync_phase.dart';
import '../../services/cloud_sync_coordinator.dart';
import '../../services/cloud_sync_port.dart';
import '../../services/cloud_sync_service.dart';
import '../../services/firestore_record_query_builder.dart';
import '../../services/report_storage_service.dart';
import '../../utils/firebase_session_helper.dart';

/// Callbacks que conectan la sincronización en nube con el estado de la app.
class CloudSyncHost {
  const CloudSyncHost({
    required this.getAuthRole,
    required this.loadLocalRecords,
    required this.loadLocalFabrics,
    required this.applyRecordsPage,
    required this.applyFabrics,
    required this.syncFabricSelection,
    required this.cacheRecords,
    required this.cacheFabrics,
    required this.migrateReports,
    required this.refreshUserRoleAndConfig,
    required this.getActiveFilters,
    required this.getQueryLimit,
    required this.setRemoteFiltersActive,
    required this.onStateChanged,
    required this.reportStorageService,
  });

  final AppUserRole Function() getAuthRole;
  final Future<List<NepRecord>> Function() loadLocalRecords;
  final Future<List<String>> Function() loadLocalFabrics;
  final void Function(RecordsPageResult page) applyRecordsPage;
  final void Function(List<String> fabrics) applyFabrics;
  final void Function() syncFabricSelection;
  final Future<void> Function(List<NepRecord> records) cacheRecords;
  final Future<void> Function(List<String> fabrics) cacheFabrics;
  final Future<void> Function() migrateReports;
  final Future<void> Function() refreshUserRoleAndConfig;
  final RecordFilters Function() getActiveFilters;
  final int Function() getQueryLimit;
  final void Function(bool active) setRemoteFiltersActive;
  final VoidCallback onStateChanged;
  final ReportStorageService reportStorageService;
}

/// Ciclo de vida de Firebase sync: bootstrap, suscripciones y errores.
class CloudSyncScope {
  CloudSyncScope({
    required this.host,
    CloudSyncPort? service,
  })  : service = service,
        coordinator = service != null ? CloudSyncCoordinator(service) : null {
    host.reportStorageService.attachCloudSync(service);
  }

  final CloudSyncHost host;

  CloudSyncPort? service;
  CloudSyncCoordinator? coordinator;
  bool enabled = false;
  String? error;
  SyncPhase syncPhase = SyncPhase.loadingLocal;
  bool receivedRealtimeSnapshot = false;

  void resetSession() {
    coordinator?.dispose();
    coordinator = null;
    final current = service;
    if (current is CloudSyncService) {
      current.resetSession();
    }
    service = null;
    enabled = false;
    error = null;
    syncPhase = SyncPhase.loadingLocal;
    receivedRealtimeSnapshot = false;
    host.reportStorageService.attachCloudSync(null);
  }

  void attachService(CloudSyncPort newService) {
    if (service != null) return;
    service = newService;
    coordinator = CloudSyncCoordinator(newService);
    host.reportStorageService.attachCloudSync(newService);
  }

  void detachOnFailure() {
    coordinator?.dispose();
    coordinator = null;
    service = null;
    host.reportStorageService.attachCloudSync(null);
    enabled = false;
    syncPhase = SyncPhase.offline;
  }

  Future<void> connectWhenAuthenticated() => ensureConnected();

  /// Conecta o reconecta Firebase si hay sesión y aún no está en tiempo real.
  Future<void> ensureConnected() async {
    if (service == null) return;

    if (!isFirebaseSessionActive) {
      final hasSession = await waitForFirebaseSession(
        timeout: const Duration(seconds: 3),
      );
      if (!hasSession) {
        syncPhase = SyncPhase.offline;
        host.onStateChanged();
        return;
      }
    }

    if (enabled && syncPhase == SyncPhase.realtime) return;

    await connectInBackground();
  }

  Future<void> connectInBackground() async {
    try {
      await loadCloudData();
    } catch (error, stackTrace) {
      markUnavailable(error, stackTrace);
    }
  }

  Future<void> bootstrapReportsIfNeeded() async {
    final cloud = service;
    if (cloud == null || !isFirebaseSessionActive) return;
    try {
      await cloud.bootstrap();
      enabled = true;
      error = null;
      await host.migrateReports();
      host.onStateChanged();
    } catch (error, stackTrace) {
      ErrorHandler.log(error, stackTrace, 'prepareReportSync');
    }
  }

  Future<void> enableIfAvailable() async {
    if (service != null) return;
    try {
      attachService(CloudSyncService());
      await connectInBackground();
    } catch (error, stackTrace) {
      detachOnFailure();
      ErrorHandler.log(error, stackTrace, 'enableCloudSync');
    }
  }

  Future<void> loadCloudData() async {
    final coord = coordinator;
    if (coord == null) return;

    syncPhase = SyncPhase.syncingCloud;
    host.onStateChanged();

    try {
      await coord.bootstrap();
      enabled = true;
      error = null;
    } catch (error, stackTrace) {
      markUnavailable(error, stackTrace);
      return;
    }

    final localRecords = await host.loadLocalRecords();
    final localFabrics = await host.loadLocalFabrics();

    try {
      await coord.migrateLocalData(
        localRecords: localRecords,
        localFabrics: localFabrics,
      );
    } catch (error, stackTrace) {
      ErrorHandler.log(error, stackTrace, 'migrateLocalData');
    }

    try {
      await host.migrateReports();
    } catch (error, stackTrace) {
      ErrorHandler.log(error, stackTrace, 'migrateReports');
    }

    try {
      await coord.syncFabricsWithLocal(localFabrics);
    } catch (error, stackTrace) {
      ErrorHandler.log(error, stackTrace, 'syncFabrics');
    }

    await host.refreshUserRoleAndConfig();

    try {
      await _bindAllSubscriptions(waitForFirstSnapshot: true);
      receivedRealtimeSnapshot = true;
      syncPhase = SyncPhase.realtime;
    } catch (error, stackTrace) {
      enabled = false;
      this.error = ErrorHandler.userMessage(error);
      ErrorHandler.log(error, stackTrace, 'cloudSubscriptions');
      syncPhase = SyncPhase.offline;
      host.onStateChanged();
    }

    host.onStateChanged();
  }

  Future<void> rebindRecordsSubscription() async {
    final coord = coordinator;
    if (coord == null || !enabled) return;

    final filters = host.getActiveFilters();
    final limit = host.getQueryLimit();
    final useRemote = FirestoreRecordQueryBuilder.hasRemoteFilters(filters);
    host.setRemoteFiltersActive(useRemote);

    await coord.rebindRecordsOnly(
      viewerRole: host.getAuthRole(),
      filters: useRemote ? filters : null,
      limit: limit,
      onRecords: (page) {
        host.applyRecordsPage(page);
        unawaited(host.cacheRecords(page.records));
        receivedRealtimeSnapshot = true;
        syncPhase = SyncPhase.realtime;
        host.onStateChanged();
      },
    );
  }

  Future<void> _bindAllSubscriptions(
      {bool waitForFirstSnapshot = false}) async {
    final coord = coordinator;
    if (coord == null) return;

    final filters = host.getActiveFilters();
    final limit = host.getQueryLimit();
    final useRemote = FirestoreRecordQueryBuilder.hasRemoteFilters(filters);
    host.setRemoteFiltersActive(useRemote);

    await coord.bindSubscriptions(
      waitForFirstSnapshot: waitForFirstSnapshot,
      viewerRole: host.getAuthRole(),
      filters: useRemote ? filters : null,
      limit: limit,
      onConnectionError: handleStreamDisconnected,
      onRecords: (page) {
        host.applyRecordsPage(page);
        unawaited(host.cacheRecords(page.records));
        receivedRealtimeSnapshot = true;
        syncPhase = SyncPhase.realtime;
        host.onStateChanged();
      },
      onFabrics: (data) {
        host.applyFabrics(data);
        host.syncFabricSelection();
        unawaited(host.cacheFabrics(data));
        host.onStateChanged();
      },
    );
  }

  Future<void> ensureSubscriptions() async {
    final coord = coordinator;
    if (coord == null) return;
    await _bindAllSubscriptions();
  }

  Future<bool> ensureReady() async {
    final coord = coordinator;
    if (coord == null) return false;

    try {
      await coord.bootstrap();
      enabled = true;
      error = null;
      await ensureSubscriptions();
      return true;
    } catch (error, stackTrace) {
      markUnavailable(error, stackTrace);
      return false;
    }
  }

  void markUnavailable(Object error, StackTrace stackTrace) {
    enabled = false;
    syncPhase = SyncPhase.offline;
    if (isCloudAuthSkipError(error)) {
      this.error = null;
      return;
    }
    this.error = ErrorHandler.userMessage(error);
    ErrorHandler.log(error, stackTrace, 'cloudSync');
    host.onStateChanged();
  }

  Future<void> reconnectIfNeeded() => ensureConnected();

  void handleStreamDisconnected(Object error, StackTrace stackTrace) {
    if (syncPhase != SyncPhase.realtime) return;
    enabled = false;
    syncPhase = SyncPhase.offline;
    this.error = ErrorHandler.userMessage(error);
    ErrorHandler.log(error, stackTrace, 'cloudStream');
    host.onStateChanged();
  }

  Future<void> registerFcmToken(String token) async {
    if (service == null || !enabled) return;
    try {
      await coordinator!.registerFcmToken(token);
    } catch (error, stackTrace) {
      ErrorHandler.log(error, stackTrace, 'registerFcmToken');
    }
  }

  void dispose() {
    coordinator?.dispose();
    coordinator = null;
  }
}
