import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../models/export_column.dart';
import '../models/nep_record.dart';
import '../models/record_filters.dart';
import '../models/saved_report.dart';
import '../services/cloud_sync_port.dart';
import '../services/cloud_sync_service.dart';
import '../services/fabric_catalog_service.dart';
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
    return defaultTargetPlatform == TargetPlatform.android;
  }

  static bool _isRunningInWidgetTest() {
    return WidgetsBinding.instance.runtimeType
        .toString()
        .contains('TestWidgets');
  }

  factory AppState({
    FabricCatalogService? fabricCatalogService,
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
      recordImportService: recordImportService ?? RecordImportService(),
      reportStorageService:
          reportStorageService ?? ReportStorageService(cloudSync: syncService),
      reportExportService: reportExportService ?? ReportExportService(),
    );
  }

  AppState._({
    this.cloudSyncService,
    required this.fabricCatalogService,
    required this.recordImportService,
    required this.reportStorageService,
    required this.reportExportService,
  });

  CloudSyncPort? cloudSyncService;
  final FabricCatalogService fabricCatalogService;
  final RecordImportService recordImportService;
  final ReportStorageService reportStorageService;
  final ReportExportService reportExportService;

  bool cloudSyncEnabled = false;
  String? cloudSyncError;
  StreamSubscription<List<NepRecord>>? _recordsSubscription;
  StreamSubscription<List<String>>? _fabricsSubscription;

  final RecordFilters filters = RecordFilters();
  final TextEditingController telarController = TextEditingController();
  final TextEditingController nepsController = TextEditingController();
  final TextEditingController lotePrefixController =
      TextEditingController(text: loteTramaPrefix);
  final TextEditingController loteSuffixController = TextEditingController();
  final TextEditingController loteFullController = TextEditingController();
  final TextEditingController manualTelaController = TextEditingController();
  bool loteFullEntryMode = false;

  List<NepRecord> records = [];
  List<String> fabrics = [];
  String? selectedFabric;
  bool useManualFabric = false;
  bool isLoading = true;
  bool isExporting = false;
  int filterPanelKey = 0;
  int navigationIndex = 0;
  Set<ExportColumn> exportColumns = ExportColumn.defaultSelection();

  List<NepRecord> get visibleRecords =>
      RecordFilterHelper.apply(records, filters);

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
    loteFullController.addListener(notifyListeners);
    lotePrefixController.addListener(notifyListeners);
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
    loteFullController.removeListener(notifyListeners);
    lotePrefixController.removeListener(notifyListeners);
    telarController.dispose();
    nepsController.dispose();
    lotePrefixController.dispose();
    loteSuffixController.dispose();
    loteFullController.dispose();
    manualTelaController.dispose();
    super.dispose();
  }

  void setNavigationIndex(int index) {
    navigationIndex = index;
    notifyListeners();
  }

  Future<void> loadData() async {
    isLoading = true;
    notifyListeners();

    await _loadLocalData();

    isLoading = false;
    notifyListeners();

    if (cloudSyncService != null) {
      unawaited(_connectCloudInBackground());
    }
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
    await _loadLotePreferences();
    _syncFabricSelection();
  }

  Future<void> _loadLotePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPrefix = prefs.getString(loteTramaPrefixStorageKey);
    if (savedPrefix != null && savedPrefix.trim().isNotEmpty) {
      lotePrefixController.text = LoteTramaHelper.normalizePrefix(savedPrefix);
    }
    loteFullEntryMode = prefs.getBool(loteTramaFullEntryStorageKey) ?? false;
  }

  Future<void> _saveLotePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      loteTramaPrefixStorageKey,
      LoteTramaHelper.normalizePrefix(lotePrefixController.text),
    );
    await prefs.setBool(loteTramaFullEntryStorageKey, loteFullEntryMode);
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
    if (loteFullEntryMode) {
      final full = LoteTramaHelper.normalizeFull(loteFullController.text);
      if (!LoteTramaHelper.isValidFull(full)) return null;
      return full;
    }

    if (!LoteTramaHelper.isValidParts(
      prefix: lotePrefixController.text,
      suffix: loteSuffixController.text,
    )) {
      return null;
    }

    return LoteTramaHelper.buildFull(
      prefix: lotePrefixController.text,
      suffix: loteSuffixController.text,
    );
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
    } catch (_) {
      return [];
    }
  }

  Future<void> _loadCloudData() async {
    final cloud = cloudSyncService!;
    await cloud.bootstrap();
    cloudSyncEnabled = true;

    final localRecords = await _loadLocalRecords();
    final localFabrics = await fabricCatalogService.loadFabrics();
    await cloud.migrateLocalDataIfNeeded(
      localRecords: localRecords,
      localFabrics: localFabrics,
    );
    await cloud.syncFabricsWithLocal(localFabrics);

    await _bindCloudSubscriptions(waitForFirstSnapshot: true);
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
    showMessage('Firebase no disponible: ${_shortCloudError(error)}');
    notifyListeners();
  }

  String _shortCloudError(Object error) {
    final message = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (message.length <= 140) return message;
    return '${message.substring(0, 137)}...';
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
    final normalized = fabricCatalogService.mergeFabrics([], updated);

    if (cloudSyncService != null && await _ensureCloudReady()) {
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
      } catch (_) {
        cloudSyncEnabled = false;
      }
    }

    await fabricCatalogService.saveFabrics(normalized);
    fabrics = normalized;
    _syncFabricSelection();
    notifyListeners();
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

  Future<void> exportCsv({Set<ExportColumn>? columns}) async {
    final selected = columns ?? exportColumns;
    await runExport(() async {
      await FileShareHelper.shareTextContent(
        content: reportExportService.buildCsvText(
          visibleRecords,
          columns: selected,
        ),
        fileName: 'reporte_neps_$timestamp.csv',
        mimeType: 'text/csv',
        shareText: 'Reporte CSV de Neps',
        bom: true,
      );
      showMessage('Reporte CSV listo para compartir o descargar.');
    });
  }

  Future<void> exportExcel({Set<ExportColumn>? columns}) async {
    final selected = columns ?? exportColumns;
    await runExport(() async {
      final bytes = reportExportService.buildExcelBytes(
        visibleRecords,
        columns: selected,
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

  Future<Uint8List> buildPdfBytes({Set<ExportColumn>? columns}) {
    final selected = columns ?? exportColumns;
    return reportExportService.buildPdfBytes(
      records: visibleRecords,
      columns: selected,
      filtersDescription: filters.hasActiveFilters
          ? FilterDescriptionHelper.describe(filters)
          : null,
    );
  }

  Future<void> exportPdf({Set<ExportColumn>? columns}) async {
    await runExport(() async {
      final bytes = await buildPdfBytes(columns: columns);
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'reporte_neps_$timestamp.pdf',
      );
    });
  }

  Future<void> printPdf() async {
    await runExport(() async {
      await Printing.layoutPdf(
        name: 'Reporte Neps VICUNHA',
        onLayout: (_) async => buildPdfBytes(),
      );
    });
  }

  Future<void> copyTable({Set<ExportColumn>? columns}) async {
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
    final loadedRecords = report.records
        .map(
          (record) => NepRecord(
            id: record.id,
            telar: record.telar,
            neps: record.neps,
            tela: record.tela,
            loteTrama: record.loteTrama,
            createdAt: record.createdAt,
          ),
        )
        .toList();

    if (report.appliedFilters != null) {
      filters
        ..tela = report.appliedFilters!.tela
        ..loteTrama = report.appliedFilters!.loteTrama
        ..telar = report.appliedFilters!.telar
        ..nepsMin = report.appliedFilters!.nepsMin
        ..nepsMax = report.appliedFilters!.nepsMax
        ..mtsMin = report.appliedFilters!.mtsMin
        ..mtsMax = report.appliedFilters!.mtsMax
        ..dateFrom = report.appliedFilters!.dateFrom
        ..dateTo = report.appliedFilters!.dateTo
        ..searchText = report.appliedFilters!.searchText;
      filterPanelKey++;
    }

    await _replaceAllRecords(loadedRecords);
    navigationIndex = 2;
    if (!cloudSyncEnabled) {
      notifyListeners();
    }
    showMessage('Informe "${report.name}" cargado en registros.');
  }

  Future<void> importRecords({
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      final result = recordImportService.importFromBytes(
        bytes,
        fileName: fileName,
      );

      if (!result.hasRecords) {
        showMessage(
          result.message ??
              'No se encontraron registros validos en el archivo.',
        );
        return;
      }

      await _persistRecords(result.records);
      await _mergeImportedFabrics(result.records);
      if (!cloudSyncEnabled) {
        notifyListeners();
      }

      if (result.skippedRows > 0) {
        showMessage(
          'Se importaron ${result.records.length} registros. '
          '${result.skippedRows} filas fueron omitidas.',
        );
      } else {
        showMessage(
          'Se importaron ${result.records.length} registros correctamente.',
        );
      }
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

  Future<void> addRecord() async {
    final telar = telarController.text.trim();
    final nepsText = nepsController.text.trim();
    final tela = resolveSelectedTela();

    if (tela == null) {
      showMessage('Seleccione o ingrese la tela.');
      return;
    }

    final loteTrama = resolveLoteTramaForSave();
    if (loteTrama == null) {
      showMessage(
          'Complete el lote de trama (base y sufijo, o lote completo).');
      return;
    }

    if (telar.isEmpty) {
      showMessage('Ingrese el numero de telar.');
      return;
    }

    if (nepsText.isEmpty || parseNumber(nepsText) <= 0) {
      showMessage('Ingrese una cantidad valida de neps.');
      return;
    }

    final record = NepRecord(
      telar: telar,
      neps: parseNumber(nepsText),
      tela: tela,
      loteTrama: loteTrama,
    );

    await _persistRecord(record);
    telarController.clear();
    nepsController.clear();
    if (!loteFullEntryMode) {
      loteSuffixController.clear();
    } else {
      loteFullController.clear();
    }
    if (!cloudSyncEnabled) {
      notifyListeners();
    }
    showMessage('Registro agregado correctamente.');
  }

  Future<void> updateRecord({
    required String id,
    required String telar,
    required double neps,
    required String tela,
    required String loteTrama,
  }) async {
    final index = records.indexWhere((record) => record.id == id);
    if (index < 0) {
      showMessage('Registro no encontrado.');
      return;
    }

    final updated = NepRecord(
      id: id,
      telar: telar.trim(),
      neps: neps,
      tela: tela.trim(),
      loteTrama: loteTrama,
      createdAt: DateTime.now(),
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
    await _removeRecord(recordId);
    if (!cloudSyncEnabled) {
      notifyListeners();
    }
  }

  Future<void> clearTable() async {
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
