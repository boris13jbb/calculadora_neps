import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show
        TargetPlatform,
        debugPrint,
        defaultTargetPlatform,
        kIsWeb,
        visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/navigation/app_navigation.dart';
import '../core/alert_config.dart';
import '../core/constants.dart';
import '../core/errors/error_handler.dart';
import '../core/permissions/report_visibility.dart';
import '../models/app_user.dart';
import '../models/app_user_role.dart';
import '../models/alert_level.dart';
import '../models/corrective_action_entry.dart';
import '../models/export_column.dart';
import '../models/nep_record.dart';
import '../models/pdf_report_style.dart';
import '../models/record_delete_outcome.dart';
import '../models/record_filters.dart';
import '../models/record_import_result.dart';
import '../models/saved_report.dart';
import '../models/reports_load_result.dart';
import '../models/analytics_history_bundle.dart';
import '../models/sync_phase.dart';
import '../services/alert_config_service.dart';
import '../services/alert_service.dart';
import '../services/cloud_sync_coordinator.dart';
import '../services/cloud_sync_port.dart';
import '../services/cloud_sync_service.dart';
import '../services/fabric_catalog_service.dart';
import '../services/import_template_service.dart';
import '../services/lote_trama_catalog_service.dart';
import '../services/notification_preferences_service.dart';
import '../services/notification_service.dart';
import '../services/permissions_service.dart';
import '../core/permissions/permission.dart';
import '../core/permissions/role_permissions.dart';
import '../services/record_export_coordinator.dart';
import '../services/record_import_service.dart';
import '../services/report_export_service.dart';
import '../features/reports/professional/models/report_configuration.dart';
import '../services/report_records_loader.dart';
import '../services/report_storage_service.dart';
import '../services/siri_shortcut_service.dart';
import '../utils/file_share_helper.dart';
import '../utils/filter_description_helper.dart';
import '../utils/analytics_records_source.dart';
import '../utils/lote_trama_helper.dart';
import '../utils/stable_id.dart';
import '../utils/today_capture_records.dart';
import '../services/capture_draft_storage_service.dart';
import '../services/saved_capture_ids_storage_service.dart';
import '../services/pending_sync_queue_service.dart';
import '../services/personal_session_archive_service.dart';
import '../services/record_local_storage_service.dart';
import '../core/permissions/record_visibility.dart';
import 'domain/capture_form_scope.dart';
import 'domain/cloud_sync_scope.dart';
import 'domain/records_scope.dart';

class AppState extends ChangeNotifier {
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static bool _supportsCloudSync() {
    if (_isRunningInWidgetTest()) return false;
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.windows;
  }

  static bool _isRunningInWidgetTest() {
    return WidgetsBinding.instance.runtimeType
        .toString()
        .contains('TestWidgets');
  }

  factory AppState({
    FabricCatalogService? fabricCatalogService,
    LoteTramaCatalogService? loteTramaCatalogService,
    RecordImportService? recordImportService,
    ReportStorageService? reportStorageService,
    ReportExportService? reportExportService,
    RecordExportCoordinator? recordExportCoordinator,
    CloudSyncPort? cloudSyncService,
  }) {
    final syncService =
        cloudSyncService ?? (_supportsCloudSync() ? CloudSyncService() : null);

    return AppState._(
      initialCloudService: syncService,
      fabricCatalogService: fabricCatalogService ?? FabricCatalogService(),
      loteTramaCatalogService:
          loteTramaCatalogService ?? LoteTramaCatalogService(),
      recordImportService: recordImportService ?? RecordImportService(),
      reportStorageService:
          reportStorageService ?? ReportStorageService(cloudSync: syncService),
      reportExportService: reportExportService ?? ReportExportService(),
      recordExportCoordinator: recordExportCoordinator,
    );
  }

  AppState._({
    CloudSyncPort? initialCloudService,
    required this.fabricCatalogService,
    required this.loteTramaCatalogService,
    required this.recordImportService,
    required this.reportStorageService,
    required this.reportExportService,
    RecordExportCoordinator? recordExportCoordinator,
  }) : recordExportCoordinator = recordExportCoordinator ??
            RecordExportCoordinator(exportService: reportExportService) {
    _cloud = CloudSyncScope(
      service: initialCloudService,
      host: CloudSyncHost(
        getAuthRole: () => authRole,
        getAuthRoleCode: () => authRoleCode,
        loadLocalRecords: () => recordsScope.loadFromPreferences(),
        loadLocalFabrics: () => fabricCatalogService.loadFabrics(),
        applyRecordsPage: (page) {
          // Ignora actualizaciones remotas tras cambio de cuenta.
          if (_authUid == null) return;
          if (!_isAuthContextValid(_authGeneration, _authUid)) return;
          if (recordsScope.remoteFiltersActive &&
              recordsScope.usesRemoteFilters) {
            recordsScope.applyPageResult(
              page.records,
              hasMore: page.hasMore,
            );
          } else {
            recordsScope.mergePageResult(
              page.records,
              hasMore: page.hasMore,
            );
          }
        },
        applyFabrics: (data) {
          if (!_isAuthContextValid(_authGeneration, _authUid)) return;
          fabrics = data;
        },
        syncFabricSelection: () =>
            _syncFabricSelection(allowAutoSelect: _autoFillCaptureDefaults),
        cacheRecords: (data) async {
          if (!_isAuthContextValid(_authGeneration, _authUid)) return;
          await _mergeRecordsLocally(data);
        },
        cacheFabrics: _cacheFabricsLocally,
        migrateReports: () =>
            reportStorageService.migrateLocalReportsIfNeeded(),
        refreshUserRoleAndConfig: _refreshUserRoleAndConfig,
        getActiveFilters: () => recordsScope.filters,
        getQueryLimit: () => recordsScope.queryLimit,
        setRemoteFiltersActive: (active) =>
            recordsScope.remoteFiltersActive = active,
        onStateChanged: notifyListeners,
        reportStorageService: reportStorageService,
      ),
    );
  }

  late final CloudSyncScope _cloud;

  CloudSyncPort? get cloudSyncService => _cloud.service;
  CloudSyncCoordinator? get cloudSyncCoordinator => _cloud.coordinator;
  bool get cloudSyncEnabled => _cloud.enabled;
  set cloudSyncEnabled(bool value) => _cloud.enabled = value;
  String? get cloudSyncError => _cloud.error;
  set cloudSyncError(String? value) => _cloud.error = value;
  SyncPhase get syncPhase => _cloud.syncPhase;
  bool get hasMoreRecords => recordsScope.hasMoreFromCloud;
  bool get isLoadingMoreRecords => recordsScope.isLoadingMore;
  final LoteTramaCatalogService loteTramaCatalogService;
  final RecordImportService recordImportService;
  final ReportStorageService reportStorageService;
  final FabricCatalogService fabricCatalogService;
  final ReportExportService reportExportService;
  final RecordExportCoordinator recordExportCoordinator;
  String? _authUid;
  String? _authUsername;
  AppUserRole? _authAppRole;
  String? _authRoleCode;

  /// Generación de autenticación: se incrementa al cambiar de cuenta o cerrar sesión.
  /// Evita aplicar respuestas asíncronas tardías de la cuenta anterior.
  int _authGeneration = 0;
  bool _disposed = false;

  /// Sesión de captura activa del usuario autenticado (lista/contadores de Capturar).
  String? _activeCaptureSessionId;

  /// IDs de registros de la sesión actual ya incluidos en un informe Guardar.
  final Set<String> _savedCaptureRecordIds = <String>{};

  /// Si es true, se pueden rellenar tela/lote por defecto al cargar preferencias.
  /// Se desactiva al iniciar una sesión nueva vacía.
  bool _autoFillCaptureDefaults = true;

  /// Bloqueo contra doble pulsación en “Guardar y crear nueva sesión”.
  bool _sessionTransitionBusy = false;

  /// Informe / archivo personal ya persistido (reintento sin duplicar).
  String? _pendingClosedSessionReportId;
  String? _pendingClosedPersonalArchiveId;

  String? get authUsername => _authUsername;
  String? get authUid => _authUid;
  String? get activeCaptureSessionId => _activeCaptureSessionId;
  bool get isSessionTransitionBusy => _sessionTransitionBusy;
  int get authGeneration => _authGeneration;

  final CaptureFormScope capture = CaptureFormScope();
  final RecordsScope recordsScope = RecordsScope();

  TextEditingController get telarController => capture.telarController;
  TextEditingController get nepsController => capture.nepsController;
  TextEditingController get lotePrefixController =>
      capture.lotePrefixController;
  TextEditingController get loteSuffixController =>
      capture.loteSuffixController;
  TextEditingController get loteFullController => capture.loteFullController;
  TextEditingController get manualTelaController =>
      capture.manualTelaController;
  TextEditingController get turnoController => capture.turnoController;
  TextEditingController get operarioController => capture.operarioController;
  TextEditingController get lineaProduccionController =>
      capture.lineaProduccionController;
  TextEditingController get observacionController =>
      capture.observacionController;
  TextEditingController get accionInmediataController =>
      capture.accionInmediataController;

  bool get loteFullEntryMode => capture.loteFullEntryMode;
  set loteFullEntryMode(bool value) => capture.loteFullEntryMode = value;

  RecordFilters get filters => recordsScope.filters;
  int get filterPanelKey => recordsScope.filterPanelKey;
  set filterPanelKey(int value) => recordsScope.filterPanelKey = value;

  /// Token de contexto de filtros para limpiar selección en Registros.
  int get recordsSelectionContextVersion =>
      recordsScope.recordsSelectionContextVersion;

  List<NepRecord> get records => recordsScope.items;
  set records(List<NepRecord> value) {
    recordsScope.items = value;
    recordsScope.notifyListeners();
  }

  /// Registros de la sesión de captura activa del usuario autenticado.
  List<NepRecord> get captureSessionRecords {
    final sid = _activeCaptureSessionId;
    if (sid == null || sid.isEmpty) return const [];
    final uid = _authUid;
    return records.where((record) {
      if (record.captureSessionId != sid) return false;
      if (uid == null || uid.isEmpty) return true;
      final owner = record.createdByUid?.trim();
      if (owner != null && owner.isNotEmpty && owner != uid) return false;
      return true;
    }).toList(growable: false);
  }

  /// IDs de la sesión actual ya guardados en un informe (Captura → Guardar).
  Set<String> get savedCaptureRecordIds =>
      Set<String>.unmodifiable(_savedCaptureRecordIds);

  /// Registros de la sesión aún no incluidos en un Guardar exitoso.
  List<NepRecord> get pendingCaptureSessionRecords {
    final saved = _savedCaptureRecordIds;
    return captureSessionRecords
        .where((record) => !saved.contains(record.id))
        .toList(growable: false);
  }

