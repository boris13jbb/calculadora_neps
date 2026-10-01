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
