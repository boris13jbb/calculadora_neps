import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../core/errors/error_handler.dart';
import '../core/permissions/report_visibility.dart';
import '../models/nep_record.dart';
import '../models/pdf_report_style.dart';
import '../models/pending_report_sync_op.dart';
import '../models/record_filters.dart';
import '../models/report_list_metrics.dart';
import '../models/report_save_outcome.dart';
import '../models/report_summaries_load_result.dart';
import '../models/report_sync_status.dart';
import '../models/reports_load_result.dart';
import '../models/saved_report.dart';
import '../models/saved_report_summary.dart';
import '../utils/firebase_session_helper.dart';
import '../utils/report_content_fingerprint.dart';
import '../utils/report_sync_error_classifier.dart';
import '../utils/report_upsert_decision.dart';
import '../utils/stable_id.dart';
import 'cloud_sync_port.dart';
import 'pending_report_sync_queue_service.dart';
import 'report_export_service.dart';
import 'report_sync_meta_store.dart';

class ReportStorageService {
  ReportStorageService({
    CloudSyncPort? cloudSync,
    ReportExportService? exportService,
    PendingReportSyncQueueService? pendingReportQueue,
    ReportSyncMetaStore? syncMetaStore,
    bool Function()? isSessionActive,
  })  : _cloudSync = cloudSync,
        _pendingReportQueue =
            pendingReportQueue ?? pendingReportSyncQueueService,
        _syncMeta = syncMetaStore ?? reportSyncMetaStore,
        _isSessionActive = isSessionActive ?? (() => isFirebaseSessionActive),
        exportService = exportService ?? ReportExportService();

  CloudSyncPort? _cloudSync;
  final PendingReportSyncQueueService _pendingReportQueue;
  final ReportSyncMetaStore _syncMeta;
  final bool Function() _isSessionActive;
  final ReportExportService exportService;
  bool _flushingPendingReports = false;

  void attachCloudSync(CloudSyncPort? cloudSync) {
    _cloudSync = cloudSync;
  }

  PendingReportSyncQueueService get pendingReportQueue => _pendingReportQueue;

  bool get _sessionActive => _isSessionActive();

  /// Carga informes. Persiste el merge completo por id; filtra solo la vista.
  /// No oculta fallos: si hay datos parciales, [ReportsLoadResult.isPartial] es true.
  Future<ReportsLoadResult> loadReportsResult({
    String? viewerUid,
    bool canViewTeamReports = false,
    bool fetchCloud = true,
  }) async {
    final localParse = await _loadReportsLocallyDetailed();
    var merged = localParse.reports;
    var skipped = localParse.skippedCount;
    String? cloudError;
    var isPartial = localParse.skippedCount > 0;

    final cloudSync = _cloudSync;
    final shouldFetchCloud = fetchCloud && cloudSync != null && _sessionActive;

    if (shouldFetchCloud) {
      try {
        await cloudSync.bootstrap();
        await migrateLocalReportsIfNeeded();
        final remote = await cloudSync.fetchReports();
        merged = _mergeReports(localParse.reports, remote);
        await _persistReportsLocally(merged);
      } catch (error, stackTrace) {
        cloudError = ErrorHandler.userMessage(error);
        ErrorHandler.log(error, stackTrace, 'loadReportsFirebase');
        isPartial = true;
        merged = localParse.reports;
        if (merged.isEmpty) {
          return ReportsLoadResult(
            reports: const [],
            skippedCount: skipped,
            cloudError: cloudError,
            isPartial: true,
          );
        }
      }
    }

    final visible = viewerUid == null
        ? merged
        : filterVisibleReports(
            merged,
            viewerUid: viewerUid,
            canViewTeamReports: canViewTeamReports,
          );

    return ReportsLoadResult(
      reports: visible,
      skippedCount: skipped,
      cloudError: cloudError,
      isPartial: isPartial || cloudError != null,
    );
  }

  Future<List<SavedReport>> loadReports({
    String? viewerUid,
    bool canViewTeamReports = false,
  }) async {
    final result = await loadReportsResult(
      viewerUid: viewerUid,
      canViewTeamReports: canViewTeamReports,
    );
    if (result.reports.isEmpty && result.cloudError != null) {
      throw StateError(result.cloudError!);
    }
    return result.reports;
  }