  /// Último pendiente de la sesión (por `createdAt`), o null.
  NepRecord? get latestPendingCaptureSessionRecord {
    final pending = pendingCaptureSessionRecords;
    if (pending.isEmpty) return null;
    return pending.reduce(
      (a, b) => a.createdAt.isAfter(b.createdAt) ? a : b,
    );
  }

  /// Registros creados hoy (día local) por el usuario autenticado.
  ///
  /// Fuente exclusiva de Captura → Compartir. Excluye otros días, otros
  /// usuarios y ownership ambiguo.
  List<NepRecord> get todayCaptureRecords => filterTodayCaptureRecords(
        records: records,
        authUid: _authUid,
      );

  /// Último registro de [todayCaptureRecords] (por `createdAt`), o null.
  NepRecord? get latestTodayCaptureRecord => resolveLatestTodayCaptureRecord(
        records: records,
        authUid: _authUid,
      );

  /// Resuelve qué lista se exporta: selección explícita o [visibleRecords].
  List<NepRecord> resolveExportRecords(List<NepRecord>? sourceRecords) =>
      sourceRecords ?? visibleRecords;

  /// Hay texto o selecciones pendientes en el formulario de captura.
  bool get hasCaptureFormDraft {
    if (telarController.text.trim().isNotEmpty) return true;
    if (nepsController.text.trim().isNotEmpty) return true;
    if (manualTelaController.text.trim().isNotEmpty) return true;
    if (loteFullController.text.trim().isNotEmpty) return true;
    if (lotePrefixController.text.trim().isNotEmpty) return true;
    if (loteSuffixController.text.trim().isNotEmpty) return true;
    if (turnoController.text.trim().isNotEmpty) return true;
    if (operarioController.text.trim().isNotEmpty) return true;
    if (lineaProduccionController.text.trim().isNotEmpty) return true;
    if (observacionController.text.trim().isNotEmpty) return true;
    if (accionInmediataController.text.trim().isNotEmpty) return true;
    if (selectedFabric != null && selectedFabric!.trim().isNotEmpty) {
      return true;
    }
    return false;
  }

  /// Hay trabajo de sesión que conviene guardar antes de vaciar.
  bool get hasCaptureSessionWork =>
      captureSessionRecords.isNotEmpty || hasCaptureFormDraft;

  List<String> fabrics = [];
  List<String> loteCatalog = [];
  String? selectedFabric;
  bool useManualFabric = false;
  bool isLoading = true;
  bool isExporting = false;
  String? bootstrapError;
  int navigationIndex = 0;

  /// Incrementa tras cada captura exitosa para forzar rebuild de campos telar/neps.
  int captureFormEpoch = 0;
  AppNavId? pendingNavTarget;
  Set<ExportColumn> exportColumns = ExportColumn.defaultSelection();
  PdfReportStyle pdfReportStyle = PdfReportStyle.completo;

  List<NepRecord> get visibleRecords => recordsScope.visible;

  /// Subconjunto ligero para el panel principal.
  List<NepRecord> get dashboardRecords => recordsScope.dashboardRecords;

  int get criticalAlertsCount =>
      alertService.detectCriticalRecords(records).length;

  AppUserRole get authRole => _authAppRole ?? AppUserRole.operario;

  String get authRoleCode => _authRoleCode ?? _authAppRole?.code ?? '';

  bool get canCapture => _hasPermission(Permission.captureRecords);

  bool get canImportRecords =>
      permissionsService.canImportRecordsForCode(authRoleCode);

  bool get canDeleteRecords => _hasPermission(Permission.deleteRecords);

  bool get canClearAllRecords => _hasPermission(Permission.clearAllRecords);

  bool get canApplyCorrectiveAction =>
      _hasPermission(Permission.applyCorrectiveAction);

  bool get canManageFabrics => _hasPermission(Permission.manageFabrics);

  bool get canManageReports => _hasPermission(Permission.manageReports);

  bool get canExportReports => _hasPermission(Permission.exportReports);

  bool get canEditRecords => _hasPermission(Permission.editRecords);

  bool get canEditAlertConfig => _hasPermission(Permission.editAlertConfig);

  bool get canManageSettings => _hasPermission(Permission.manageSettings);

  bool get isReadOnlyUser => permissionsService.isReadOnlyCode(authRoleCode);

  bool _hasPermission(Permission permission) {
    return RolePermissions.hasCode(authRoleCode, permission);
  }

  void applyAuthProfile(AppUser user) {
    final previousUid = _authUid;
    final switched = previousUid != null && previousUid != user.uid;
    final firstLogin = previousUid == null;

    final leavingUid = previousUid;
    if (switched && leavingUid != null) {
      // Persiste borrador del usuario saliente en SU espacio (no en el nuevo).
      unawaited(_persistCaptureDraftForUid(leavingUid));
    }

    _authUid = user.uid;
    _authUsername =
        user.username.isNotEmpty ? user.username : user.effectiveDisplayName;
    _authAppRole = AppUserRole.tryParse(user.roleCode) ?? user.role;
    _authRoleCode = user.roleCode;

    if (switched || firstLogin) {
      _authGeneration++;
      final generation = _authGeneration;
      if (switched) {
        // Retira de la UI los datos del usuario anterior; no los borra del disco.
        recordsScope.clear();
        clearCaptureFields(preserveCatalogDefaults: false);
        _pendingClosedSessionReportId = null;
        _pendingClosedPersonalArchiveId = null;
        _activeCaptureSessionId = null;
        _savedCaptureRecordIds.clear();
        // Vista temporal de informe: no sobrevive al cambio de UID.
        viewingSavedReport = null;
      }
      unawaited(_bootstrapUserLocalState(user.uid, generation));
    }
    notifyListeners();
  }

  /// Cierra suscripciones y estado de nube al cerrar sesión.
  void resetCloudSession() {
    final previousUid = _authUid;
    final previousGeneration = _authGeneration;
    _authGeneration++;
    if (previousUid != null) {
      unawaited(_persistCaptureDraftForUid(previousUid));
    }
    _cloud.resetSession();
    _authUid = null;
    _authUsername = null;
    _authAppRole = null;
    _authRoleCode = null;
    _activeCaptureSessionId = null;
    _pendingClosedSessionReportId = null;
    _pendingClosedPersonalArchiveId = null;
    _savedCaptureRecordIds.clear();
    viewingSavedReport = null;
    recordsScope.clear();
    clearCaptureFields(preserveCatalogDefaults: false);
    unawaited(recordLocalStorageService.bindUser(null));
    // Descarta cualquier resultado de la generación anterior.
    assert(previousGeneration < _authGeneration);
    notifyListeners();
  }

  bool _isAuthContextValid(int generation, String? uid) {
    if (_disposed) return false;
    if (generation != _authGeneration) return false;
    if (uid == null || uid.isEmpty) return _authUid == null;
    return _authUid == uid;
  }

  Future<void> _bootstrapUserLocalState(String uid, int generation) async {
    await recordsScope.bindUser(uid);
    if (!_isAuthContextValid(generation, uid)) return;

    final localRecords = await recordsScope.loadFromPreferences();
    if (!_isAuthContextValid(generation, uid)) return;
    records = localRecords;

    await _restoreOrCreateCaptureSession(uid);
    if (!_isAuthContextValid(generation, uid)) return;

    await _restoreCaptureDraftForUid(uid);
    if (!_isAuthContextValid(generation, uid)) return;

    unawaited(_drainPendingSyncIfCurrent(uid, generation));
    _notifyIfActive();
  }

  /// Asegura que exista sessionId activo (útil tras login o en tests).
  Future<void> ensureCaptureSessionReady() async {
    final uid = _authUid;
    final generation = _authGeneration;
    if (uid == null || uid.isEmpty) return;
    await recordsScope.bindUser(uid);
    if (!_isAuthContextValid(generation, uid)) return;
    await _restoreOrCreateCaptureSession(uid);
    _notifyIfActive();
  }

  Future<void> _restoreOrCreateCaptureSession(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final key = activeCaptureSessionKeyForUid(uid);
    var sessionId = prefs.getString(key)?.trim();
    if (sessionId == null || sessionId.isEmpty) {
      sessionId = generateStableId(prefix: 'ses');
      await prefs.setString(key, sessionId);
      // No adopta registros legacy ambiguos ni ajenos.
    }
    _activeCaptureSessionId = sessionId;
    await _loadSavedCaptureIdsForSession(uid, sessionId);
  }

  Future<void> _loadSavedCaptureIdsForSession(
    String uid,
    String sessionId,
  ) async {
    final loaded = await savedCaptureIdsStorageService.load(
      uid: uid,
      captureSessionId: sessionId,
    );
    _savedCaptureRecordIds
      ..clear()
      ..addAll(loaded);
  }

  Future<void> _persistActiveCaptureSessionId(
    String uid,
    String sessionId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(activeCaptureSessionKeyForUid(uid), sessionId);
  }

  Future<void> _persistCaptureDraftForUid(String uid) async {
    final sessionId = _activeCaptureSessionId ?? '';
    final draft = CaptureDraftSnapshot(
      ownerUid: uid,
      captureSessionId: sessionId,
      updatedAt: DateTime.now(),
      telar: telarController.text,
      neps: nepsController.text,
      manualTela: manualTelaController.text,
      selectedFabric: selectedFabric,
      useManualFabric: useManualFabric,
      loteFull: loteFullController.text,
      lotePrefix: lotePrefixController.text,
      loteSuffix: loteSuffixController.text,
      loteFullEntryMode: loteFullEntryMode,
      turno: turnoController.text,
      operario: operarioController.text,
      lineaProduccion: lineaProduccionController.text,
      observacion: observacionController.text,
      accionInmediata: accionInmediataController.text,
    );
    await captureDraftStorageService.save(draft);
  }

  Future<void> _restoreCaptureDraftForUid(String uid) async {
    final draft = await captureDraftStorageService.loadForUid(uid);
    if (draft == null) return;
    if (draft.ownerUid != uid) return;
    if (_activeCaptureSessionId != null &&
        draft.captureSessionId.isNotEmpty &&
        draft.captureSessionId != _activeCaptureSessionId) {
      // Borrador de otra sesión: no rellenar la sesión activa vacía.
      return;
    }

    _suppressLotePersist = true;
    try {
      telarController.text = draft.telar;
      nepsController.text = draft.neps;
      manualTelaController.text = draft.manualTela;
      selectedFabric = draft.selectedFabric;
      useManualFabric = draft.useManualFabric;
      loteFullController.text = draft.loteFull;
      lotePrefixController.text = draft.lotePrefix;
      loteSuffixController.text = draft.loteSuffix;
      loteFullEntryMode = draft.loteFullEntryMode;
      turnoController.text = draft.turno;
      operarioController.text = draft.operario;
      lineaProduccionController.text = draft.lineaProduccion;
      observacionController.text = draft.observacion;
      accionInmediataController.text = draft.accionInmediata;
      _autoFillCaptureDefaults = false;
    } finally {
      _suppressLotePersist = false;
    }
  }

