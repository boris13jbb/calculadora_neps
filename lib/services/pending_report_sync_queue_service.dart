import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../models/pending_report_sync_op.dart';
import '../models/report_sync_status.dart';
import '../models/saved_report.dart';

/// Cola durable de sync de Informes, aislada por UID y workspace.
///
/// Independiente de [PendingSyncQueueService] (registros) y de personalSessions.
class PendingReportSyncQueueService {
  PendingReportSyncQueueService();

  /// Carga operaciones del [uid], descartando entradas corruptas o de otro dueño.
  Future<List<PendingReportSyncOp>> loadForUid(String uid) async {
    final key = pendingReportSyncKeyForUid(uid);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];

      final ops = <PendingReportSyncOp>[];
      var mutated = false;
      for (final item in decoded) {
        if (item is! Map) {
          mutated = true;
          continue;
        }
        final op = PendingReportSyncOp.tryFromJson(
          Map<String, dynamic>.from(item),
        );
        if (op == null) {
          mutated = true;
          continue;
        }
        if (op.ownerUid != uid) {
          mutated = true;
          continue;
        }
        if (op.workspaceId != cloudWorkspaceId) {
          mutated = true;
          continue;
        }
        ops.add(op);
      }

      if (mutated) {
        await _save(uid, ops);
      }
      return List.unmodifiable(ops);
    } catch (_) {
      // Cola parcialmente dañada: no borrar a ciegas; deja vacía en memoria
      // y limpia la clave corrupta para no romper arranques siguientes.
      await prefs.remove(key);
      return const [];
    }
  }

  Future<void> _save(String uid, List<PendingReportSyncOp> ops) async {
    final prefs = await SharedPreferences.getInstance();
    final key = pendingReportSyncKeyForUid(uid);
    final encoded = jsonEncode(ops.map((op) => op.toJson()).toList());
    final ok = await prefs.setString(key, encoded);
    if (!ok) {
      throw StateError('No se pudo persistir la cola de sync de informes');
    }
    final readBack = prefs.getString(key);
    if (readBack != encoded) {
      throw StateError(
        'Verificación de cola de sync de informes falló tras escribir',
      );
    }
  }

  Future<PendingReportSyncOp?> findByReportId(String uid, String reportId) async {
    final id = reportId.trim();
    if (id.isEmpty) return null;
    final ops = await loadForUid(uid);
    for (final op in ops) {
      if (op.reportId == id) return op;
    }
    return null;
  }

  Future<Map<String, ReportSyncStatus>> statusByReportId(String uid) async {
    final ops = await loadForUid(uid);
    return {
      for (final op in ops) op.reportId: op.status,
    };
  }

  /// Encola o reemplaza un upsert pendiente del mismo reportId (mismo ID).
  Future<PendingReportSyncOp> enqueueUpsert({
    required String uid,
    required SavedReport report,
    String? baseFingerprint,
    ReportSyncStatus status = ReportSyncStatus.localPending,
    String? errorCode,
  }) async {
    final owner = uid.trim();
    final ops = List<PendingReportSyncOp>.from(await loadForUid(owner));
    ops.removeWhere((op) => op.reportId == report.id);

    final pending = PendingReportSyncOp.upsert(
      report: report,
      ownerUid: owner,
      baseFingerprint: baseFingerprint,
      status: status,
    ).copyWith(
      errorCode: errorCode,
      clearErrorCode: errorCode == null,
    );

    ops.add(pending);
    await _save(owner, ops);
    return pending;
  }

  Future<void> upsertOp(String uid, PendingReportSyncOp op) async {
    if (op.ownerUid != uid) return;
    final ops = List<PendingReportSyncOp>.from(await loadForUid(uid));
    ops.removeWhere((item) => item.reportId == op.reportId || item.id == op.id);
    ops.add(op);
    await _save(uid, ops);
  }

  Future<void> removeByReportId(String uid, String reportId) async {
    final id = reportId.trim();
    if (id.isEmpty) return;
    final ops = List<PendingReportSyncOp>.from(await loadForUid(uid));
    final next = ops.where((op) => op.reportId != id).toList(growable: false);
    if (next.length == ops.length) return;
    await _save(uid, next);
  }

  Future<void> replaceAll(String uid, List<PendingReportSyncOp> ops) async {
    final filtered = ops
        .where(
          (op) =>
              op.ownerUid == uid && op.workspaceId == cloudWorkspaceId,
        )
        .toList(growable: false);
    await _save(uid, filtered);
  }

  Future<void> clear(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(pendingReportSyncKeyForUid(uid));
  }
}

final PendingReportSyncQueueService pendingReportSyncQueueService =
    PendingReportSyncQueueService();
