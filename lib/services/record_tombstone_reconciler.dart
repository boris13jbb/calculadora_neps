import '../models/nep_record.dart';
import '../models/record_tombstone.dart';
import '../providers/domain/records_scope.dart';
import 'pending_sync_queue_service.dart';
import 'record_local_storage_service.dart';

/// Aplica un tombstone localmente: memoria, disco y cola (DELETE > UPSERT).
///
/// No toca SavedReports ni archivos históricos. No limpia otros UID.
class RecordTombstoneReconciler {
  const RecordTombstoneReconciler();

  /// Poda [scope.items], borra del storage del UID bound y limpia upserts.
  Future<void> applyLocally({
    required RecordTombstone tombstone,
    required RecordsScope scope,
    required RecordLocalStorageService storage,
    required PendingSyncQueueService queue,
    required String actorUid,
  }) async {
    final recordId = tombstone.recordId.trim();
    if (recordId.isEmpty) return;

    scope.removeById(recordId);
    await storage.deleteById(recordId);
    await queue.removeUpsertsForRecordId(actorUid, recordId);
  }

  /// Conserva registros ausentes del snapshot salvo que estén tombstoned.
  ///
  /// La paginación sola NUNCA debe borrar IDs; solo [tombstonedIds] podan.
  List<NepRecord> mergePreservingLocalExceptTombstones({
    required List<NepRecord> local,
    required List<NepRecord> remotePage,
    required Set<String> tombstonedIds,
  }) {
    final byId = <String, NepRecord>{
      for (final r in local)
        if (!tombstonedIds.contains(r.id)) r.id: r,
    };
    for (final r in remotePage) {
      if (tombstonedIds.contains(r.id)) continue;
      byId[r.id] = r;
    }
    return byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
}