  Future<void> _drainPendingSyncIfCurrent(String uid, int generation) async {
    if (cloudSyncCoordinator == null) return;
    if (!await _ensureCloudReady()) return;
    if (!_isAuthContextValid(generation, uid)) return;

    final pending = await pendingSyncQueueService.loadForUid(uid);
    if (pending.isEmpty) return;
    if (!_isAuthContextValid(generation, uid)) return;

    final remaining = <PendingSyncOp>[];
    for (var i = 0; i < pending.length; i++) {
      if (!_isAuthContextValid(generation, uid)) {
        remaining.addAll(pending.sublist(i));
        break;
      }
      final op = pending[i];
      try {
        switch (op.type) {
          case PendingSyncOpType.upsert:
            if (op.ownerUid != uid) continue;
            final record = op.record;
            if (record == null) continue;
            final owner = verifiedRecordOwnerUid(record);
            if (owner != null && owner != uid) continue;
            await cloudSyncCoordinator!.upsertRecord(record);
          case PendingSyncOpType.delete:
            final recordId = op.recordId;
            if (recordId == null || recordId.isEmpty) continue;
            final deleteOwner = op.ownerUid.trim().isEmpty ? null : op.ownerUid;
            await cloudSyncCoordinator!.deleteRecord(
              recordId,
              ownerUid: deleteOwner,
            );
        }
      } catch (_) {
        remaining.add(op);
      }
    }

    if (!_isAuthContextValid(generation, uid)) return;
    await pendingSyncQueueService.replaceAll(uid, remaining);
    if (remaining.isEmpty) {
      cloudSyncEnabled = true;
      _notifyIfActive();
    }
  }

  bool _requirePermission(bool allowed, String action) {
    if (allowed) return true;
    showMessage(permissionsService.deniedMessage(action));
    return false;
  }

  int get warningAlertsCount =>
      alertService.detectWarningRecords(records).length;

  double get totalNeps =>
      visibleRecords.fold(0, (sum, item) => sum + item.neps);

  double get totalMts => visibleRecords.fold(
        0,
        (sum, item) => sum + calculateMts(item.neps),
      );

  double get averageMts =>
      visibleRecords.isEmpty ? 0 : totalMts / visibleRecords.length;

  double get averageNeps =>
      visibleRecords.isEmpty ? 0 : totalNeps / visibleRecords.length;

  double get previewValue {
    if (nepsController.text.trim().isEmpty) return 0;
    return calculateMts(parseNumber(nepsController.text));
  }

  Future<void> initialize({Uri? launchUri}) async {
    capture.onLoteFullPersist = () {
      if (_suppressLotePersist) return;
      unawaited(_saveLoteFull());
    };
    capture.attachListeners(notifyListeners);
    recordsScope.addListener(notifyListeners);
    capture.addListener(notifyListeners);

    await Future<void>.delayed(Duration.zero);

    await Future.wait([
      alertConfigService.load(),
      notificationPreferencesService.load(),
    ]);
    alertService.updateConfig(alertConfigService.config);

    await loadData();
    if (launchUri != null) {
      await applyLaunchParameters(launchUri);
    }
  }

  /// Aplica parámetros de URL para Atajos de iOS / Siri Shortcuts.
  Future<void> applyLaunchParameters(Uri uri) async {
    final params = uri.queryParameters;
    if (params.isEmpty) return;

    final screenId = SiriShortcutService.resolveScreenId(
      SiriShortcutService.readParam(params, 'pantalla') ??
          SiriShortcutService.readParam(params, 'screen'),
    );
    if (screenId != null) {
      requestNavigation(screenId);
    }

    final telar = SiriShortcutService.readParam(params, 'telar');
    final neps = SiriShortcutService.readParam(params, 'neps');
    final lote = SiriShortcutService.readParam(params, 'lote') ??
        SiriShortcutService.readParam(params, 'lote_trama');
    final tela = SiriShortcutService.readParam(params, 'tela');

    if (telar != null) telarController.text = telar;
    if (neps != null) nepsController.text = neps;
    if (lote != null) {
      final parts = LoteTramaHelper.split(
        lote,
        fallbackPrefix: lotePrefixController.text,
      );
      lotePrefixController.text = parts.prefix;
      loteSuffixController.text = parts.suffix;
      loteFullController.text = parts.full;
      loteFullEntryMode =
          parts.suffix.isNotEmpty && lote.contains(parts.prefix);
    }

    if (tela != null) {
      if (fabrics.contains(tela)) {
        selectedFabric = tela;
        useManualFabric = false;
      } else {
        useManualFabric = true;
        manualTelaController.text = tela;
      }
    }

    notifyListeners();

    if (SiriShortcutService.shouldAutoAdd(params)) {
      await addRecord();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _cloud.dispose();
    capture.detachListeners(notifyListeners);
    recordsScope.removeListener(notifyListeners);
    capture.removeListener(notifyListeners);
    capture.dispose();
    super.dispose();
  }

  void _notifyIfActive() {
    if (_disposed) return;
    notifyListeners();
  }

  void setNavigationIndex(int index) {
    navigationIndex = index;
    pendingNavTarget = null;
    notifyListeners();
  }

  /// Solicita navegación por id (resuelto en [AppShell] según permisos).
  void requestNavigation(AppNavId id) {
    pendingNavTarget = id;
    notifyListeners();
  }

  /// Resuelve [pendingNavTarget] al índice visible del usuario.
  void applyPendingNavigation(AppUser? user) {
    final target = pendingNavTarget;
    if (target == null) return;
    pendingNavTarget = null;
    final index = AppNavigation.indexOf(user, target);
    if (index != null) {
      navigationIndex = index;
      notifyListeners();
    }
  }

  /// Navega a registros aplicando filtros relacionados con una alerta.
  void navigateToRecordsFiltered({
    String? telar,
    String? tela,
    String? loteTrama,
    DateQuickRange? quickRange,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) {
    recordsScope.applyNavigationFilters(
      telar: telar,
      tela: tela,
      loteTrama: loteTrama,
      quickRange: quickRange,
      dateFrom: dateFrom,
      dateTo: dateTo,
    );
    requestNavigation(AppNavId.records);
  }

  Future<void> loadData() async {
    isLoading = true;
    bootstrapError = null;
    _cloud.syncPhase = SyncPhase.loadingLocal;
    notifyListeners();

    try {
      await _loadLocalData();
      _cloud.syncPhase =
          cloudSyncService != null ? SyncPhase.syncingCloud : SyncPhase.offline;
    } catch (error, stackTrace) {
      bootstrapError =
          'No se pudieron cargar los datos guardados. Verifique el almacenamiento local.';
      ErrorHandler.log(error, stackTrace, 'loadLocalData');
      _cloud.syncPhase = SyncPhase.offline;
    }

    isLoading = false;
    notifyListeners();

    if (cloudSyncService != null) {
      unawaited(_cloud.connectWhenAuthenticated());
    }
  }

  Future<void> reloadData() => loadData();

  Future<List<SavedReport>> refreshReports() async {
    final result = await refreshReportsResult();
    if (result.reports.isEmpty && result.cloudError != null) {
      throw StateError(result.cloudError!);
    }
    return result.reports;
  }

  /// Carga informes con resultado parcial (no oculta fallos de fuente).
  Future<ReportsLoadResult> refreshReportsResult() async {
    final generation = _authGeneration;
    final uid = _authUid;
    await _cloud.bootstrapReportsIfNeeded();
    if (!_isAuthContextValid(generation, uid)) {
      return const ReportsLoadResult(reports: [], isPartial: true);
    }
    return reportStorageService.loadReportsResult(
      viewerUid: uid,
      canViewTeamReports: canManageReports,
    );
  }

  /// Registros unificados (vivos + archivo personal + informes autorizados).
  Future<List<NepRecord>> loadAnalyticsRecords() async {
    final source = await loadAnalyticsRecordsSource();
    return source.records;
  }

  /// Historial para gráficas: sesiones personales + informes autorizados.
  Future<AnalyticsHistoryBundle> loadAnalyticsHistoryBundle() async {
    final generation = _authGeneration;
    final uid = _authUid;
    final reportsResult = await refreshReportsResult();
    if (!_isAuthContextValid(generation, uid)) {
      return const AnalyticsHistoryBundle(
        historyReports: [],
        isPartial: true,
        partialMessage: 'La sesión cambió durante la carga.',
      );
    }

    final personalReports = <SavedReport>[];
    if (uid != null && uid.isNotEmpty) {
      final archives = await personalSessionArchiveService.loadForUid(uid);
      if (!_isAuthContextValid(generation, uid)) {
        return const AnalyticsHistoryBundle(
          historyReports: [],
          isPartial: true,
          partialMessage: 'La sesión cambió durante la carga.',
        );
      }
      for (final archive in archives) {
        personalReports.add(
          SavedReport(
            id: archive.id,
            name: archive.name.isEmpty
                ? 'Sesión ${archive.captureSessionId}'
                : archive.name,
            createdAt: archive.savedAt,
            records: archive.records,
            createdByUid: archive.ownerUid,
          ),
        );
      }
    }

    return AnalyticsHistoryBundle(
      historyReports: [...personalReports, ...reportsResult.reports],
      isPartial: reportsResult.isPartial,
      partialMessage: reportsResult.cloudError,
      skippedReportCount: reportsResult.skippedCount,
    );
  }

  Future<AnalyticsRecordsSource> loadAnalyticsRecordsSource() async {
    final bundle = await loadAnalyticsHistoryBundle();
    return buildAnalyticsRecordsSource(
      liveRecords: records,
      savedReports: bundle.historyReports,
      isPartial: bundle.isPartial,
      partialMessage: bundle.partialMessage,
      skippedReportCount: bundle.skippedReportCount,
    );
  }

  /// Registros del periodo configurado (consulta nube por rango + local).
  Future<List<NepRecord>> loadRecordsForReportPeriod(
    ReportConfiguration config,
  ) async {
    final cloudReady = cloudSyncService != null && await _ensureCloudReady();
    return reportRecordsLoader.load(
      config: config,
      inMemoryRecords: records,
      loadAllLocal: recordsScope.loadAllLocal,
      cloud: cloudSyncService,
      viewerRole: authRole,
      cloudReady: cloudReady,
    );
  }

  Future<void> enableCloudSyncIfAvailable() => _cloud.enableIfAvailable();

  Future<void> _loadLocalData() async {
    final uid = _authUid;
    final generation = _authGeneration;

    if (uid != null && uid.isNotEmpty) {
      await recordsScope.bindUser(uid);
      if (!_isAuthContextValid(generation, uid)) return;
    } else {
      // Sin sesión: no cargar el store legacy compartido en la UI.
      records = [];
    }

    final loaded = await Future.wait([
      uid == null || uid.isEmpty
          ? Future<List<NepRecord>>.value(const [])
          : recordsScope.loadFromPreferences(),
      fabricCatalogService.loadFabrics(),
      loteTramaCatalogService.loadCatalog(),
    ]);

    if (uid != null && !_isAuthContextValid(generation, uid)) return;

    records = loaded[0] as List<NepRecord>;
    fabrics = loaded[1] as List<String>;
    loteCatalog = loaded[2] as List<String>;

    if (uid != null && uid.isNotEmpty) {
      await _restoreOrCreateCaptureSession(uid);
      if (!_isAuthContextValid(generation, uid)) return;
    }

    _suppressLotePersist = true;
    try {
      // Preferencias de lote/tela del formulario son personales por UID.
      // Tras nueva sesión (_autoFillCaptureDefaults=false) no se restauran.
      if (_autoFillCaptureDefaults && uid != null && uid.isNotEmpty) {
        await _loadLotePreferences();
      }
      _syncFabricSelection(allowAutoSelect: false);
    } finally {
      _suppressLotePersist = false;
    }
  }

  void _ensureDefaultLotePreview() {
    if (!_autoFillCaptureDefaults) return;
    if (loteFullController.text.trim().isNotEmpty) return;
    if (loteCatalog.isEmpty) return;
    loteFullController.text = loteCatalog.first;
    final parts = LoteTramaHelper.split(
      loteCatalog.first,
      fallbackPrefix: lotePrefixController.text,
    );
    lotePrefixController.text = parts.prefix;
    loteSuffixController.text = parts.suffix;
  }

  Future<void> _loadLotePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = _authUid;
    if (uid != null && uid.isNotEmpty) {
      final raw = prefs.getString(lotePrefsKeyForUid(uid));
      if (raw != null && raw.isNotEmpty) {
        try {
          final Map<String, dynamic> data =
              Map<String, dynamic>.from(jsonDecode(raw) as Map);
          final savedPrefix = data['prefix']?.toString();
          if (savedPrefix != null && savedPrefix.trim().isNotEmpty) {
            lotePrefixController.text =
                LoteTramaHelper.normalizePrefix(savedPrefix);
          }
          loteFullEntryMode = data['fullEntry'] == true;
          final savedFull = data['full']?.toString();
          if (savedFull != null && savedFull.trim().isNotEmpty) {
            final full = savedFull.trim();
            loteFullController.text = full;
            final parts = LoteTramaHelper.split(
              full,
              fallbackPrefix: lotePrefixController.text,
            );
            lotePrefixController.text = parts.prefix;
            loteSuffixController.text = parts.suffix;
          }
          return;
        } catch (_) {
          // Continúa con legacy global solo para migración de lectura.
        }
      }
    }

    final savedPrefix = prefs.getString(loteTramaPrefixStorageKey);
    if (savedPrefix != null && savedPrefix.trim().isNotEmpty) {
      lotePrefixController.text = LoteTramaHelper.normalizePrefix(savedPrefix);
    }
    loteFullEntryMode = prefs.getBool(loteTramaFullEntryStorageKey) ?? false;

    final savedFull = prefs.getString(loteTramaFullStorageKey);
    if (savedFull != null && savedFull.trim().isNotEmpty) {
      final full = savedFull.trim();
      loteFullController.text = full;
      final parts = LoteTramaHelper.split(
        full,
        fallbackPrefix: lotePrefixController.text,
      );
      lotePrefixController.text = parts.prefix;
      loteSuffixController.text = parts.suffix;
    }
  }

  Future<void> _saveLotePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = LoteTramaHelper.normalizePrefix(lotePrefixController.text);
    final uid = _authUid;
    if (uid != null && uid.isNotEmpty) {
      final prefix = LoteTramaHelper.normalizePrefix(lotePrefixController.text);
      final full = loteFullController.text.trim();
      await prefs.setString(
        lotePrefsKeyForUid(uid),
        jsonEncode({
          'prefix': prefix,
          'fullEntry': loteFullEntryMode,
          'full': full,
        }),
      );
      return;
    }
    await prefs.setString(loteTramaPrefixStorageKey, prefix);
    await prefs.setBool(loteTramaFullEntryStorageKey, loteFullEntryMode);
  }

