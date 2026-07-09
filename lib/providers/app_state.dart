import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/navigation/app_navigation.dart';
import '../core/alert_config.dart';
import '../core/constants.dart';
import '../core/errors/error_handler.dart';
import '../models/app_user.dart';
import '../models/app_user_role.dart';
import '../models/alert_level.dart';
import '../models/corrective_action_entry.dart';
import '../models/export_column.dart';
import '../models/nep_record.dart';
import '../models/pdf_report_style.dart';
import '../models/record_filters.dart';
import '../models/record_import_result.dart';
import '../models/saved_report.dart';
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
import '../services/report_storage_service.dart';
import '../services/siri_shortcut_service.dart';
import '../utils/file_share_helper.dart';
import '../utils/filter_description_helper.dart';
import '../utils/lote_trama_helper.dart';
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
        loadLocalRecords: () => recordsScope.loadFromPreferences(),
        loadLocalFabrics: () => fabricCatalogService.loadFabrics(),
        applyRecordsPage: (page) {
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
        applyFabrics: (data) => fabrics = data,
        syncFabricSelection: _syncFabricSelection,
        cacheRecords: _mergeRecordsLocally,
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

  String? get authUsername => _authUsername;

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

  List<NepRecord> get records => recordsScope.items;
  set records(List<NepRecord> value) {
    recordsScope.items = value;
    recordsScope.notifyListeners();
  }

  List<String> fabrics = [];
  List<String> loteCatalog = [];
  String? selectedFabric;
  bool useManualFabric = false;
  bool isLoading = true;
  bool isExporting = false;
  String? bootstrapError;
  int navigationIndex = 0;
  AppNavId? pendingNavTarget;
  Set<ExportColumn> exportColumns = ExportColumn.defaultSelection();
  PdfReportStyle pdfReportStyle = PdfReportStyle.completo;

  List<NepRecord> get visibleRecords => recordsScope.visible;

  /// Subconjunto ligero para el panel principal.
  List<NepRecord> get dashboardRecords => recordsScope.dashboardRecords;

  int get criticalAlertsCount =>
      alertService.detectCriticalRecords(records).length;

  AppUserRole get authRole => _authAppRole ?? AppUserRole.operario;

  bool get canCapture => _hasPermission(Permission.captureRecords);

  bool get canImportRecords =>
      permissionsService.canImportRecords(_authAppRole);

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

  bool get isReadOnlyUser => permissionsService.isReadOnly(_authAppRole);

  bool _hasPermission(Permission permission) {
    return RolePermissions.has(authRole, permission);
  }

  void applyAuthProfile(AppUser user) {
    _authUid = user.uid;
    _authUsername =
        user.username.isNotEmpty ? user.username : user.effectiveDisplayName;
    _authAppRole = user.role;
    notifyListeners();
  }

  /// Cierra suscripciones y estado de nube al cerrar sesión.
  void resetCloudSession() {
    _cloud.resetSession();
    _authUid = null;
    _authUsername = null;
    _authAppRole = null;
    notifyListeners();
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
    _cloud.dispose();
    capture.detachListeners(notifyListeners);
    recordsScope.removeListener(notifyListeners);
    capture.removeListener(notifyListeners);
    capture.dispose();
    super.dispose();
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
    await _cloud.bootstrapReportsIfNeeded();
    return reportStorageService.loadReports();
  }

  Future<void> enableCloudSyncIfAvailable() => _cloud.enableIfAvailable();

  Future<void> _loadLocalData() async {
    final loaded = await Future.wait([
      recordsScope.loadFromPreferences(),
      fabricCatalogService.loadFabrics(),
      loteTramaCatalogService.loadCatalog(),
    ]);

    records = loaded[0] as List<NepRecord>;
    fabrics = loaded[1] as List<String>;
    loteCatalog = loaded[2] as List<String>;

    _suppressLotePersist = true;
    try {
      await _loadLotePreferences();
      _syncFabricSelection();
      _ensureDefaultLotePreview();
    } finally {
      _suppressLotePersist = false;
    }
  }

  void _ensureDefaultLotePreview() {
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
    final savedPrefix = prefs.getString(loteTramaPrefixStorageKey);
    if (savedPrefix != null && savedPrefix.trim().isNotEmpty) {
      lotePrefixController.text = LoteTramaHelper.normalizePrefix(savedPrefix);
    }
    loteFullEntryMode = prefs.getBool(loteTramaFullEntryStorageKey) ?? false;

    // Restaura el último lote de trama usado para acelerar la captura.
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
    await prefs.setString(
      loteTramaPrefixStorageKey,
      LoteTramaHelper.normalizePrefix(lotePrefixController.text),
    );
    await prefs.setBool(loteTramaFullEntryStorageKey, loteFullEntryMode);
  }

  /// Evita persistir el lote mientras se restauran/derivan valores en la carga.
  bool _suppressLotePersist = false;

  Future<void> _saveLoteFull() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      loteTramaFullStorageKey,
      loteFullController.text.trim(),
    );
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

  Future<void> ensureCloudConnected() => _cloud.ensureConnected();

  void _syncFabricSelection() {
    if (fabrics.isEmpty) {
      useManualFabric = true;
      return;
    }

    if (useManualFabric) return;

    if (selectedFabric == null || !fabrics.contains(selectedFabric)) {
      selectedFabric = fabrics.first;
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
    recordsScope.upsert(record);
    await recordsScope.persistRecord(record);
    notifyListeners();

    if (cloudSyncCoordinator != null && await _ensureCloudReady()) {
      try {
        await cloudSyncCoordinator!.upsertRecord(record);
        return;
      } catch (error, stackTrace) {
        cloudSyncEnabled = false;
        ErrorHandler.log(error, stackTrace, 'persistRecord');
        showMessage(
          'No se pudo sincronizar con Firebase. Registro guardado localmente.',
        );
      }
    }
  }

  Future<void> _persistRecords(List<NepRecord> updatedRecords) async {
    for (final record in updatedRecords) {
      recordsScope.upsert(record);
    }
    await recordsScope.persistMerged(updatedRecords);
    notifyListeners();

    if (cloudSyncCoordinator != null && await _ensureCloudReady()) {
      try {
        await cloudSyncCoordinator!.upsertRecords(updatedRecords);
        return;
      } catch (_) {
        cloudSyncEnabled = false;
      }
    }
  }

  Future<void> _replaceAllRecords(List<NepRecord> updatedRecords) async {
    records = updatedRecords;
    await _cacheRecordsLocally(updatedRecords);

    if (cloudSyncCoordinator != null && await _ensureCloudReady()) {
      try {
        await cloudSyncCoordinator!.replaceRecords(updatedRecords);
        return;
      } catch (_) {
        cloudSyncEnabled = false;
      }
    }
  }

  Future<void> _removeRecord(String recordId) async {
    final index = records.indexWhere((record) => record.id == recordId);
    final ownerUid = index >= 0 ? records[index].createdByUid : null;

    recordsScope.removeById(recordId);
    await recordsScope.persistLocally();
    notifyListeners();

    if (cloudSyncCoordinator != null && await _ensureCloudReady()) {
      try {
        await cloudSyncCoordinator!.deleteRecord(
          recordId,
          ownerUid: ownerUid,
        );
        return;
      } catch (_) {
        cloudSyncEnabled = false;
      }
    }
  }

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

  Future<void> runExport(Future<void> Function() action) async {
    if (!_requirePermission(canExportReports, 'exportar reportes')) {
      return;
    }
    if (visibleRecords.isEmpty) {
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
  }) async {
    final selected = columns ?? exportColumns;
    final reportStyle = style ?? pdfReportStyle;
    await runExport(() async {
      await recordExportCoordinator.shareCsv(
        records: visibleRecords,
        columns: selected,
        style: reportStyle,
        fileTimestamp: timestamp,
      );
      showMessage('Reporte CSV listo para compartir o descargar.');
    });
  }

  Future<void> exportExcel({
    Set<ExportColumn>? columns,
    PdfReportStyle? style,
  }) async {
    final selected = columns ?? exportColumns;
    final reportStyle = style ?? pdfReportStyle;
    await runExport(() async {
      await recordExportCoordinator.shareExcel(
        records: visibleRecords,
        columns: selected,
        style: reportStyle,
        fileTimestamp: timestamp,
      );
      showMessage('Reporte Excel listo para compartir o descargar.');
    });
  }

  Future<Uint8List> buildPdfBytes({
    Set<ExportColumn>? columns,
    PdfReportStyle? style,
  }) {
    return recordExportCoordinator.buildPdfBytes(
      records: visibleRecords,
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
  }) async {
    final selected = columns ?? exportColumns;
    final reportStyle = style ?? pdfReportStyle;
    await runExport(() async {
      await recordExportCoordinator.sharePdf(
        records: visibleRecords,
        columns: selected,
        style: reportStyle,
        fileTimestamp: timestamp,
        filtersDescription: filters.hasActiveFilters
            ? FilterDescriptionHelper.describe(filters)
            : null,
      );
    });
  }

  Future<void> printPdf({PdfReportStyle? style}) async {
    final reportStyle = style ?? pdfReportStyle;
    await runExport(() async {
      await recordExportCoordinator.printPdf(
        records: visibleRecords,
        columns: exportColumns,
        style: reportStyle,
        filtersDescription: filters.hasActiveFilters
            ? FilterDescriptionHelper.describe(filters)
            : null,
      );
    });
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

  Future<void> saveCurrentReport(String name) async {
    if (!_requirePermission(canManageReports, 'guardar informes')) {
      return;
    }
    if (records.isEmpty) {
      showMessage('No hay registros para guardar como informe.');
      return;
    }

    final dataToSave = filters.hasActiveFilters
        ? visibleRecords
        : List<NepRecord>.from(records);

    if (dataToSave.isEmpty) {
      showMessage('No hay registros visibles para guardar.');
      return;
    }

    try {
      final report = await reportStorageService.saveReport(
        name: name.trim().isEmpty ? 'Informe $timestamp' : name.trim(),
        records: dataToSave,
        appliedFilters: filters.hasActiveFilters ? filters.copy() : null,
        saveFiles: !kIsWeb,
        exportStyle: pdfReportStyle,
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

  Future<void> loadReport(SavedReport report) async {
    if (!_requirePermission(canManageReports, 'cargar informes en registros')) {
      return;
    }
    final loadedRecords = List<NepRecord>.from(report.records);

    if (report.appliedFilters != null) {
      final f = report.appliedFilters!;
      filters
        ..tela = f.tela
        ..loteTrama = f.loteTrama
        ..telar = f.telar
        ..nepsMin = f.nepsMin
        ..nepsMax = f.nepsMax
        ..mtsMin = f.mtsMin
        ..mtsMax = f.mtsMax
        ..dateFrom = f.dateFrom
        ..dateTo = f.dateTo
        ..searchText = f.searchText
        ..alertLevel = f.alertLevel
        ..turno = f.turno
        ..operario = f.operario
        ..lineaProduccion = f.lineaProduccion
        ..soloNoRevisados = f.soloNoRevisados
        ..soloConAccionCorrectiva = f.soloConAccionCorrectiva
        ..quickRange = f.quickRange;
      filterPanelKey++;
    }

    await _replaceAllRecords(loadedRecords);
    navigationIndex = 2;
    if (!cloudSyncEnabled) {
      notifyListeners();
    }
    showMessage('Informe "${report.name}" cargado en registros.');
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
    if (!_requirePermission(
        canImportRecords, 'descargar plantillas de importación')) {
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
      createdByRole: _authAppRole?.code,
    );
  }

  bool isRecentDuplicate(NepRecord candidate) {
    final threshold = DateTime.now().subtract(const Duration(minutes: 2));
    return records.any(
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
    if (!cloudSyncEnabled) {
      notifyListeners();
    }

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
    capture.clearCaptureFields(notify: false);
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
    );

    await _updateRecord(updated);
    showMessage('Registro actualizado correctamente.');
  }

  Future<void> _updateRecord(NepRecord record) async {
    records = [
      for (final item in records)
        if (item.id == record.id) record else item,
    ];
    await recordsScope.persistRecord(record);
    notifyListeners();

    if (cloudSyncCoordinator != null && await _ensureCloudReady()) {
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

  Future<void> deleteRecord(String recordId) async {
    if (!_requirePermission(canDeleteRecords, 'eliminar registros')) {
      return;
    }

    if (_authAppRole == AppUserRole.operario && _authUid != null) {
      final index = records.indexWhere((r) => r.id == recordId);
      if (index >= 0) {
        final record = records[index];
        if (record.createdByUid != null && record.createdByUid != _authUid) {
          showMessage('Solo puede eliminar registros propios.');
          return;
        }
      }
    }

    await _removeRecord(recordId);
    if (!cloudSyncEnabled) {
      notifyListeners();
    }
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

  Future<void> startNewCaptureSession() async {
    if (!_requirePermission(canClearAllRecords, 'iniciar una nueva sesión')) {
      return;
    }
    await _clearAllRecords();
    clearCaptureFields();
    recordsScope.clearFilters();
    filterPanelKey = recordsScope.filterPanelKey;
    unawaited(_rebindRecordsIfCloudReady());
    if (!cloudSyncEnabled) {
      notifyListeners();
    }
    showMessage('Nueva sesion iniciada. Tabla vacia.');
  }

  void clearCaptureFields() {
    capture.clearCaptureFields(notify: false);
    selectedFabric = null;
    useManualFabric = false;
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
