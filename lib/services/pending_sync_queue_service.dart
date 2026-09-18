import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../models/nep_record.dart';
import '../utils/stable_id.dart';

enum PendingSyncOpType { upsert, delete }

/// Operación de sincronización pendiente, aislada por UID propietario.
class PendingSyncOp {
  PendingSyncOp({
    required this.id,
    required this.ownerUid,
    required this.type,
    required this.createdAt,
    this.record,
    this.recordId,
  });

  final String id;
  final String ownerUid;
  final PendingSyncOpType type;
  final DateTime createdAt;
  final NepRecord? record;
  final String? recordId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'ownerUid': ownerUid,
        'type': type.name,
        'createdAt': createdAt.toIso8601String(),
        if (record != null) 'record': record!.toJson(),
        if (recordId != null) 'recordId': recordId,
      };

  factory PendingSyncOp.fromJson(Map<String, dynamic> json) {
    final typeName = json['type']?.toString() ?? 'upsert';
    return PendingSyncOp(
      id: json['id']?.toString() ?? generateStableId(prefix: 'pop'),
      ownerUid: json['ownerUid']?.toString() ?? '',
      type: PendingSyncOpType.values.firstWhere(
        (value) => value.name == typeName,
        orElse: () => PendingSyncOpType.upsert,
      ),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      record: json['record'] is Map
          ? NepRecord.fromJson(Map<String, dynamic>.from(json['record'] as Map))
          : null,
      recordId: json['recordId']?.toString(),
    );
  }
}

/// Cola durable de sync por UID. Nunca se aplica bajo otra identidad.
class PendingSyncQueueService {
  PendingSyncQueueService();

  Future<List<PendingSyncOp>> loadForUid(String uid) async {
    final key = pendingSyncKeyForUid(uid);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final List decoded = jsonDecode(raw);
      return decoded
          .map((item) =>
              PendingSyncOp.fromJson(Map<String, dynamic>.from(item as Map)))
          .where((op) => op.ownerUid == uid)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _save(String uid, List<PendingSyncOp> ops) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      pendingSyncKeyForUid(uid),
      jsonEncode(ops.map((op) => op.toJson()).toList()),
    );
  }

  Future<void> enqueueUpsert(String uid, NepRecord record) async {
    final ops = List<PendingSyncOp>.from(await loadForUid(uid));
    // Idempotencia: una sola upsert pendiente por record.id
    ops.removeWhere(
      (op) =>
          op.type == PendingSyncOpType.upsert &&
          (op.record?.id == record.id || op.recordId == record.id),
    );
    ops.add(
      PendingSyncOp(
        id: generateStableId(prefix: 'pop'),
        ownerUid: uid,
        type: PendingSyncOpType.upsert,
        createdAt: DateTime.now(),
        record: record,
        recordId: record.id,
      ),
    );
    await _save(uid, ops);
  }

  Future<void> enqueueDelete(
    String uid,
    String recordId, {
    String? ownerUid,
  }) async {
    final ops = List<PendingSyncOp>.from(await loadForUid(uid));
    ops.removeWhere(
      (op) => op.recordId == recordId || op.record?.id == recordId,
    );
    ops.add(
      PendingSyncOp(
        id: generateStableId(prefix: 'pop'),
        ownerUid: ownerUid ?? uid,
        type: PendingSyncOpType.delete,
        createdAt: DateTime.now(),
        recordId: recordId,
      ),
    );
    await _save(uid, ops);
  }

  /// Quita upserts pendientes de [recordId] (DELETE > UPSERT).
  ///
  /// Conserva deletes y upserts de otros IDs. Aislado por [uid].
  Future<void> removeUpsertsForRecordId(String uid, String recordId) async {
    final id = recordId.trim();
    if (id.isEmpty) return;
    final ops = List<PendingSyncOp>.from(await loadForUid(uid));
    final next = ops
        .where(
          (op) => !(op.type == PendingSyncOpType.upsert &&
              (op.recordId == id || op.record?.id == id)),
        )
        .toList(growable: false);
    if (next.length == ops.length) return;
    await _save(uid, next);
  }

  /// Quita todos los UPSERT del actor (p. ej. tras vaciar tabla). Conserva deletes.
  Future<void> removeAllUpserts(String uid) async {
    final ops = List<PendingSyncOp>.from(await loadForUid(uid));
    final next = ops
        .where((op) => op.type != PendingSyncOpType.upsert)
        .toList(growable: false);
    if (next.length == ops.length) return;
    await _save(uid, next);
  }

  Future<void> replaceAll(String uid, List<PendingSyncOp> ops) async {
    // Conserva todas las ops restantes de la cola del actor (incluye deletes
    // de registros ajenos encolados por roles con permiso global).
    await _save(uid, List<PendingSyncOp>.from(ops));
  }

  Future<void> clear(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(pendingSyncKeyForUid(uid));
  }
}

final PendingSyncQueueService pendingSyncQueueService =
    PendingSyncQueueService();