  /// Evita persistir el lote mientras se restauran/derivan valores en la carga.
  bool _suppressLotePersist = false;

  Future<void> _saveLoteFull() async {
    final prefs = await SharedPreferences.getInstance();
    final full = loteFullController.text.trim();
    final uid = _authUid;
    if (uid != null && uid.isNotEmpty) {
      final prefix = LoteTramaHelper.normalizePrefix(lotePrefixController.text);
      await prefs.setString(
        lotePrefsKeyForUid(uid),
        jsonEncode({
          'prefix': prefix,
          'fullEntry': loteFullEntryMode,
          'full': full,
        }),
      );
      return;
    }
    await prefs.setString(loteTramaFullStorageKey, full);
  }

  void setLoteFullEntryMode(bool value) {
    if (loteFullEntryMode == value) return;
    loteFullEntryMode = value;
    unawaited(_saveLotePreferences());
    notifyListeners();
  }

  void persistLotePrefix() {
    unawaited(_saveLotePreferences());
    notifyListeners();
  }

  String? resolveLoteTramaForSave() {
    final full = LoteTramaHelper.normalizeFull(loteFullController.text);
    if (LoteTramaHelper.isValidFull(full)) return full;

    if (LoteTramaHelper.isValidParts(
      prefix: lotePrefixController.text,
      suffix: loteSuffixController.text,
    )) {
      return LoteTramaHelper.buildFull(
        prefix: lotePrefixController.text,
        suffix: loteSuffixController.text,
      );
    }

    return null;
  }

  Future<void> addLoteTramaToCatalog(String lote) async {
    loteCatalog = await loteTramaCatalogService.addLote(loteCatalog, lote);
    notifyListeners();
  }

  Future<void> removeLoteTramaFromCatalog(String lote) async {
    loteCatalog = await loteTramaCatalogService.removeLote(loteCatalog, lote);
    final current = LoteTramaHelper.normalizeFull(loteFullController.text);
    if (current.toUpperCase() == lote.trim().toUpperCase()) {
      loteFullController.clear();
    }
    notifyListeners();
  }

  Future<void> _cacheRecordsLocally(List<NepRecord> data) async {
    recordsScope.items = data;
    await recordsScope.persistLocally();
    recordsScope.notifyListeners();
    notifyListeners();
  }

  Future<void> _mergeRecordsLocally(List<NepRecord> data) async {
    if (data.isEmpty) return;
    await recordsScope.persistMerged(data);
  }

  Future<void> _refreshUserRoleAndConfig() async {
    final coordinator = cloudSyncCoordinator;
    if (coordinator == null) return;

    try {
      _authAppRole ??= await coordinator.fetchUserRole();
      final remoteConfig = await coordinator.fetchAlertConfig();
      if (remoteConfig != null) {
        alertConfigService.applyFromFirestore(remoteConfig);
        alertService.updateConfig(alertConfigService.config);
      }
      notifyListeners();
    } catch (error, stackTrace) {
      ErrorHandler.log(error, stackTrace, 'refreshUserRoleAndConfig');
    }
  }

  Future<void> initializeNotifications() async {
    await notificationService.initialize(
      onTokenRegistered: (token) async {
        await _cloud.registerFcmToken(token);
      },
    );
  }

  Future<bool> _ensureCloudReady() => _cloud.ensureReady();

  Future<void> reconnectCloudIfNeeded() => _cloud.ensureConnected();

  Future<void> ensureCloudConnected() async {
    await _cloud.ensureConnected();
    final uid = _authUid;
    final generation = _authGeneration;
    if (uid != null && uid.isNotEmpty) {
      unawaited(_drainPendingSyncIfCurrent(uid, generation));
    }
  }

  void _syncFabricSelection({bool allowAutoSelect = true}) {
    if (fabrics.isEmpty) {
      useManualFabric = true;
      return;
    }

    if (useManualFabric) return;

    if (selectedFabric == null || !fabrics.contains(selectedFabric)) {
      if (allowAutoSelect && _autoFillCaptureDefaults) {
        selectedFabric = fabrics.first;
      } else {
        selectedFabric = null;
      }
    }
  }

  Future<void> _cacheFabricsLocally(List<String> data) async {
    await fabricCatalogService.saveFabrics(data);
  }

  String? resolveSelectedTela() {
    if (useManualFabric) {
      final manual = manualTelaController.text.trim();
      return manual.isEmpty ? null : manual;
    }
    return selectedFabric;
  }

  Future<void> saveFabrics(List<String> updated) async {
    if (!_requirePermission(
        canManageFabrics, 'administrar el catálogo de telas')) {
      return;
    }
    final normalized = fabricCatalogService.mergeFabrics([], updated);

    await fabricCatalogService.saveFabrics(normalized);
    fabrics = normalized;
    _syncFabricSelection();
    notifyListeners();

    if (cloudSyncService == null || !canManageFabrics) {
      showMessage('Catalogo de telas actualizado localmente.');
      return;
    }

    if (cloudSyncCoordinator != null && await _ensureCloudReady()) {
      try {
        final saved = await cloudSyncCoordinator!.saveFabrics(normalized);
        await _cacheFabricsLocally(saved);
        showMessage('Catalogo de telas guardado en Firebase.');
        return;
      } catch (error, stackTrace) {
        ErrorHandler.log(error, stackTrace, 'saveFabrics');
        if (error.toString().contains('permission-denied')) {
          cloudSyncError = null;
        }
      }
    }

    showMessage('Catalogo de telas actualizado localmente.');
  }

  Future<void> saveData() async {
    if (cloudSyncCoordinator != null && await _ensureCloudReady()) {
      try {
        await cloudSyncCoordinator!.replaceRecords(records);
        return;
      } catch (_) {
        cloudSyncEnabled = false;
      }
    }

    await _cacheRecordsLocally(records);
  }

