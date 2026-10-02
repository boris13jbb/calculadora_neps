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
/// 3. [latestTodayCaptureRecord] (fallback toolbar; suele ser el más reciente
///    de la sesión si el llamador ya lo acotó)
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

/// Modo de lista inicial en Captura → Compartir (copy / UX).
enum ShareInitialListMode {
  /// Registros de la sesión de captura activa.
  session,

  /// Pool completo de hoy.
  today,
}

/// Intersección estable: registros de [sessionRecords] que siguen en [eligible].
///
/// Conserva el orden de [eligibleRecords] (típicamente más reciente primero).
List<NepRecord> intersectEligibleSessionRecords({
  required List<NepRecord> eligibleRecords,
  List<NepRecord>? sessionRecords,
}) {
  if (sessionRecords == null || sessionRecords.isEmpty) {
    return const [];
  }
  final sessionIds = sessionRecords.map((record) => record.id).toSet();
  return eligibleRecords
      .where((record) => sessionIds.contains(record.id))
      .toList(growable: false);
}

/// Registros visibles al abrir Captura → Compartir.
///
/// Separa "qué mostrar" de "qué seleccionar":
/// - Con [sessionRecords] de la sesión activa → **todos** los de esa sesión
///   (también tras crear o desde fila), no todo el día.
/// - Sin sesión usable → pool completo de hoy.
///
/// "Seleccionar registros de hoy" usa el pool completo [eligibleRecords] y
/// puede ampliar la lista visible en el diálogo.
List<NepRecord> resolveShareInitialVisibleRecords({
  required List<NepRecord> eligibleRecords,
  List<NepRecord>? sessionRecords,
}) {
  // La sesión actual es la unidad de visibilidad inicial (todos sus registros).
  final sessionVisible = intersectEligibleSessionRecords(
    eligibleRecords: eligibleRecords,
    sessionRecords: sessionRecords,
  );
  if (sessionVisible.isNotEmpty) {
    return List<NepRecord>.from(sessionVisible);
  }

  return List<NepRecord>.from(eligibleRecords);
}

/// Modo de lista coherente con [resolveShareInitialVisibleRecords].
ShareInitialListMode resolveShareInitialListMode({
  required List<NepRecord> eligibleRecords,
  required List<NepRecord> visibleRecords,
  List<NepRecord>? sessionRecords,
}) {
  final sessionVisible = intersectEligibleSessionRecords(
    eligibleRecords: eligibleRecords,
    sessionRecords: sessionRecords,
  );
  if (sessionVisible.isNotEmpty &&
      visibleRecords.length == sessionVisible.length &&
      visibleRecords.every(
        (record) => sessionVisible.any((session) => session.id == record.id),
      )) {
    return ShareInitialListMode.session;
  }

  return ShareInitialListMode.today;
}

/// Más reciente de una lista ya filtrada, o null.
NepRecord? resolveLatestRecord(Iterable<NepRecord> records) {
  NepRecord? latest;
  for (final record in records) {
    if (latest == null || record.createdAt.isAfter(latest.createdAt)) {
      latest = record;
    }
  }
  return latest;
}
