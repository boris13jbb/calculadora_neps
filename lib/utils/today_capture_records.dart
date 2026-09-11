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