  Future<void> _persistRecord(NepRecord record) async {
    final uid = _authUid;
    final generation = _authGeneration;
    if (uid == null || uid.isEmpty) {
      showMessage('Debe iniciar sesión para guardar registros.');
      return;
    }

    final verified = verifiedRecordOwnerUid(record);
    if (verified != null && verified != uid) {
      showMessage('No puede guardar registros de otro usuario.');
      return;
    }

    final stamped = record.createdByUid == null || record.createdByUid!.isEmpty
        ? record.copyWith(createdByUid: uid)
        : record;

    recordsScope.upsert(stamped);
    await recordsScope.persistRecord(stamped);
    if (!_isAuthContextValid(generation, uid)) return;
    notifyListeners();

    if (cloudSyncCoordinator != null && await _ensureCloudReady()) {
      if (!_isAuthContextValid(generation, uid)) return;
      try {
        await cloudSyncCoordinator!.upsertRecord(stamped);
        return;
      } catch (error, stackTrace) {
        cloudSyncEnabled = false;
        ErrorHandler.log(error, stackTrace, 'persistRecord');
        await pendingSyncQueueService.enqueueUpsert(uid, stamped);
        showMessage(
          'No se pudo sincronizar con Firebase. Registro guardado localmente.',
        );
      }
    } else if (cloudSyncCoordinator != null) {
      await pendingSyncQueueService.enqueueUpsert(uid, stamped);
    }
  }

  Future<void> _persistRecords(List<NepRecord> updatedRecords) async {
    final uid = _authUid;
    final generation = _authGeneration;
    if (uid == null || uid.isEmpty) {
      throw StateError('Sin UID autenticado para persistir registros.');
    }

    final stamped = <NepRecord>[];
    for (final record in updatedRecords) {
      final verified = verifiedRecordOwnerUid(record);
      if (verified != null && verified != uid) {
        continue;
      }
      stamped.add(
        record.createdByUid == null || record.createdByUid!.isEmpty
            ? record.copyWith(createdByUid: uid)
            : record,
      );
    }

    for (final record in stamped) {
      recordsScope.upsert(record);
    }
    await recordsScope.persistMerged(stamped);
    if (!_isAuthContextValid(generation, uid)) return;
    notifyListeners();

    if (cloudSyncCoordinator != null && await _ensureCloudReady()) {
      if (!_isAuthContextValid(generation, uid)) return;
      try {
        await cloudSyncCoordinator!.upsertRecords(stamped);
        return;
      } catch (_) {
        cloudSyncEnabled = false;
        for (final record in stamped) {
          await pendingSyncQueueService.enqueueUpsert(uid, record);
        }
      }
    } else if (cloudSyncCoordinator != null) {
      for (final record in stamped) {
        await pendingSyncQueueService.enqueueUpsert(uid, record);
      }
    }
  }

  /// Resultado de la última eliminación (útil en pruebas).
  @visibleForTesting
  RecordDeleteOutcome? lastDeleteOutcome;

  Future<void> _clearAllRecords() async {
    recordsScope.clear();
    await recordsScope.persistLocally();
    notifyListeners();

    if (cloudSyncCoordinator != null && await _ensureCloudReady()) {
      try {
        await cloudSyncCoordinator!.clearRecords();
      } catch (error, stackTrace) {
        cloudSyncEnabled = false;
        ErrorHandler.log(error, stackTrace, 'clearRecords');
        showMessage(
          'Tabla vaciada en el dispositivo, pero no se pudo limpiar Firebase.',
        );
      }
    }
  }

  double calculateMts(double neps) => neps / testLengthM;

  double parseNumber(String value) =>
      double.tryParse(value.replaceAll(',', '.')) ?? 0;

  String formatNumber(double value) {
    if (decimals == 0) return value.round().toString();
    return value.toStringAsFixed(decimals);
  }

  String formatDecimal(double value) {
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toStringAsFixed(3);
  }

  void clearFilters() {
    recordsScope.clearFilters();
    recordsScope.remoteFiltersActive = false;
    filterPanelKey = recordsScope.filterPanelKey;
    unawaited(_rebindRecordsIfCloudReady());
    notifyListeners();
  }

  Future<void> loadMoreRecords() async {
    await recordsScope.requestLoadMore();
    await _rebindRecordsIfCloudReady();
    notifyListeners();
  }

  Future<void> _rebindRecordsIfCloudReady() async {
    if (cloudSyncCoordinator == null || !cloudSyncEnabled) return;
    try {
      await _cloud.rebindRecordsSubscription();
    } catch (error, stackTrace) {
      ErrorHandler.log(error, stackTrace, 'rebindRecords');
    }
  }

  String get timestamp {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  void showMessage(String message) {
    AppState.messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> runExport({
    required List<NepRecord> recordsToExport,
    required Future<void> Function() action,
  }) async {
    if (!_requirePermission(canExportReports, 'exportar reportes')) {
      return;
    }
    if (recordsToExport.isEmpty) {
      showMessage('No hay datos para exportar.');
      return;
    }
    if (isExporting) return;

    isExporting = true;
    notifyListeners();

    try {
      await action();
    } catch (e, stack) {
      ErrorHandler.log(e, stack, 'runExport');
      showMessage('Error al exportar: ${ErrorHandler.userMessage(e)}');
    } finally {
      isExporting = false;
      notifyListeners();
    }
  }

  void setExportColumns(Set<ExportColumn> columns) {
    if (!ExportColumn.isValidSelection(columns)) return;
    exportColumns = Set<ExportColumn>.from(columns);
    notifyListeners();
  }

  void setPdfReportStyle(PdfReportStyle style) {
    if (pdfReportStyle == style) return;
    pdfReportStyle = style;
    notifyListeners();
  }

  Future<void> exportCsv({
    Set<ExportColumn>? columns,
    PdfReportStyle? style,
    List<NepRecord>? sourceRecords,
  }) async {
    final selected = columns ?? exportColumns;
    final reportStyle = style ?? pdfReportStyle;
    final toExport = resolveExportRecords(sourceRecords);
    await runExport(
      recordsToExport: toExport,
      action: () async {
        await recordExportCoordinator.shareCsv(
          records: toExport,
          columns: selected,
          style: reportStyle,
          fileTimestamp: timestamp,
        );
        showMessage('Reporte CSV listo para compartir o descargar.');
      },
    );
  }

  Future<void> exportExcel({
    Set<ExportColumn>? columns,
    PdfReportStyle? style,
    List<NepRecord>? sourceRecords,
  }) async {
    final selected = columns ?? exportColumns;
    final reportStyle = style ?? pdfReportStyle;
    final toExport = resolveExportRecords(sourceRecords);
    await runExport(
      recordsToExport: toExport,
      action: () async {
        await recordExportCoordinator.shareExcel(
          records: toExport,
          columns: selected,
          style: reportStyle,
          fileTimestamp: timestamp,
        );
        showMessage('Reporte Excel listo para compartir o descargar.');
      },
    );
  }

  Future<Uint8List> buildPdfBytes({
    Set<ExportColumn>? columns,
    PdfReportStyle? style,
    List<NepRecord>? sourceRecords,
  }) {
    return recordExportCoordinator.buildPdfBytes(
      records: resolveExportRecords(sourceRecords),
      columns: columns ?? exportColumns,
      style: style ?? pdfReportStyle,
      filtersDescription: filters.hasActiveFilters
          ? FilterDescriptionHelper.describe(filters)
          : null,
    );
  }

  Future<void> exportPdf({
    Set<ExportColumn>? columns,
    PdfReportStyle? style,
    List<NepRecord>? sourceRecords,
  }) async {
    final selected = columns ?? exportColumns;
    final reportStyle = style ?? pdfReportStyle;
    final toExport = resolveExportRecords(sourceRecords);
    await runExport(
      recordsToExport: toExport,
      action: () async {
        await recordExportCoordinator.sharePdf(
          records: toExport,
          columns: selected,
          style: reportStyle,
          fileTimestamp: timestamp,
          filtersDescription: filters.hasActiveFilters
              ? FilterDescriptionHelper.describe(filters)
              : null,
        );
      },
    );
  }

  Future<void> printPdf({PdfReportStyle? style}) async {
    final reportStyle = style ?? pdfReportStyle;
    final toExport = List<NepRecord>.from(visibleRecords);
    await runExport(
      recordsToExport: toExport,
      action: () async {
        await recordExportCoordinator.printPdf(
          records: toExport,
          columns: exportColumns,
          style: reportStyle,
          filtersDescription: filters.hasActiveFilters
              ? FilterDescriptionHelper.describe(filters)
              : null,
        );
      },
    );
  }

  Future<void> copyTable({Set<ExportColumn>? columns}) async {
    if (!_requirePermission(canExportReports, 'copiar la tabla')) {
      return;
    }
    if (visibleRecords.isEmpty) {
      showMessage('No hay datos para copiar.');
      return;
    }

    final text = recordExportCoordinator.buildTabText(
      records: visibleRecords,
      columns: columns ?? exportColumns,
    );

    await Clipboard.setData(ClipboardData(text: text));
    showMessage('Tabla copiada correctamente.');
  }

  String formatDateTime(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)}';
  }

  Future<void> saveCurrentReport(
    String name, {
    List<NepRecord>? recordsOverride,
  }) async {
    if (!_requirePermission(canManageReports, 'guardar informes')) {
      return;
    }
    // Sin override: solo visibles (filtros de Registros/Exportar).
    // Captura → Guardar debe usar [saveCaptureReport] con sourceRecords.
    final source = List<NepRecord>.from(recordsOverride ?? visibleRecords);

    if (source.isEmpty) {
      showMessage('No hay registros para guardar como informe.');
      return;
    }

    try {
      final report = await reportStorageService.saveReport(
        name: name.trim().isEmpty ? 'Informe $timestamp' : name.trim(),
        records: source,
        appliedFilters: recordsOverride == null && filters.hasActiveFilters
            ? filters.copy()
            : null,
        saveFiles: !kIsWeb,
        exportStyle: pdfReportStyle,
        createdByUid: _authUid,
      );

      if (cloudSyncEnabled) {
        showMessage(
          'Informe "${report.name}" guardado en la nube.',
        );
      } else if (!kIsWeb) {
        final folder = await reportStorageService.getReportsDirectory();
        showMessage(
          'Informe "${report.name}" guardado. Archivos en: ${folder.path}',
        );
      } else {
        showMessage(
          'Informe "${report.name}" guardado. '
          'Sincronice con Firebase para compartirlo con el equipo.',
        );
      }
    } catch (error, stack) {
      ErrorHandler.log(error, stack, 'saveReport');
      showMessage(
        'No se pudo guardar el informe: ${ErrorHandler.userMessage(error)}',
      );
    }
  }

