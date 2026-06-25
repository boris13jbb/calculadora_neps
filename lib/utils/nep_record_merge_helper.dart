import '../models/nep_record.dart';

/// Utilidades puras para fusionar registros al migrar entre colecciones.
class NepRecordMergeHelper {
  const NepRecordMergeHelper._();

  /// Conserva el registro con `createdAt` mas reciente.
  static NepRecord resolveConflict(NepRecord existing, NepRecord incoming) {
    return incoming.createdAt.isAfter(existing.createdAt) ? incoming : existing;
  }

  /// Fusiona listas por `id`, resolviendo conflictos por fecha de creacion.
  static List<NepRecord> mergeById(
    Iterable<NepRecord> existing,
    Iterable<NepRecord> incoming,
  ) {
    final byId = <String, NepRecord>{
      for (final record in existing) record.id: record,
    };

    for (final record in incoming) {
      final current = byId[record.id];
      byId[record.id] = current == null
          ? record
          : resolveConflict(current, record);
    }

    final merged = byId.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return merged;
  }
}