  /// Listado liviano PR2: cloud summaries + puente sintético local.
  ///
  /// **No** llama a [CloudSyncPort.fetchReports] (evita descargar todos los
  /// `records[]` solo para pintar la lista).
  Future<ReportSummariesLoadResult> loadReportSummariesResult({
    String? viewerUid,
    bool canViewTeamReports = false,
    bool fetchCloud = true,
    /// Si false, no intenta cloud (evita permission-denied ruidoso en Analíticas).
    bool canReadCloudReports = true,
  }) async {
    final started = DateTime.now();
    final localParse = await _loadReportsLocallyDetailed();
    var cloudSummaries = <SavedReportSummary>[];
    String? cloudError;
    var isPartial = localParse.skippedCount > 0;
    var cloudSummaryDocs = 0;

    final cloudSync = _cloudSync;
    final shouldFetchCloud = fetchCloud &&
        canReadCloudReports &&
        cloudSync != null &&
        _sessionActive;

    if (shouldFetchCloud) {
      try {
        await cloudSync.bootstrap();
        cloudSummaries = await cloudSync.fetchReportSummaries();
        cloudSummaryDocs = cloudSummaries.length;
      } catch (error, stackTrace) {
        cloudError = ErrorHandler.userMessage(error);
        ErrorHandler.log(error, stackTrace, 'loadReportSummariesFirebase');
        isPartial = true;
      }
    }

    final byId = <String, SavedReportSummary>{
      for (final summary in cloudSummaries) summary.id: summary,
    };

    var localSynthetic = 0;
    for (final report in localParse.reports) {
      if (byId.containsKey(report.id)) continue;
      byId[report.id] = SavedReportSummary.fromSavedReport(report);
      localSynthetic++;
    }

    var merged = byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final visible = viewerUid == null
        ? merged
        : filterVisibleReportSummariesByOwner(
            merged,
            viewerUid: viewerUid,
            canViewTeamReports: canViewTeamReports,
          );

    final metrics = ReportListMetrics(
      listLoadDuration: DateTime.now().difference(started),
      cloudSummaryDocs: cloudSummaryDocs,
      localSyntheticSummaries: localSynthetic,
      cloudFullFetches: 0,
      cloudRecordsDeserializedOnList: 0,
      localBridgeReportsRead: localParse.reports.length,
      usedFetchReportsForList: false,
    );

    return ReportSummariesLoadResult(
      summaries: visible,
      metrics: metrics,
      skippedCount: localParse.skippedCount,
      cloudError: cloudError,
      isPartial: isPartial || cloudError != null,
    );
  }

  /// Resuelve un informe completo: cache local primero, luego cloud por id.
  Future<SavedReport?> resolveFullReport(String id) async {
    final reportId = id.trim();
    if (reportId.isEmpty) return null;

    final local = await _loadReportsLocally();
    for (final report in local) {
      if (report.id == reportId) return report;
    }

    final cloudSync = _cloudSync;
    if (cloudSync == null || !_sessionActive) return null;

    try {
      await cloudSync.bootstrap();
      final remote = await cloudSync.fetchReportById(reportId);
      if (remote != null) {
        await _upsertReportLocally(remote);
      }
      return remote;
    } catch (error, stackTrace) {
      ErrorHandler.log(error, stackTrace, 'resolveFullReport');
      return null;
    }
  }

  /// Fulls locales indexados por id (para filtros de contenido sin fetch masivo).
  Future<Map<String, SavedReport>> loadLocalReportsById() async {
    final local = await _loadReportsLocally();
    return {for (final report in local) report.id: report};
  }

  /// Sube informes locales a Firestore la primera vez que hay nube disponible.
  Future<void> migrateLocalReportsIfNeeded() async {
    final cloudSync = _cloudSync;
    if (cloudSync == null) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(cloudReportsMigrationKey) == true) return;

    final local = await _loadReportsLocally();
    if (local.isEmpty) {
      await prefs.setBool(cloudReportsMigrationKey, true);
      return;
    }

    for (final report in local) {
      try {
        await cloudSync.saveReport(report);
      } catch (error, stackTrace) {
        ErrorHandler.log(error, stackTrace, 'migrateReport');
        return;
      }
    }