  /// Guarda un informe desde Captura con [sourceRecords] exactos.
  ///
  /// Solo acepta pendientes de la sesión actual. Tras éxito marca esos IDs;
  /// si falla, no marca nada. No usa `records` ni `visibleRecords`.
  Future<bool> saveCaptureReport(
    String name, {
    required List<NepRecord> sourceRecords,
  }) async {
    if (!_requirePermission(canManageReports, 'guardar informes')) {
      return false;
    }

    final selected = List<NepRecord>.from(sourceRecords);
    if (selected.isEmpty) {
      showMessage('Seleccione al menos un registro.');
      return false;
    }

    final pendingIds =
        pendingCaptureSessionRecords.map((record) => record.id).toSet();
    final invalid = selected.any((record) => !pendingIds.contains(record.id));
    if (invalid) {
      showMessage(
        'Selección inválida: solo puede guardar registros pendientes '
        'de esta sesión.',
      );
      return false;
    }

    try {
      final report = await reportStorageService.saveReport(
        name: name.trim().isEmpty ? 'Informe $timestamp' : name.trim(),
        records: selected,
        appliedFilters: null,
        saveFiles: !kIsWeb,
        exportStyle: pdfReportStyle,
        createdByUid: _authUid,
      );

      // Solo tras persistencia exitosa del informe: disco y luego memoria.
      final addedIds = selected.map((record) => record.id).toSet();
      final nextSaved = {..._savedCaptureRecordIds, ...addedIds};
      final uid = _authUid;
      final sessionId = _activeCaptureSessionId;
      if (uid != null &&
          uid.isNotEmpty &&
          sessionId != null &&
          sessionId.isNotEmpty) {
        try {
          await savedCaptureIdsStorageService.save(
            uid: uid,
            captureSessionId: sessionId,
            ids: nextSaved,
          );
        } catch (persistError, persistStack) {
          ErrorHandler.log(
            persistError,
            persistStack,
            'persistSavedCaptureIds',
          );
        }
      }
      _savedCaptureRecordIds
        ..clear()
        ..addAll(nextSaved);
      notifyListeners();

      try {
        if (cloudSyncEnabled) {
          showMessage('Informe "${report.name}" guardado en la nube.');
        } else if (!kIsWeb) {
          final folder = await reportStorageService.getReportsDirectory();
          showMessage(
            'Informe "${report.name}" guardado. Archivos en: ${folder.path}',
          );
        } else {
          showMessage(
            'Informe "${report.name}" guardado. '
            'Sincronice con Firebase para compartirlo con el equipo.',
          );
        }
      } catch (_) {
        showMessage('Informe "${report.name}" guardado.');
      }
      return true;
    } catch (error, stack) {
      ErrorHandler.log(error, stack, 'saveCaptureReport');
      showMessage(
        'No se pudo guardar el informe: ${ErrorHandler.userMessage(error)}',
      );
      return false;
    }
  }

  /// Persiste de forma durable el trabajo de la sesión de captura activa.
  /// Devuelve true solo si la persistencia local confirmó (disco).
  Future<bool> persistActiveCaptureSession({String? reportName}) async {
    if (!_requirePermission(canCapture, 'guardar la sesión de captura')) {
      return false;
    }

    final uid = _authUid;
    final generation = _authGeneration;
    final sessionId = _activeCaptureSessionId;
    if (uid == null || uid.isEmpty) {
      showMessage('Debe iniciar sesión para guardar la sesión.');
      return false;
    }
    if (sessionId == null || sessionId.isEmpty) {
      showMessage('No hay sesión de captura activa.');
      return false;
    }

    final sessionRecords = List<NepRecord>.from(captureSessionRecords);
    if (sessionRecords.isEmpty) {
      showMessage('No hay registros de sesión para guardar.');
      return false;
    }

    try {
      await _persistRecords(sessionRecords);
      if (!_isAuthContextValid(generation, uid)) return false;

      final reloaded = await recordsScope.loadFromPreferences();
      if (!_isAuthContextValid(generation, uid)) return false;
      final persistedIds = reloaded.map((r) => r.id).toSet();
      final missing = sessionRecords.any((r) => !persistedIds.contains(r.id));
      if (missing) {
        showMessage(
          'No se pudo confirmar el guardado en este dispositivo. '
          'Se conservan los datos para reintentar.',
        );
        return false;
      }

      final archiveName = (reportName?.trim().isNotEmpty == true)
          ? reportName!.trim()
          : 'Sesión $timestamp';
      final archiveId =
          _pendingClosedPersonalArchiveId ?? generateStableId(prefix: 'pses');
      final archive = PersonalCaptureSessionArchive(
        id: archiveId,
        ownerUid: uid,
        captureSessionId: sessionId,
        savedAt: DateTime.now(),
        records: sessionRecords,
        name: archiveName,
      );
      await personalSessionArchiveService.upsert(archive);
      if (!_isAuthContextValid(generation, uid)) return false;
      _pendingClosedPersonalArchiveId = archive.id;

      if (canManageReports) {
        if (_pendingClosedSessionReportId != null) {
          final existing = SavedReport(
            id: _pendingClosedSessionReportId!,
            name: archiveName,
            createdAt: DateTime.now(),
            records: sessionRecords,
            createdByUid: uid,
          );
          await reportStorageService.saveExistingReport(
            existing,
            saveFiles: false,
          );
        } else {
          final report = await reportStorageService.saveReport(
            name: archiveName,
            records: sessionRecords,
            saveFiles: false,
            exportStyle: pdfReportStyle,
            createdByUid: uid,
          );
          _pendingClosedSessionReportId = report.id;
        }
      }

      final pendingOps = await pendingSyncQueueService.loadForUid(uid);
      if (!_isAuthContextValid(generation, uid)) return false;

      if (pendingOps.isNotEmpty || !cloudSyncEnabled) {
        showMessage(
          'Guardado en este dispositivo; sincronización pendiente.',
        );
      } else {
        showMessage('Sesión guardada correctamente.');
      }
      return true;
    } catch (error, stack) {
      ErrorHandler.log(error, stack, 'persistActiveCaptureSession');
      showMessage(
        'No se pudo guardar la sesión: ${ErrorHandler.userMessage(error)}',
      );
      return false;
    }
  }

  /// Tras un guardado exitoso: cierra la sesión lógica y abre una vacía.
  /// No borra registros históricos ni limpia la nube.
  Future<bool> openEmptyCaptureSessionAfterSave() {
    return _rotateToEmptyCaptureSession(
      successMessage: 'Nueva sesión lista. Todos los campos quedan vacíos.',
      failureMessage: 'La sesión se guardó, pero no se pudo abrir la nueva. '
          'Reintente sin duplicar el informe.',
      logLabel: 'openEmptyCaptureSessionAfterSave',
    );
  }

  /// Descarta únicamente el borrador de formulario y preferencias de sesión
  /// del UID actual; rota a un nuevo `captureSessionId` vacío.
  ///
  /// Conserva registros ya guardados localmente (incl. cola de sync),
  /// historial e informes. No usa clearAll ni afecta a otros usuarios.
  Future<bool> discardUnsavedDraftAndOpenEmptyCaptureSession() {
    return _rotateToEmptyCaptureSession(
      successMessage:
          'Cambios descartados. Nueva sesión lista con campos vacíos.',
      failureMessage:
          'No se pudo abrir la nueva sesión tras descartar. Reintente.',
      logLabel: 'discardUnsavedDraftAndOpenEmptyCaptureSession',
    );
  }

  /// Rota el ID de sesión, limpia borrador/prefs de lote y vacía el formulario.
  /// No elimina registros persistidos ni operaciones de sync ya encoladas.
  Future<bool> _rotateToEmptyCaptureSession({
    required String successMessage,
    required String failureMessage,
    required String logLabel,
  }) async {
    if (!_requirePermission(canCapture, 'iniciar una nueva sesión')) {
      return false;
    }
    if (_sessionTransitionBusy) return false;

    final uid = _authUid;
    final generation = _authGeneration;
    if (uid == null || uid.isEmpty) {
      showMessage('Debe iniciar sesión para crear una nueva captura.');
      return false;
    }

    _sessionTransitionBusy = true;
    notifyListeners();
    try {
      final newSessionId = generateStableId(prefix: 'ses');
      await _persistActiveCaptureSessionId(uid, newSessionId);
      if (!_isAuthContextValid(generation, uid)) return false;

      _activeCaptureSessionId = newSessionId;
      _pendingClosedSessionReportId = null;
      _pendingClosedPersonalArchiveId = null;
      _savedCaptureRecordIds.clear();
      await savedCaptureIdsStorageService.save(
        uid: uid,
        captureSessionId: newSessionId,
        ids: const <String>{},
      );
      // Evita que preferencias o restauración de borrador rellenen la sesión.
      _autoFillCaptureDefaults = false;
      await captureDraftStorageService.clearForUid(uid);
      await _clearSessionLotePreferences();
      _suppressLotePersist = true;
      try {
        clearCaptureFields(preserveCatalogDefaults: false);
      } finally {
        _suppressLotePersist = false;
      }
      if (!_isAuthContextValid(generation, uid)) return false;
      notifyListeners();
      showMessage(successMessage);
      return true;
    } catch (error, stack) {
      ErrorHandler.log(error, stack, logLabel);
      showMessage(failureMessage);
      return false;
    } finally {
      _sessionTransitionBusy = false;
      notifyListeners();
    }
  }

