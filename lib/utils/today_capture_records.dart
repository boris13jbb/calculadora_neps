import '../models/nep_record.dart';

/// Registros del día local actual del usuario autenticado, aptos para Compartir.
///
/// Ownership ambiguo (`createdByUid` nulo/vacío) se excluye.
List<NepRecord> filterTodayCaptureRecords({
  required Iterable<NepRecord> records,
  required String? authUid,
  DateTime? now,
}) {
  final uid = authUid?.trim();
  if (uid == null || uid.isEmpty) return const [];

  final localNow = (now ?? DateTime.now()).toLocal();
  final dayStart = DateTime(localNow.year, localNow.month, localNow.day);
  final dayEnd = dayStart.add(const Duration(days: 1));

  final filtered = records.where((record) {
    final owner = record.createdByUid?.trim();
    if (owner == null || owner.isEmpty || owner != uid) return false;
    final created = record.createdAt.toLocal();
    return !created.isBefore(dayStart) && created.isBefore(dayEnd);
  }).toList();

  filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return filtered;
}

/// Registro más reciente de [filterTodayCaptureRecords], o null.
NepRecord? resolveLatestTodayCaptureRecord({
  required Iterable<NepRecord> records,
  required String? authUid,
  DateTime? now,
}) {
  final today = filterTodayCaptureRecords(
    records: records,
    authUid: authUid,
    now: now,
  );
  if (today.isEmpty) return null;
  return today.first;
}

/// ID inicial para Captura → Compartir, con prioridad explícita.
///
/// 1. [initiallySelectedRecord] (Compartir desde fila)
/// 2. [newlyCreatedRecordId] (registro recién creado en Captura)
/// 3. [latestTodayCaptureRecord] (fallback toolbar)
/// 4. null si ninguno es elegible
String? resolveShareInitialSelectedId({
  required List<NepRecord> eligibleRecords,
  NepRecord? initiallySelectedRecord,
  String? newlyCreatedRecordId,
  NepRecord? latestTodayCaptureRecord,
}) {
  bool isEligible(String? id) {
    if (id == null || id.isEmpty) return false;
    return eligibleRecords.any((record) => record.id == id);
  }

  final fromRow = initiallySelectedRecord?.id;
  if (isEligible(fromRow)) return fromRow;

  if (isEligible(newlyCreatedRecordId)) return newlyCreatedRecordId;

  final fromLatest = latestTodayCaptureRecord?.id;
  if (isEligible(fromLatest)) return fromLatest;

  return null;
}

/// Registros visibles al abrir Captura → Compartir.
///
/// Separa "qué mostrar" de "qué seleccionar":
/// - Compartir desde fila → lista completa de hoy (la fila define la selección).
/// - Tras crear un registro (`newlyCreatedRecordId` elegible, sin fila) →
///   únicamente ese registro por ID estable.
/// - Menú general / fallback → lista completa de hoy.
///
/// "Seleccionar todos los de hoy" usa el pool completo [eligibleRecords] y
/// puede ampliar la lista visible en el diálogo.
List<NepRecord> resolveShareInitialVisibleRecords({
  required List<NepRecord> eligibleRecords,
  NepRecord? initiallySelectedRecord,
  String? newlyCreatedRecordId,
}) {
  // Fila: no enfocar; mantener listado general de hoy.
  final fromRow = initiallySelectedRecord?.id;
  if (fromRow != null &&
      fromRow.isNotEmpty &&
      eligibleRecords.any((record) => record.id == fromRow)) {
    return List<NepRecord>.from(eligibleRecords);
  }

  final newId = newlyCreatedRecordId?.trim();
  if (newId != null && newId.isNotEmpty) {
    final focused = eligibleRecords
        .where((record) => record.id == newId)
        .toList(growable: false);
    if (focused.isNotEmpty) return focused;
  }

  return List<NepRecord>.from(eligibleRecords);
}
