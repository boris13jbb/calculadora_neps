import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/alert_config.dart';
import '../core/constants.dart';
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
import '../models/user_role.dart';
import '../services/alert_config_service.dart';
import '../services/alert_service.dart';
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
import '../services/record_import_service.dart';
import '../services/report_export_service.dart';
import '../services/report_storage_service.dart';
import '../services/siri_shortcut_service.dart';
import '../utils/file_share_helper.dart';
import '../utils/filter_description_helper.dart';
import '../utils/lote_trama_helper.dart';
import '../utils/record_filter_helper.dart';

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
      cloudSyncService: syncService,
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
    this.cloudSyncService,
    required this.fabricCatalogService,
    required this.loteTramaCatalogService,
    required this.recordImportService,
    required this.reportStorageService,
    required this.reportExportService,
  });

  CloudSyncPort? cloudSyncService;
  final FabricCatalogService fabricCatalogService;
  final LoteTramaCatalogService loteTramaCatalogService;
  final RecordImportService recordImportService;
  final ReportStorageService reportStorageService;
  final ReportExportService reportExportService;

  bool cloudSyncEnabled = false;
  String? cloudSyncError;
  UserRole userRole = UserRole.supervisor;
  String? _authUid;
  String? _authUsername;
  AppUserRole? _authAppRole;
  StreamSubscription<List<NepRecord>>? _recordsSubscription;
  StreamSubscription<List<String>>? _fabricsSubscription;

  String? get authUsername => _authUsername;

  final RecordFilters filters = RecordFilters();
  final TextEditingController telarController = TextEditingController();
  final TextEditingController nepsController = TextEditingController();
  final TextEditingController lotePrefixController =
      TextEditingController(text: loteTramaPrefix);
  final TextEditingController loteSuffixController = TextEditingController();
  final TextEditingController loteFullController = TextEditingController();
  final TextEditingController manualTelaController = TextEditingController();
  final TextEditingController turnoController = TextEditingController();
  final TextEditingController operarioController = TextEditingController();
  final TextEditingController lineaProduccionController = TextEditingController();
  final TextEditingController observacionController = TextEditingController();
  final TextEditingController accionInmediataController =
      TextEditingController();
  bool loteFullEntryMode = false;

  List<NepRecord> records = [];
  List<String> fabrics = [];
  List<String> loteCatalog = [];
  String? selectedFabric;
  bool useManualFabric = false;
  bool isLoading = true;
  bool isExporting = false;
  String? bootstrapError;
  int filterPanelKey = 0;
  int navigationIndex = 0;
  Set<ExportColumn> exportColumns = ExportColumn.defaultSelection();
  PdfReportStyle pdfReportStyle = PdfReportStyle.completo;

  List<NepRecord> get visibleRecords =>
      RecordFilterHelper.apply(records, filters);

  int get criticalAlertsCount =>
      alertService.detectCriticalRecords(records).length;

  AppUserRole get authRole => _authAppRole ?? AppUserRole.operario;

  bool get canCapture => _hasPermission(Permission.captureRecords);

  bool get canImportRecords => permissionsService.canImportRecords(_authAppRole);

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
    if (_authAppRole != null) {
      return RolePermissions.has(_authAppRole!, permission);
    }
    return _legacyPermission(permission);
  }

  bool _legacyPermission(Permission permission) {
    switch (permission) {
      case Permission.captureRecords:
        return permissionsService.canCaptureLegacy(userRole);
      case Permission.editRecords:
        return userRole.canDeleteRecords;
      case Permission.deleteRecords:
        return permissionsService.canDeleteRecordsLegacy(userRole);
      case Permission.clearAllRecords:
        return permissionsService.canClearAllRecordsLegacy(userRole);
      case Permission.applyCorrectiveAction:
        return permissionsService.canApplyCorrectiveActionLegacy(userRole);
      case Permission.manageFabrics:
        return permissionsService.canManageFabricsLegacy(userRole);
      case Permission.manageReports:
        return permissionsService.canManageReportsLegacy(userRole);
      case Permission.exportReports:
        return userRole.canExport;
      case Permission.editAlertConfig:
        return permissionsService.canEditAlertConfigLegacy(userRole);
      case Permission.manageSettings:
        return userRole.isAdmin;
      default:
        return false;
    }
  }

  void applyAuthProfile(AppUser user) {
    _authUid = user.uid;
    _authUsername = user.username.isNotEmpty ? user.username : user.effectiveDisplayName;
    _authAppRole = user.role;
    userRole = _mapAppUserRole(user.role);
    notifyListeners();
  }

  UserRole _mapAppUserRole(AppUserRole role) {
    switch (role) {
      case AppUserRole.superAdmin:
      case AppUserRole.admin:
        return UserRole.administrador;
      case AppUserRole.supervisor:
        return UserRole.supervisor;
      case AppUserRole.operario:
        return UserRole.operario;
      case AppUserRole.gerencia:
        return UserRole.gerencia;
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
    nepsController.addListener(notifyListeners);
    loteSuffixController.addListener(notifyListeners);
    loteFullController.addListener(_handleLoteFullChanged);
    lotePrefixController.addListener(notifyListeners);
    await alertConfigService.load();
    alertService.updateConfig(alertConfigService.config);
    await notificationPreferencesService.load();
    await loadData();
    if (launchUri != null) {
      await applyLaunchParameters(launchUri);
    }
  }

  /// Aplica parámetros de URL para Atajos de iOS / Siri Shortcuts.
  Future<void> applyLaunchParameters(Uri uri) async {
    final params = uri.queryParameters;
    if (params.isEmpty) return;

    final screenIndex = SiriShortcutService.resolveScreenIndex(
      SiriShortcutService.readParam(params, 'pantalla') ??
          SiriShortcutService.readParam(params, 'screen'),
    );
    if (screenIndex != null) {
      navigationIndex = screenIndex;
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
    _recordsSubscription?.cancel();
    _fabricsSubscription?.cancel();
    nepsController.removeListener(notifyListeners);
    loteSuffixController.removeListener(notifyListeners);
    loteFullController.removeListener(_handleLoteFullChanged);
    lotePrefixController.removeListener(notifyListeners);
    telarController.dispose();
    nepsController.dispose();
    lotePrefixController.dispose();
    loteSuffixController.dispose();
    loteFullController.dispose();
    manualTelaController.dispose();
    turnoController.dispose();
    operarioController.dispose();
    lineaProduccionController.dispose();
    observacionController.dispose();
    accionInmediataController.dispose();
    super.dispose();
  }

  void setNavigationIndex(int index) {
    navigationIndex = index;
    notifyListeners();
  }

  /// Navega a registros aplicando filtros relacionados con una alerta.
  void navigateToRecordsFiltered({
    String? telar,
    String? tela,
    String? loteTrama,
  }) {
    filters.clear();
    filters.telar = telar;
    filters.tela = tela;
    filters.loteTrama = loteTrama;
    filterPanelKey++;
    navigationIndex = 2;
    notifyListeners();
  }

  Future<void> loadData() async {
    isLoading = true;
    bootstrapError = null;
    notifyListeners();

    try {
      await _loadLocalData();
    } catch (error, stackTrace) {
      bootstrapError =
          'No se pudieron cargar los datos guardados. Verifique el almacenamiento local.';
      debugPrint('Error al cargar datos locales: $error');
      debugPrint('$stackTrace');
    }

    isLoading = false;
    notifyListeners();

    if (cloudSyncService != null) {
      unawaited(_connectCloudInBackground());
    }
  }

  Future<void> reloadData() => loadData();

  Future<List<SavedReport>> refreshReports() async {
    final cloud = cloudSyncService;
    if (cloud != null) {
      try {
        await cloud.bootstrap();
        cloudSyncEnabled = true;
        cloudSyncError = null;
        await reportStorageService.migrateLocalReportsIfNeeded();
        notifyListeners();
      } catch (error, stackTrace) {
        debugPrint('No se pudo preparar sync de informes: $error');
        debugPrint('$stackTrace');
      }
    }
    return reportStorageService.loadReports();
  }

  Future<void> enableCloudSyncIfAvailable() async {
    if (cloudSyncService != null) return;

    try {
      cloudSyncService = CloudSyncService();
      reportStorageService.attachCloudSync(cloudSyncService);
      await _connectCloudInBackground();
    } catch (error, stackTrace) {
      cloudSyncService = null;
      reportStorageService.attachCloudSync(null);
      cloudSyncEnabled = false;
      debugPrint('Sincronizacion en la nube no disponible: $error');
      debugPrint('$stackTrace');
    }
  }

  Future<void> _connectCloudInBackground() async {
    try {
      await _loadCloudData();
    } catch (error, stackTrace) {
      _markCloudUnavailable(error, stackTrace);
    }
  }

  Future<void> _loadLocalData() async {
    records = await _loadLocalRecords();
    fabrics = await fabricCatalogService.loadFabrics();
    loteCatalog = await loteTramaCatalogService.loadCatalog();
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

  /// Notifica cambios y persiste el último lote de trama escrito, de modo que
  /// la captura recuerde el valor entre sesiones.
  void _handleLoteFullChanged() {
    notifyListeners();
    if (_suppressLotePersist) return;
    unawaited(_saveLoteFull());
  }

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

  Future<List<NepRecord>> _loadLocalRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString(storageKey);
    if (savedData == null || savedData.isEmpty) return [];

    try {
      final List decoded = jsonDecode(savedData);
      return decoded
          .map((item) => NepRecord.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (error) {
      throw FormatException('Datos locales corruptos: $error');
    }
  }

  Future<void> _loadCloudData() async {
    final cloud = cloudSyncService!;
    try {
      await cloud.bootstrap();
      cloudSyncEnabled = true;
      cloudSyncError = null;
    } catch (error, stackTrace) {
      _markCloudUnavailable(error, stackTrace);
      return;
    }

    final localRecords = await _loadLocalRecords();
    final localFabrics = await fabricCatalogService.loadFabrics();

    try {
      await cloud.migrateLocalDataIfNeeded(
        localRecords: localRecords,
        localFabrics: localFabrics,
      );
    } catch (error, stackTrace) {
      debugPrint('Migración local parcial omitida: $error');
      debugPrint('$stackTrace');
    }

    try {
      await reportStorageService.migrateLocalReportsIfNeeded();
    } catch (error, stackTrace) {
      debugPrint('Migración de informes omitida: $error');
      debugPrint('$stackTrace');
    }

    try {
      await cloud.syncFabricsWithLocal(localFabrics);
    } catch (error, stackTrace) {
      debugPrint('Sync de telas omitida: $error');
      debugPrint('$stackTrace');
    }

    await _refreshUserRoleAndConfig();

    try {
      await _bindCloudSubscriptions(waitForFirstSnapshot: true);
    } catch (error, stackTrace) {
      debugPrint('Suscripciones en la nube parciales: $error');
      debugPrint('$stackTrace');
    }

    notifyListeners();
  }

  Future<void> _refreshUserRoleAndConfig() async {
    final cloud = cloudSyncService;
    if (cloud == null) return;

    try {
      if (_authAppRole == null) {
        userRole = await cloud.fetchUserRole();
      }
      final remoteConfig = await cloud.fetchAlertConfig();
      if (remoteConfig != null) {
        alertConfigService.applyFromFirestore(remoteConfig);
        alertService.updateConfig(alertConfigService.config);
      }
      notifyListeners();
    } catch (error) {
      debugPrint('No se pudo cargar rol/config remota: $error');
    }
  }

  Future<void> initializeNotifications() async {
    await notificationService.initialize(
      onTokenRegistered: (token) async {
        if (cloudSyncService == null || !cloudSyncEnabled) return;
        try {
          await cloudSyncService!.registerFcmToken(token);
        } catch (error) {
          debugPrint('No se pudo registrar token FCM: $error');
        }
      },
    );
  }

  Future<void> _bindCloudSubscriptions({
    required bool waitForFirstSnapshot,
  }) async {
    final cloud = cloudSyncService!;
    final recordsReady = Completer<void>();
    final fabricsReady = Completer<void>();

    _recordsSubscription?.cancel();
    _fabricsSubscription?.cancel();

    _recordsSubscription = cloud.watchRecords().listen(
      (data) {
        records = data;
        unawaited(_cacheRecordsLocally(data));
        if (!recordsReady.isCompleted) recordsReady.complete();
        notifyListeners();
      },
      onError: (error) {
        if (!recordsReady.isCompleted) recordsReady.completeError(error);
      },
    );

    _fabricsSubscription = cloud.watchFabrics().listen(
      (data) {
        fabrics = data;
        _syncFabricSelection();
        unawaited(_cacheFabricsLocally(data));
        if (!fabricsReady.isCompleted) fabricsReady.complete();
        notifyListeners();
      },
      onError: (error) {
        if (!fabricsReady.isCompleted) fabricsReady.completeError(error);
      },
    );

    if (waitForFirstSnapshot) {
      try {
        await Future.wait([
          recordsReady.future,
          fabricsReady.future,
        ]).timeout(const Duration(seconds: 15));
      } on TimeoutException {
        if (!recordsReady.isCompleted) recordsReady.complete();
        if (!fabricsReady.isCompleted) fabricsReady.complete();
      }
    }
  }

  Future<bool> _ensureCloudReady() async {
    if (cloudSyncService == null) return false;

    try {
      await cloudSyncService!.bootstrap();
      cloudSyncEnabled = true;

      if (_fabricsSubscription == null || _recordsSubscription == null) {
        await _bindCloudSubscriptions(waitForFirstSnapshot: false);
      }

      return true;
    } catch (error, stackTrace) {
      _markCloudUnavailable(error, stackTrace);
      return false;
    }
  }

  void _markCloudUnavailable(Object error, StackTrace stackTrace) {
    cloudSyncEnabled = false;
    cloudSyncError = error.toString();
    debugPrint('Sincronizacion en la nube no disponible: $error');
    debugPrint('$stackTrace');
    notifyListeners();
  }

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

  Future<void> reconnectCloudIfNeeded() async {
    if (cloudSyncService == null || cloudSyncEnabled) return;

    try {
      await _connectCloudInBackground();
      cloudSyncError = null;
      notifyListeners();
    } catch (error, stackTrace) {
      _markCloudUnavailable(error, stackTrace);
    }
  }

  Future<void> _cacheRecordsLocally(List<NepRecord> data) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(data.map((record) => record.toJson()).toList());
    await prefs.setString(storageKey, encoded);
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
    if (!_requirePermission(canManageFabrics, 'administrar el catálogo de telas')) {
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

    if (await _ensureCloudReady()) {
      try {
        final saved = await cloudSyncService!.saveFabrics(normalized);
        await _cacheFabricsLocally(saved);

        if (_fabricsSubscription == null) {
          fabrics = saved;
          _syncFabricSelection();
          notifyListeners();
        }

        showMessage('Catalogo de telas guardado en Firebase.');
        return;
      } catch (error) {
        debugPrint('No se pudo guardar telas en Firebase: $error');
        if (error.toString().contains('permission-denied')) {
          cloudSyncError = null;
        }
      }
    }

    showMessage('Catalogo de telas actualizado localmente.');
  }

  Future<void> saveData() async {
    if (cloudSyncService != null && await _ensureCloudReady()) {
      try {
        await cloudSyncService!.replaceRecords(records);
        return;
      } catch (_) {
        cloudSyncEnabled = false;
      }
    }

    await _cacheRecordsLocally(records);
  }

  Future<void> _persistRecord(NepRecord record) async {
    if (cloudSyncService != null && await _ensureCloudReady()) {
      try {
        await cloudSyncService!.upsertRecord(record);
        if (_recordsSubscription == null) {
          records = [...records, record];
          await _cacheRecordsLocally(records);
          notifyListeners();
        }
        return;
      } catch (error) {
        cloudSyncEnabled = false;
        debugPrint('Error al guardar en Firebase: $error');
        showMessage(
          'No se pudo sincronizar con Firebase. Registro guardado localmente.',
        );
      }
    }

    records = [...records, record];
    await _cacheRecordsLocally(records);
    notifyListeners();
  }

  Future<void> _persistRecords(List<NepRecord> updatedRecords) async {
    if (cloudSyncService != null && await _ensureCloudReady()) {
      try {
        await cloudSyncService!.upsertRecords(updatedRecords);
        return;
      } catch (_) {
        cloudSyncEnabled = false;
      }
    }

    records.addAll(updatedRecords);
    await _cacheRecordsLocally(records);
    notifyListeners();
  }

  Future<void> _replaceAllRecords(List<NepRecord> updatedRecords) async {
    if (cloudSyncService != null && await _ensureCloudReady()) {
      try {
        await cloudSyncService!.replaceRecords(updatedRecords);
        return;
      } catch (_) {
        cloudSyncEnabled = false;
      }
    }

    records = updatedRecords;
    await _cacheRecordsLocally(records);
    notifyListeners();
  }

  Future<void> _removeRecord(String recordId) async {
    if (cloudSyncService != null && await _ensureCloudReady()) {
      try {
        await cloudSyncService!.deleteRecord(recordId);
        return;
      } catch (_) {
        cloudSyncEnabled = false;
      }
    }

    records.removeWhere((record) => record.id == recordId);
    await _cacheRecordsLocally(records);
    notifyListeners();
  }

  Future<void> _clearAllRecords() async {
    if (cloudSyncService != null && await _ensureCloudReady()) {
      try {
        await cloudSyncService!.clearRecords();
        return;
      } catch (_) {
        cloudSyncEnabled = false;
      }
    }

    records = [];
    await _cacheRecordsLocally(records);
    notifyListeners();
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
    filters.clear();
    filterPanelKey++;
    notifyListeners();
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
    } catch (e) {
      showMessage('Error al exportar: $e');
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
      await FileShareHelper.shareTextContent(
        content: reportExportService.buildCsvText(
          visibleRecords,
          columns: selected,
          style: reportStyle,
        ),
        fileName: 'reporte_neps_$timestamp.csv',
        mimeType: 'text/csv',
        shareText: 'Reporte CSV de Neps',
        bom: true,
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
      final bytes = reportExportService.buildExcelBytes(
        visibleRecords,
        columns: selected,
        style: reportStyle,
      );
      if (bytes == null) {
        showMessage('No se pudo generar el archivo Excel.');
        return;
      }
      await FileShareHelper.shareBytes(
        bytes: bytes,
        fileName: 'reporte_neps_$timestamp.xlsx',
        mimeType: FileShareHelper.excelMimeType,
        shareText: 'Reporte Excel de Neps',
      );
      showMessage('Reporte Excel listo para compartir o descargar.');
    });
  }

  Future<Uint8List> buildPdfBytes({
    Set<ExportColumn>? columns,
    PdfReportStyle? style,
  }) {
    final selected = columns ?? exportColumns;
    return reportExportService.buildPdfBytes(
      records: visibleRecords,
      columns: selected,
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
    await runExport(() async {
      final bytes = await buildPdfBytes(columns: columns, style: style);
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'reporte_neps_$timestamp.pdf',
      );
    });
  }

  Future<void> printPdf({PdfReportStyle? style}) async {
    await runExport(() async {
      await Printing.layoutPdf(
        name: 'Reporte Neps VICUNHA',
        onLayout: (_) async => buildPdfBytes(style: style),
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

    final text = reportExportService.buildTabText(
      visibleRecords,
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
    } catch (error) {
      debugPrint('Error al guardar informe: $error');
      showMessage('No se pudo guardar el informe. Intente nuevamente.');
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
    } catch (e) {
      showMessage('Error al importar registros: $e');
    }
  }

  Future<void> downloadImportTemplate() async {
    if (!_requirePermission(canImportRecords, 'descargar plantillas de importación')) {
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
    } catch (e) {
      showMessage('No se pudo generar la plantilla: $e');
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
    } catch (e) {
      showMessage('Error al importar registros: $e');
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
    if (!_requirePermission(canEditAlertConfig, 'modificar los límites de alerta')) {
      return;
    }

    await alertConfigService.save(config);
    alertService.updateConfig(config);

    if (cloudSyncService != null && await _ensureCloudReady()) {
      try {
        await cloudSyncService!.saveAlertConfig(
          alertConfigService.toFirestoreMap(),
        );
      } catch (error) {
        debugPrint('No se pudo sincronizar config a Firebase: $error');
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
    telarController.clear();
    nepsController.clear();
    turnoController.clear();
    operarioController.clear();
    lineaProduccionController.clear();
    observacionController.clear();
    accionInmediataController.clear();
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
    if (cloudSyncService != null && await _ensureCloudReady()) {
      try {
        await cloudSyncService!.upsertRecord(record);
        if (_recordsSubscription == null) {
          records = [
            for (final item in records)
              if (item.id == record.id) record else item,
          ];
          await _cacheRecordsLocally(records);
          notifyListeners();
        }
        return;
      } catch (error) {
        cloudSyncEnabled = false;
        debugPrint('Error al actualizar en Firebase: $error');
        showMessage(
          'No se pudo sincronizar con Firebase. Cambio guardado localmente.',
        );
      }
    }

    records = [
      for (final item in records)
        if (item.id == record.id) record else item,
    ];
    await _cacheRecordsLocally(records);
    notifyListeners();
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
    telarController.clear();
    nepsController.clear();
    if (!cloudSyncEnabled) {
      notifyListeners();
    }
    showMessage('Nueva sesion iniciada. Tabla vacia.');
  }

  void clearCaptureFields() {
    telarController.clear();
    nepsController.clear();
    turnoController.clear();
    operarioController.clear();
    lineaProduccionController.clear();
    observacionController.clear();
    accionInmediataController.clear();
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

  void onFiltersChanged() => notifyListeners();
}
