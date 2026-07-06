import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/errors/error_handler.dart';
import '../../models/app_user_role.dart';
import '../../models/nep_record.dart';
import '../../services/cloud_sync_coordinator.dart';
import '../../services/cloud_sync_port.dart';
import '../../services/cloud_sync_service.dart';
import '../../services/report_storage_service.dart';
import '../../utils/firebase_session_helper.dart';

/// Callbacks que conectan la sincronización en nube con el estado de la app.
class CloudSyncHost {
  const CloudSyncHost({
    required this.getAuthRole,
    required this.loadLocalRecords,
    required this.loadLocalFabrics,
    required this.applyRecords,
    required this.applyFabrics,
    required this.syncFabricSelection,
    required this.cacheRecords,
    required this.cacheFabrics,
    required this.migrateReports,
    required this.refreshUserRoleAndConfig,
    required this.onStateChanged,
    required this.reportStorageService,
  });

  final AppUserRole Function() getAuthRole;
  final Future<List<NepRecord>> Function() loadLocalRecords;
  final Future<List<String>> Function() loadLocalFabrics;
  final void Function(List<NepRecord> records) applyRecords;
  final void Function(List<String> fabrics) applyFabrics;
  final void Function() syncFabricSelection;
  final Future<void> Function(List<NepRecord> records) cacheRecords;
  final Future<void> Function(List<String> fabrics) cacheFabrics;
  final Future<void> Function() migrateReports;
  final Future<void> Function() refreshUserRoleAndConfig;
  final VoidCallback onStateChanged;
  final ReportStorageService reportStorageService;
}

/// Ciclo de vida de Firebase sync: bootstrap, suscripciones y errores.
class CloudSyncScope {
  CloudSyncScope({
    required this.host,
    CloudSyncPort? service,
  })  : service = service,
        coordinator =
            service != null ? CloudSyncCoordinator(service) : null {
    host.reportStorageService.attachCloudSync(service);
  }

  final CloudSyncHost host;

  CloudSyncPort? service;
  CloudSyncCoordinator? coordinator;
  bool enabled = false;
  String? error;

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
  }

  Future<void> connectWhenAuthenticated() async {
    if (service == null) return;
    final hasSession = await waitForFirebaseSession();
    if (!hasSession) return;
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
      await coord.bindSubscriptions(
        waitForFirstSnapshot: true,
        viewerRole: host.getAuthRole(),
        onRecords: (data) {
          host.applyRecords(data);
          unawaited(host.cacheRecords(data));
          host.onStateChanged();
        },
        onFabrics: (data) {
          host.applyFabrics(data);
          host.syncFabricSelection();
          unawaited(host.cacheFabrics(data));
          host.onStateChanged();
        },
      );
    } catch (error, stackTrace) {
      ErrorHandler.log(error, stackTrace, 'cloudSubscriptions');
    }

    host.onStateChanged();
  }

  Future<void> ensureSubscriptions() async {
    final coord = coordinator;
    if (coord == null) return;

    await coord.bindSubscriptions(
      viewerRole: host.getAuthRole(),
      onRecords: (data) {
        host.applyRecords(data);
        unawaited(host.cacheRecords(data));
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
    if (isCloudAuthSkipError(error)) {
      this.error = null;
      return;
    }
    this.error = ErrorHandler.userMessage(error);
    ErrorHandler.log(error, stackTrace, 'cloudSync');
    host.onStateChanged();
  }

  Future<void> reconnectIfNeeded() async {
    if (service == null || enabled) return;
    if (!isFirebaseSessionActive) return;

    try {
      await connectInBackground();
      error = null;
      host.onStateChanged();
    } catch (error, stackTrace) {
      markUnavailable(error, stackTrace);
    }
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