  Future<void> _clearSessionLotePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(loteTramaFullStorageKey);
    await prefs.remove(loteTramaPrefixStorageKey);
    await prefs.remove(loteTramaFullEntryStorageKey);
    final uid = _authUid;
    if (uid != null && uid.isNotEmpty) {
      await prefs.remove(lotePrefsKeyForUid(uid));
    }
  }

  /// Lista archivos personales del usuario autenticado (separado de informes de equipo).
  Future<List<PersonalCaptureSessionArchive>>
      loadPersonalSessionArchives() async {
    final uid = _authUid;
    if (uid == null || uid.isEmpty) return const [];
    return personalSessionArchiveService.loadForUid(uid);
  }

  /// Abre una sesión personal guardada desde el historial de la UI.
  Future<bool> openPersonalCaptureArchive(
    PersonalCaptureSessionArchive archive,
  ) async {
    if (!_requirePermission(canCapture, 'abrir una sesión personal')) {
      return false;
    }
    final uid = _authUid;
    final generation = _authGeneration;
    if (uid == null || uid.isEmpty) {
      showMessage('Debe iniciar sesión para abrir el historial personal.');
      return false;
    }
    if (archive.ownerUid != uid) {
      showMessage('No puede abrir el archivo personal de otra cuenta.');
      return false;
    }
    if (archive.records.isEmpty) {
      showMessage('La sesión guardada no tiene registros.');
      return false;
    }

    try {
      await recordsScope.bindUser(uid);
      if (!_isAuthContextValid(generation, uid)) return false;
      await _persistRecords(archive.records);
      if (!_isAuthContextValid(generation, uid)) return false;

      await _persistActiveCaptureSessionId(uid, archive.captureSessionId);
      if (!_isAuthContextValid(generation, uid)) return false;
      _activeCaptureSessionId = archive.captureSessionId;
      await _loadSavedCaptureIdsForSession(uid, archive.captureSessionId);

      records = await recordsScope.loadFromPreferences();
      if (!_isAuthContextValid(generation, uid)) return false;

      _autoFillCaptureDefaults = false;
      clearCaptureFields(preserveCatalogDefaults: false);
      notifyListeners();
      showMessage(
        'Sesión "${archive.name.isEmpty ? archive.id : archive.name}" abierta '
        '(${archive.records.length} registros).',
      );
      return true;
    } catch (error, stack) {
      ErrorHandler.log(error, stack, 'openPersonalCaptureArchive');
      showMessage(
        'No se pudo abrir la sesión: ${ErrorHandler.userMessage(error)}',
      );
      return false;
    }
  }

  /// Inicia sesión vacía sin contenido que guardar (sin diálogo de guardado).
  Future<void> startEmptyCaptureSessionIfIdle() async {
    if (!_requirePermission(canCapture, 'iniciar una nueva sesión')) {
      return;
    }
    if (hasCaptureSessionWork) return;
    await openEmptyCaptureSessionAfterSave();
  }

  @Deprecated(
      'Usar persistActiveCaptureSession + openEmptyCaptureSessionAfterSave')
  Future<void> startNewCaptureSession() async {
    if (!_requirePermission(canCapture, 'iniciar una nueva sesión')) {
      return;
    }
    // Compatibilidad: ya no borra registros históricos.
    final saved = captureSessionRecords.isEmpty
        ? true
        : await persistActiveCaptureSession();
    if (!saved) return;
    await openEmptyCaptureSessionAfterSave();
  }

  /// Informe histórico abierto solo para visualización read-only.
  /// No forma parte del dataset operativo (`records` / Captura).
  SavedReport? viewingSavedReport;

  void clearViewingSavedReport() {
    if (viewingSavedReport == null) return;
    viewingSavedReport = null;
    notifyListeners();
  }

  /// Abre un [SavedReport] en modo lectura.
  ///
  /// No modifica `records`, persistencia operativa, sesión de captura,
  /// `savedCaptureRecordIds` ni sincroniza registros hacia Firestore.
  Future<bool> openSavedReportView(SavedReport report) async {
    if (!_requirePermission(canManageReports, 'ver informes guardados')) {
      return false;
    }
    if (!canViewSavedReport(
      report,
      viewerUid: _authUid,
      canViewTeamReports: canManageReports,
    )) {
      showMessage('No tiene permiso para abrir este informe.');
      return false;
    }

    viewingSavedReport = SavedReport(
      id: report.id,
      name: report.name,
      createdAt: report.createdAt,
      records: List<NepRecord>.from(report.records),
      appliedFilters: report.appliedFilters?.copy(),
      createdByUid: report.createdByUid,
    );
    notifyListeners();
    return true;
  }

  /// @Deprecated Use [openSavedReportView]. Conservado solo por compatibilidad
  /// de tests legados; ya no reemplaza registros vivos.
  Future<void> loadReport(SavedReport report) async {
    await openSavedReportView(report);
  }

  RecordImportResult previewImport({
    required Uint8List bytes,
    required String fileName,
  }) {
    return recordImportService.importFromBytes(
      bytes,
      fileName: fileName,
      existingRecords: records,
    );
  }

  Future<void> confirmImportRecords(List<NepRecord> toImport) async {
    if (!_requirePermission(canImportRecords, 'importar registros')) {
      return;
    }

    if (toImport.isEmpty) {
      showMessage('No hay registros válidos para importar.');
      return;
    }

    try {
      await _persistRecords(toImport);
      await _mergeImportedFabrics(toImport);
      if (!cloudSyncEnabled) {
        notifyListeners();
      }
      showMessage(
        'Se importaron ${toImport.length} registros correctamente.',
      );
    } catch (e, stack) {
      ErrorHandler.log(e, stack, 'confirmImportRecords');
      showMessage(
          'Error al importar registros: ${ErrorHandler.userMessage(e)}');
    }
  }

  Future<void> downloadImportTemplate() async {
    // Solo lectura/export local: no exige capture+edit (sí ver registros).
    if (!_requirePermission(_hasPermission(Permission.viewRecords),
        'descargar plantillas de importación')) {
      return;
    }
    try {
      final bytes = ImportTemplateService().buildExcelTemplate();
      await FileShareHelper.shareBytes(
        bytes: bytes,
        fileName: 'plantilla_importacion_neps.xlsx',
        mimeType: FileShareHelper.excelMimeType,
        shareText: 'Plantilla para importar registros de neps',
        subject: 'Plantilla importación Neps',
      );
    } catch (e, stack) {
      ErrorHandler.log(e, stack, 'downloadImportTemplate');
      showMessage(
          'No se pudo generar la plantilla: ${ErrorHandler.userMessage(e)}');
    }
  }

  Future<void> applyCorrectiveAction({
    required String recordId,
    required String accion,
    required String responsable,
    required bool marcarRevisado,
  }) async {
    if (!_requirePermission(
      canApplyCorrectiveAction,
      'registrar acciones correctivas',
    )) {
      return;
    }

    final index = records.indexWhere((record) => record.id == recordId);
    if (index < 0) {
      showMessage('Registro no encontrado.');
      return;
    }

    final existing = records[index];
    final entry = CorrectiveActionEntry(
      fecha: DateTime.now(),
      responsable: responsable,
      accion: accion,
    );

    final updated = existing.copyWith(
      accionCorrectiva: accion,
      responsableRevision: responsable,
      historialAcciones: [...existing.historialAcciones, entry],
      revisadoPorSupervisor:
          marcarRevisado ? true : existing.revisadoPorSupervisor,
      fechaRevision: marcarRevisado ? DateTime.now() : existing.fechaRevision,
    );

    await _updateRecord(updated);
    showMessage('Seguimiento registrado correctamente.');
  }

  Future<void> importRecords({
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      final result = previewImport(bytes: bytes, fileName: fileName);

      if (!result.hasRecords) {
        showMessage(
          result.message ??
              'No se encontraron registros validos en el archivo.',
        );
        return;
      }

      await confirmImportRecords(result.importableRecords);
    } catch (e, stack) {
      ErrorHandler.log(e, stack, 'importRecords');
      showMessage(
          'Error al importar registros: ${ErrorHandler.userMessage(e)}');
    }
  }

  Future<void> _mergeImportedFabrics(List<NepRecord> imported) async {
    final names = imported
        .map((record) => record.tela.trim())
        .where((name) => name.isNotEmpty)
        .toList();

    if (names.isEmpty) return;

    final merged = fabricCatalogService.mergeFabrics(fabrics, names);
    if (merged.length == fabrics.length) return;

    await saveFabrics(merged);
  }

  Future<void> saveAlertConfig(AlertConfig config) async {
    if (!_requirePermission(
        canEditAlertConfig, 'modificar los límites de alerta')) {
      return;
    }

    await alertConfigService.save(config);
    alertService.updateConfig(config);

    if (cloudSyncCoordinator != null && await _ensureCloudReady()) {
      try {
        await cloudSyncCoordinator!.saveAlertConfig(
          alertConfigService.toFirestoreMap(),
        );
      } catch (error, stackTrace) {
        ErrorHandler.log(error, stackTrace, 'saveAlertConfig');
      }
    }

    notifyListeners();
  }

  Future<void> setCriticalNotificationsEnabled(bool enabled) async {
    await notificationPreferencesService.setCriticalAlertsEnabled(enabled);
    notifyListeners();
  }

  NepRecord? buildCaptureRecord() {
    if (!canCapture) {
      showMessage(permissionsService.deniedMessage('capturar registros'));
      return null;
    }

    final telar = telarController.text.trim();
    final nepsText = nepsController.text.trim();
    final tela = resolveSelectedTela();

    if (tela == null) {
      showMessage('Seleccione o ingrese la tela.');
      return null;
    }

    final loteTrama = resolveLoteTramaForSave();
    if (loteTrama == null) {
      showMessage('Seleccione o ingrese el lote de trama.');
      return null;
    }

    if (telar.isEmpty) {
      showMessage('Ingrese el numero de telar.');
      return null;
    }

    if (nepsText.isEmpty || parseNumber(nepsText) <= 0) {
      showMessage('Ingrese una cantidad valida de neps.');
      return null;
    }

    // Garantiza sessionId estable aunque auth/prefs aún no hayan terminado.
    if (_activeCaptureSessionId == null || _activeCaptureSessionId!.isEmpty) {
      _activeCaptureSessionId = generateStableId(prefix: 'ses');
      final uid = _authUid;
      final sessionId = _activeCaptureSessionId!;
      if (uid != null && uid.isNotEmpty) {
        unawaited(_persistActiveCaptureSessionId(uid, sessionId));
      }
    }

    return NepRecord(
      telar: telar,
      neps: parseNumber(nepsText),
      tela: tela,
      loteTrama: loteTrama,
      turno: turnoController.text.trim(),
      operario: operarioController.text.trim(),
      lineaProduccion: lineaProduccionController.text.trim(),
      observacion: observacionController.text.trim(),
      accionCorrectiva: accionInmediataController.text.trim(),
      createdByUid: _authUid,
      createdByEmail: _authUsername,
      createdByRole:
          authRoleCode.isNotEmpty ? authRoleCode : _authAppRole?.code,
      captureSessionId: _activeCaptureSessionId,
    );
  }

  bool isRecentDuplicate(NepRecord candidate) {
    final threshold = DateTime.now().subtract(const Duration(minutes: 2));
    // Solo compara dentro de la sesión activa del usuario (evita falsos
    // positivos con el mismo telar/lote de otro usuario u otra sesión).
    return captureSessionRecords.any(
      (r) =>
          r.telar == candidate.telar &&
          r.tela == candidate.tela &&
          r.loteTrama == candidate.loteTrama &&
          r.neps == candidate.neps &&
          r.createdAt.isAfter(threshold),
    );
  }

  Future<NepRecord?> submitCaptureRecord(NepRecord record) async {
    await _persistRecord(record);
    await addLoteTramaToCatalog(record.loteTrama);
    _clearCaptureInputs();

    final level = alertService.getAlertLevel(record.neps);
    if (level == AlertLevel.critico) {
      _showCriticalAlertSnackBar(record);
      unawaited(
        notificationService.showCriticalAlert(
          record: record,
          formatDecimal: formatDecimal,
        ),
      );
      showMessage(
        'Alerta crítica: el telar ${record.telar} registró '
        '${formatDecimal(record.neps)} neps.',
      );
    } else {
      showMessage('Registro agregado correctamente.');
    }
    return record;
  }

  void _showCriticalAlertSnackBar(NepRecord record) {
    messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(
          'Alerta crítica: telar ${record.telar} — '
          '${formatDecimal(record.neps)} neps',
        ),
        backgroundColor: const Color(0xFFB94D4D),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Ver alertas',
          textColor: Colors.white,
          onPressed: () => setNavigationIndex(3),
        ),
      ),
    );
  }

  void _clearCaptureInputs() {
    capture.clearFieldsForNextRecord(notify: false);
    captureFormEpoch++;
    notifyListeners();
  }

  Future<void> addRecord() async {
    final record = buildCaptureRecord();
    if (record == null) return;
    await submitCaptureRecord(record);
  }

  Future<void> updateRecord({
    required String id,
    required String telar,
    required double neps,
    required String tela,
    required String loteTrama,
    String turno = '',
    String operario = '',
    String lineaProduccion = '',
    String observacion = '',
    String accionCorrectiva = '',
    bool revisadoPorSupervisor = false,
    DateTime? fechaRevision,
  }) async {
    if (!_requirePermission(canEditRecords, 'editar registros')) {
      return;
    }

    final index = records.indexWhere((record) => record.id == id);
    if (index < 0) {
      showMessage('Registro no encontrado.');
      return;
    }

    final existing = records[index];
    // Conserva autoría; registra quién modifica (permiso editRecords).
    final updated = existing.copyWith(
      telar: telar.trim(),
      neps: neps,
      tela: tela.trim(),
      loteTrama: loteTrama,
      turno: turno,
      operario: operario,
      lineaProduccion: lineaProduccion,
      observacion: observacion,
      accionCorrectiva: accionCorrectiva,
      revisadoPorSupervisor: revisadoPorSupervisor,
      fechaRevision: fechaRevision,
      createdByUid: existing.createdByUid,
      createdByEmail: existing.createdByEmail,
      createdByRole: existing.createdByRole,
      captureSessionId: existing.captureSessionId,
      lastModifiedByUid: _authUid,
      lastModifiedByEmail: _authUsername,
      lastModifiedAt: DateTime.now(),
    );

    await _updateRecord(updated);
    showMessage('Registro actualizado correctamente.');
  }

  Future<void> _updateRecord(NepRecord record) async {
    final uid = _authUid;
    final generation = _authGeneration;
    if (uid == null || uid.isEmpty) {
      showMessage('Debe iniciar sesión para modificar registros.');
      return;
    }

    // Evita escribir en storage sin UID (carrera post-login o fixture incompleto).
    if (recordLocalStorageService.boundUid != uid) {
      await recordsScope.bindUser(uid);
      if (!_isAuthContextValid(generation, uid)) return;
    }

    records = [
      for (final item in records)
        if (item.id == record.id) record else item,
    ];
    await recordsScope.persistRecord(record);
    if (!_isAuthContextValid(generation, uid)) return;
    notifyListeners();

    if (cloudSyncCoordinator != null && await _ensureCloudReady()) {
      if (!_isAuthContextValid(generation, uid)) return;
      try {
        await cloudSyncCoordinator!.upsertRecord(record);
        return;
      } catch (error, stackTrace) {
        cloudSyncEnabled = false;
        ErrorHandler.log(error, stackTrace, 'updateRecord');
        showMessage(
          'No se pudo sincronizar con Firebase. Cambio guardado localmente.',
        );
      }
    }
  }

  Future<RecordDeleteOutcome> deleteRecord(String recordId) async {
    lastDeleteOutcome = null;
    if (!_requirePermission(canDeleteRecords, 'eliminar registros')) {
      lastDeleteOutcome = RecordDeleteOutcome.permissionDeniedLocal;
      return lastDeleteOutcome!;
    }

    final index = records.indexWhere((r) => r.id == recordId);
    if (index < 0) {
      showMessage('Registro no encontrado.');
      lastDeleteOutcome = RecordDeleteOutcome.notFound;
      return lastDeleteOutcome!;
    }

    final record = records[index];
    final verifiedOwner = verifiedRecordOwnerUid(record);

    debugPrint(
      '[deleteRecord] authRoleCode=$authRoleCode '
      'canDeleteRecords=$canDeleteRecords '
      'record.id=${record.id} '
      'record.createdByUid=${record.createdByUid ?? '(null)'} '
      'cloudSyncEnabled=$cloudSyncEnabled',
    );

    if (authRoleCode == 'operario' && _authUid != null) {
      if (record.createdByUid != null && record.createdByUid != _authUid) {
        showMessage('Solo puede eliminar registros propios.');
        lastDeleteOutcome = RecordDeleteOutcome.permissionDeniedLocal;
        return lastDeleteOutcome!;
      }
    }

    final uid = _authUid;
    final generation = _authGeneration;

    if (cloudSyncCoordinator != null && await _ensureCloudReady()) {
      if (uid != null && !_isAuthContextValid(generation, uid)) {
        lastDeleteOutcome = RecordDeleteOutcome.notFound;
        return lastDeleteOutcome!;
      }
      try {
        await cloudSyncCoordinator!.deleteRecord(
          recordId,
          ownerUid: verifiedOwner,
        );
        debugPrint('[deleteRecord] resultado cloud=ok');
        if (uid != null && !_isAuthContextValid(generation, uid)) {
          lastDeleteOutcome = RecordDeleteOutcome.deletedRemote;
          return lastDeleteOutcome!;
        }
        recordsScope.removeById(recordId);
        await recordsScope.persistLocally();
        notifyListeners();
        showMessage('Registro eliminado correctamente.');
        lastDeleteOutcome = RecordDeleteOutcome.deletedRemote;
        return lastDeleteOutcome!;
      } on FirebaseException catch (error, stackTrace) {
        ErrorHandler.log(error, stackTrace, 'deleteRecord');
        debugPrint(
          '[deleteRecord] FirebaseException code=${error.code} '
          'DELETE_PERMISSION_DENIED=${error.code == 'permission-denied'} '
          'authRoleCode=$authRoleCode canDeleteRecords=$canDeleteRecords',
        );
        if (error.code == 'permission-denied') {
          showMessage('No tiene permiso para eliminar este registro.');
          lastDeleteOutcome = RecordDeleteOutcome.permissionDenied;
          return lastDeleteOutcome!;
        }
        if (_isOfflineLikeFirebaseError(error)) {
          return _deleteLocalPendingSync(
            recordId: recordId,
            actorUid: uid,
            recordOwnerUid: verifiedOwner,
            generation: generation,
          );
        }
        showMessage(
          'No se pudo eliminar el registro: ${ErrorHandler.userMessage(error)}',
        );
        lastDeleteOutcome = RecordDeleteOutcome.firebaseError;
        return lastDeleteOutcome!;
      } catch (error, stackTrace) {
        ErrorHandler.log(error, stackTrace, 'deleteRecord');
        if (_isOfflineLikeError(error)) {
          return _deleteLocalPendingSync(
            recordId: recordId,
            actorUid: uid,
            recordOwnerUid: verifiedOwner,
            generation: generation,
          );
        }
        showMessage(
          'No se pudo eliminar el registro: ${ErrorHandler.userMessage(error)}',
        );
        lastDeleteOutcome = RecordDeleteOutcome.firebaseError;
        return lastDeleteOutcome!;
      }
    }

    if (cloudSyncCoordinator != null) {
      return _deleteLocalPendingSync(
        recordId: recordId,
        actorUid: uid,
        recordOwnerUid: verifiedOwner,
        generation: generation,
      );
    }

    recordsScope.removeById(recordId);
    await recordsScope.persistLocally();
    notifyListeners();
    showMessage('Registro eliminado correctamente.');
    lastDeleteOutcome = RecordDeleteOutcome.deletedLocalPendingSync;
    return lastDeleteOutcome!;
  }

  Future<RecordDeleteOutcome> _deleteLocalPendingSync({
    required String recordId,
    required String? actorUid,
    required String? recordOwnerUid,
    required int generation,
  }) async {
    recordsScope.removeById(recordId);
    await recordsScope.persistLocally();
    if (actorUid != null && !_isAuthContextValid(generation, actorUid)) {
      lastDeleteOutcome = RecordDeleteOutcome.deletedLocalPendingSync;
      return lastDeleteOutcome!;
    }
    notifyListeners();

    if (actorUid != null) {
      await pendingSyncQueueService.enqueueDelete(
        actorUid,
        recordId,
        ownerUid: recordOwnerUid ?? '',
      );
    }
    showMessage(
      'Registro eliminado localmente. Eliminación pendiente de sincronizar.',
    );
    lastDeleteOutcome = RecordDeleteOutcome.deletedLocalPendingSync;
    return lastDeleteOutcome!;
  }

  bool _isOfflineLikeFirebaseError(FirebaseException error) {
    return error.code == 'unavailable' ||
        error.code == 'deadline-exceeded' ||
        error.code == 'network-request-failed';
  }

  bool _isOfflineLikeError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('socketexception') ||
        text.contains('network') ||
        text.contains('failed to fetch') ||
        text.contains('clientexception');
  }

  Future<void> clearTable() async {
    if (!_requirePermission(canClearAllRecords, 'vaciar la tabla')) {
      return;
    }
    if (records.isEmpty) {
      showMessage('La tabla ya esta vacia.');
      return;
    }
    await _clearAllRecords();
    if (!cloudSyncEnabled) {
      notifyListeners();
    }
    showMessage('Tabla vaciada correctamente.');
  }

  void clearCaptureFields({bool preserveCatalogDefaults = false}) {
    capture.clearCaptureFields(notify: false);
    selectedFabric = null;
    useManualFabric = false;
    if (preserveCatalogDefaults && _autoFillCaptureDefaults) {
      _syncFabricSelection(allowAutoSelect: true);
      _ensureDefaultLotePreview();
    } else {
      _syncFabricSelection(allowAutoSelect: false);
    }
    captureFormEpoch++;
    notifyListeners();
  }

  void setManualFabricMode(bool manual) {
    useManualFabric = manual;
    notifyListeners();
  }

  void setSelectedFabric(String? fabric) {
    selectedFabric = fabric;
    notifyListeners();
  }

  void onFiltersChanged() {
    recordsScope.onFiltersChanged();
    filterPanelKey = recordsScope.filterPanelKey;
    unawaited(_rebindRecordsIfCloudReady());
    notifyListeners();
  }
}