    await prefs.setBool(cloudReportsMigrationKey, true);
  }

  List<SavedReport> _mergeReports(
    List<SavedReport> local,
    List<SavedReport> remote,
  ) {
    final byId = <String, SavedReport>{};
    for (final report in local) {
      byId[report.id] = report;
    }
    for (final report in remote) {
      final existing = byId[report.id];
      if (existing == null || !report.createdAt.isBefore(existing.createdAt)) {
        byId[report.id] = report;
      }
    }

    final merged = byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }

  Future<List<SavedReport>> _loadReportsLocally() async {
    final detailed = await _loadReportsLocallyDetailed();
    return detailed.reports;
  }

  Future<({List<SavedReport> reports, int skippedCount})>
      _loadReportsLocallyDetailed() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(savedReportsStorageKey);
    if (saved == null || saved.isEmpty) {
      return (reports: <SavedReport>[], skippedCount: 0);
    }

    try {
      final decoded = jsonDecode(saved);
      if (decoded is! List) {
        ErrorHandler.log(
          StateError('vicunha_saved_reports_v1 no es una lista'),
          StackTrace.current,
          'loadReportsLocally',
        );
        return (reports: <SavedReport>[], skippedCount: 0);
      }
      return _parseReportList(decoded, sourceLabel: 'localReports');
    } catch (error, stackTrace) {
      ErrorHandler.log(error, stackTrace, 'loadReportsLocally');
      return (reports: <SavedReport>[], skippedCount: 0);
    }
  }

  ({List<SavedReport> reports, int skippedCount}) _parseReportList(
    List<dynamic> raw, {
    required String sourceLabel,
  }) {
    final reports = <SavedReport>[];
    var skipped = 0;
    for (final item in raw) {
      if (item is! Map) {
        skipped++;
        continue;
      }
      final parsed = SavedReport.tryFromJson(Map<String, dynamic>.from(item));
      if (parsed == null) {
        skipped++;
        ErrorHandler.log(
          StateError('Informe omitido en $sourceLabel (formato inválido)'),
          StackTrace.current,
          sourceLabel,
        );
        continue;
      }
      reports.add(parsed);
    }
    reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return (reports: reports, skippedCount: skipped);
  }

  Future<void> _persistReportsLocally(List<SavedReport> reports) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded =
        jsonEncode(reports.map((report) => report.toJson()).toList());
    final ok = await prefs.setString(savedReportsStorageKey, encoded);
    if (!ok) {
      throw StateError('No se pudo persistir informes locales');
    }
    final readBack = prefs.getString(savedReportsStorageKey);
    if (readBack != encoded) {
      throw StateError('Verificación de informes locales falló tras escribir');
    }
  }

  Future<void> _upsertReportLocally(SavedReport report) async {
    final reports = await _loadReportsLocally();
    reports.removeWhere((item) => item.id == report.id);
    reports.insert(0, report);
    await _persistReportsLocally(reports);
  }

  Future<void> _removeReportLocally(String id) async {
    final reports = await _loadReportsLocally();
    reports.removeWhere((report) => report.id == id);
    await _persistReportsLocally(reports);
  }

  Future<ReportSaveOutcome> saveReport({
    required String name,
    required List<NepRecord> records,
    RecordFilters? appliedFilters,
    bool saveFiles = true,
    PdfReportStyle exportStyle = PdfReportStyle.completo,
    String? createdByUid,
  }) async {
    final report = SavedReport(
      id: generateStableId(prefix: 'rep'),
      name: name.trim(),
      createdAt: DateTime.now(),
      records:
          records.map((record) => NepRecord.fromJson(record.toJson())).toList(),
      appliedFilters: appliedFilters?.copy(),
      createdByUid: createdByUid,
    );

    return saveExistingReport(
      report,
      saveFiles: saveFiles,
      exportStyle: exportStyle,
    );
  }

  /// Guarda o actualiza un informe con id estable (reintentos sin duplicar).
  ///
  /// Solo marca [ReportSyncStatus.synced] tras confirmación cloud del dual-write.
  Future<ReportSaveOutcome> saveExistingReport(
    SavedReport report, {
    bool saveFiles = true,
    PdfReportStyle exportStyle = PdfReportStyle.completo,
    String? actorUid,
  }) async {
    final ownerUid = (actorUid ?? report.createdByUid)?.trim() ?? '';
    final existingPending = ownerUid.isEmpty
        ? null
        : await _pendingReportQueue.findByReportId(ownerUid, report.id);
    final lastSynced = ownerUid.isEmpty
        ? null
        : await _syncMeta.lastSyncedFingerprint(ownerUid, report.id);
    // Base = versión remota conocida (pending.base o última sync), NUNCA el
    // fingerprint del payload local pendiente.
    final baseFingerprint =
        existingPending?.baseFingerprint ?? lastSynced;

    // Siempre persistir local primero (incluye intención de sync).
    await _upsertReportLocally(report);
    if (saveFiles && !kIsWeb) {
      try {
        await _saveReportFiles(report, exportStyle: exportStyle);
      } catch (error, stackTrace) {
        ErrorHandler.log(error, stackTrace, 'saveReportFiles');
      }
    }

    final cloudSync = _cloudSync;
    final canAttemptCloud = cloudSync != null && _sessionActive;

    if (!canAttemptCloud) {
      try {
        final pending = ownerUid.isEmpty
            ? null
            : await _pendingReportQueue.enqueueUpsert(
                uid: ownerUid,
                report: report,
                baseFingerprint: baseFingerprint,
                status: ReportSyncStatus.localPending,
              );
        return ReportSaveOutcome(
          report: report,
          status: ReportSyncStatus.localPending,
          userMessage: ReportSyncUserMessages.forStatus(
            ReportSyncStatus.localPending,
            offlineHint: true,
          ),
          pendingOp: pending,
          offlineHint: true,
        );
      } catch (error, stackTrace) {
        ErrorHandler.log(error, stackTrace, 'enqueuePendingReport');
        return ReportSaveOutcome(
          report: report,
          status: ReportSyncStatus.retryableError,
          userMessage: ReportSyncUserMessages.retryableError,
          errorCode: 'local_persist_failed',
          offlineHint: true,
        );
      }
    }

    try {
      final saved = await cloudSync.saveReport(
        report,
        expectedBaseFingerprint: baseFingerprint,
      );
      await _upsertReportLocally(saved);
      if (ownerUid.isNotEmpty) {
        await _pendingReportQueue.removeByReportId(ownerUid, saved.id);
        await _syncMeta.setLastSyncedFingerprint(
          uid: ownerUid,
          reportId: saved.id,
          fingerprint: reportContentFingerprint(saved),
        );
      }
      return ReportSaveOutcome(
        report: saved,
        status: ReportSyncStatus.synced,
        userMessage: ReportSyncUserMessages.synced,
      );
    } on ReportSyncConflictException catch (error) {
      PendingReportSyncOp? pending;
      try {
        pending = ownerUid.isEmpty
            ? null
            : await _pendingReportQueue.enqueueUpsert(
                uid: ownerUid,
                report: report,
                baseFingerprint: baseFingerprint,
                status: ReportSyncStatus.conflict,
                errorCode: 'conflict',
              );
      } catch (persistError, persistStack) {
        ErrorHandler.log(persistError, persistStack, 'enqueueConflictPending');
      }
      ErrorHandler.log(error, StackTrace.current, 'saveReportConflict');
      return ReportSaveOutcome(
        report: report,
        status: ReportSyncStatus.conflict,
        userMessage: ReportSyncUserMessages.conflict,
        errorCode: 'conflict',
        pendingOp: pending,
      );
    } catch (error, stackTrace) {
      ErrorHandler.log(error, stackTrace, 'saveReportFirebase');
      final classified = classifyReportSyncError(error);
      PendingReportSyncOp? pending;
      try {
        pending = ownerUid.isEmpty
            ? null
            : await _pendingReportQueue.enqueueUpsert(
                uid: ownerUid,
                report: report,
                baseFingerprint: baseFingerprint,
                status: classified.status,
                errorCode: classified.code,
              );
      } catch (persistError, persistStack) {
        ErrorHandler.log(persistError, persistStack, 'enqueueErrorPending');
      }
      return ReportSaveOutcome(
        report: report,
        status: classified.status,
        userMessage: ReportSyncUserMessages.forStatus(classified.status),
        errorCode: classified.code,
        pendingOp: pending,
        offlineHint: classified.status == ReportSyncStatus.retryableError,
      );
    }
  }

  /// Reintenta un informe pendiente conservando el ID original.
  Future<ReportSaveOutcome?> retryPendingReport({
    required String uid,
    required String reportId,
  }) async {
    final owner = uid.trim();
    final id = reportId.trim();
    if (owner.isEmpty || id.isEmpty) return null;

    final pending = await _pendingReportQueue.findByReportId(owner, id);
    final report = pending?.report;
    if (pending == null || report == null) {
      final local = await _loadReportsLocally();
      SavedReport? found;
      for (final item in local) {
        if (item.id == id) {
          found = item;
          break;
        }
      }
      if (found == null) return null;
      return saveExistingReport(found, saveFiles: false, actorUid: owner);
    }

    if (pending.status == ReportSyncStatus.conflict) {
      // Reintento manual de conflicto: re-evalúa remoto sin sobrescribir a ciegas.
      return saveExistingReport(
        report,
        saveFiles: false,
        actorUid: owner,
      );
    }

    await _pendingReportQueue.upsertOp(
      owner,
      pending.copyWith(
        status: ReportSyncStatus.syncing,
        lastAttemptAt: DateTime.now(),
        attempts: pending.attempts + 1,
        clearErrorCode: true,
      ),
    );

    return saveExistingReport(
      report,
      saveFiles: false,
      actorUid: owner,
    );
  }

  /// Procesa pendientes del [uid] (sin solaparse con otro flush).
  Future<List<ReportSaveOutcome>> flushPendingReports({
    required String uid,
    bool Function()? isCurrent,
  }) async {
    final owner = uid.trim();
    if (owner.isEmpty) return const [];
    if (_flushingPendingReports) return const [];
    if (_cloudSync == null || !_sessionActive) return const [];

    _flushingPendingReports = true;
    final outcomes = <ReportSaveOutcome>[];
    try {
      final pending = await _pendingReportQueue.loadForUid(owner);
      for (final op in pending) {
        if (isCurrent != null && !isCurrent()) break;
        if (op.ownerUid != owner) continue;
        if (op.workspaceId != cloudWorkspaceId) continue;
        if (!op.canAutoRetry) continue;
        if (op.type != PendingReportSyncOpType.upsert || op.report == null) {
          continue;
        }

        await _pendingReportQueue.upsertOp(
          owner,
          op.copyWith(
            status: ReportSyncStatus.syncing,
            lastAttemptAt: DateTime.now(),
            attempts: op.attempts + 1,
          ),
        );

        final outcome = await saveExistingReport(
          op.report!,
          saveFiles: false,
          actorUid: owner,
        );
        outcomes.add(outcome);
      }
      return outcomes;
    } finally {
      _flushingPendingReports = false;
    }
  }

  Future<Map<String, ReportSyncStatus>> pendingReportStatusesForUid(
    String uid,
  ) {
    return _pendingReportQueue.statusByReportId(uid);
  }

  Future<void> deleteReport(String id, {String? actorUid}) async {
    final reportId = id.trim();
    if (reportId.isEmpty) return;

    final cloudSync = _cloudSync;
    if (cloudSync != null && _sessionActive) {
      try {
        await cloudSync.deleteReport(reportId);
        await _removeReportLocally(reportId);
        final uid = actorUid?.trim();
        if (uid != null && uid.isNotEmpty) {
          await _pendingReportQueue.removeByReportId(uid, reportId);
          await _syncMeta.clearReport(uid, reportId);
        }
        return;
      } catch (error, stackTrace) {
        ErrorHandler.log(error, stackTrace, 'deleteReportFirebase');
      }
    }

    await _removeReportLocally(reportId);
    final uid = actorUid?.trim();
    if (uid != null && uid.isNotEmpty) {
      await _pendingReportQueue.removeByReportId(uid, reportId);
      await _syncMeta.clearReport(uid, reportId);
    }
  }

  Future<Directory> getReportsDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final reportsDir = Directory('${dir.path}/informes');
    if (!await reportsDir.exists()) {
      await reportsDir.create(recursive: true);
    }
    return reportsDir;
  }

  Future<void> _saveReportFiles(
    SavedReport report, {
    PdfReportStyle exportStyle = PdfReportStyle.completo,
  }) async {
    final dir = await getReportsDirectory();
    final safeName = _safeFileName(report.name);
    final stamp = _fileStamp(report.createdAt);

    final excelBytes = exportService.buildExcelBytes(
      report.records,
      style: exportStyle,
    );
    if (excelBytes != null) {
      final excelFile = File('${dir.path}/${safeName}_$stamp.xlsx');
      await excelFile.writeAsBytes(excelBytes, flush: true);
    }

    final csvFile = File('${dir.path}/${safeName}_$stamp.csv');
    await csvFile.writeAsString(
      '\uFEFF${exportService.buildCsvText(report.records, style: exportStyle)}',
      encoding: utf8,
    );

    final pdfBytes = await exportService.buildPdfBytes(
      records: report.records,
      title: report.name,
      style: exportStyle,
    );
    final pdfFile = File('${dir.path}/${safeName}_$stamp.pdf');
    await pdfFile.writeAsBytes(pdfBytes, flush: true);
  }

  String _safeFileName(String name) {
    final cleaned = name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    return cleaned.isEmpty ? 'informe' : cleaned;
  }

  String _fileStamp(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}${two(date.month)}${two(date.day)}_${two(date.hour)}${two(date.minute)}';
  }
}
