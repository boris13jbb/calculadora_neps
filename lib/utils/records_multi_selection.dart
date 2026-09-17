import '../models/nep_record.dart';
import '../models/record_delete_outcome.dart';

/// IDs de la página actual (paginación 0-based). Solo la página visible.
List<String> pageRecordIds({
  required List<NepRecord> records,
  required int page,
  required int rowsPerPage,
}) {
  if (records.isEmpty || rowsPerPage <= 0) return const [];
  final pageCount = (records.length + rowsPerPage - 1) ~/ rowsPerPage;
  final safePage = page.clamp(0, pageCount - 1);
  final start = safePage * rowsPerPage;
  final end = (start + rowsPerPage) > records.length
      ? records.length
      : start + rowsPerPage;
  return records.sublist(start, end).map((r) => r.id).toList(growable: false);
}

/// Selección múltiple de registros identificada exclusivamente por [NepRecord.id].
class RecordsMultiSelection {
  final Set<String> selectedRecordIds = <String>{};

  int get count => selectedRecordIds.length;

  bool get isEmpty => selectedRecordIds.isEmpty;

  bool get isNotEmpty => selectedRecordIds.isNotEmpty;

  void clear() => selectedRecordIds.clear();

  void toggle(String id) {
    if (!selectedRecordIds.add(id)) {
      selectedRecordIds.remove(id);
    }
  }

  void setSelected(String id, bool selected) {
    if (selected) {
      selectedRecordIds.add(id);
    } else {
      selectedRecordIds.remove(id);
    }
  }

  /// Selecciona únicamente los IDs de la página actual (reemplaza selección).
  void selectAllOnPage(Iterable<String> pageIds) {
    selectedRecordIds
      ..clear()
      ..addAll(pageIds);
  }

  void deselectPage(Iterable<String> pageIds) {
    selectedRecordIds.removeAll(pageIds);
  }

  /// Checkbox maestro: si todos de la página están marcados, desmarca;
  /// si no, marca todos los de la página (conserva otros solo si ya estaban,
  /// pero el contrato de página limpia en cambio de contexto).
  void toggleSelectAllOnPage(Iterable<String> pageIds) {
    final pageSet = pageIds.toSet();
    if (pageSet.isEmpty) return;
    if (isPageFullySelected(pageSet)) {
      deselectPage(pageSet);
    } else {
      selectedRecordIds.addAll(pageSet);
    }
  }

  bool isPageFullySelected(Iterable<String> pageIds) {
    final pageSet = pageIds.toSet();
    if (pageSet.isEmpty) return false;
    return pageSet.every(selectedRecordIds.contains);
  }

  bool isPageNoneSelected(Iterable<String> pageIds) {
    final pageSet = pageIds.toSet();
    if (pageSet.isEmpty) return true;
    return pageSet.every((id) => !selectedRecordIds.contains(id));
  }

  bool isPageIndeterminate(Iterable<String> pageIds) {
    final pageSet = pageIds.toSet();
    if (pageSet.isEmpty) return false;
    var selectedOnPage = 0;
    for (final id in pageSet) {
      if (selectedRecordIds.contains(id)) selectedOnPage++;
    }
    return selectedOnPage > 0 && selectedOnPage < pageSet.length;
  }

  /// Cambio de página / filas por página: limpiar por seguridad.
  void onPageContextChanged() => clear();

  /// Cambio de filtros / contexto visual distinto: limpiar por seguridad.
  void onFilterContextChanged() => clear();

  /// Usuario / logout: limpiar.
  void onUserContextChanged() => clear();

  /// Quita IDs que ya no existen en el dataset visible.
  void pruneToExisting(Iterable<String> existingIds) {
    final existing =
        existingIds is Set<String> ? existingIds : existingIds.toSet();
    selectedRecordIds.removeWhere((id) => !existing.contains(id));
  }

  bool canUpdate({required bool canEditRecords}) =>
      canEditRecords && selectedRecordIds.length == 1;

  bool canBulkDelete({required bool canDeleteRecords}) =>
      canDeleteRecords && selectedRecordIds.isNotEmpty;

  String? get singleSelectedId =>
      selectedRecordIds.length == 1 ? selectedRecordIds.single : null;

  NepRecord? resolveSingleSelected(List<NepRecord> records) {
    final id = singleSelectedId;
    if (id == null) return null;
    for (final record in records) {
      if (record.id == id) return record;
    }
    return null;
  }
}

bool isSuccessfulDeleteOutcome(RecordDeleteOutcome outcome) {
  return outcome == RecordDeleteOutcome.deletedRemote ||
      outcome == RecordDeleteOutcome.deletedLocalPendingSync;
}

String bulkDeleteConfirmTitle(int count) {
  if (count == 1) return 'Eliminar 1 registro seleccionado';
  return 'Eliminar $count registros seleccionados';
}

String bulkDeleteConfirmActionLabel(int count) {
  if (count == 1) return 'Eliminar 1';
  return 'Eliminar $count';
}

String bulkDeleteConfirmMessage(int count) {
  final noun =
      count == 1 ? 'el registro seleccionado' : 'los registros seleccionados';
  return 'Se eliminarán únicamente $noun de esta página.\n'
      'Esta acción no vaciará la tabla completa.';
}

/// Resultado de borrado múltiple (no atómico).
class BulkDeleteSummary {
  const BulkDeleteSummary({
    required this.succeeded,
    required this.failed,
    required this.remainingSelectedIds,
    this.wasCancelled = false,
    this.wasDeniedByPermission = false,
  });

  final int succeeded;
  final int failed;
  final Set<String> remainingSelectedIds;
  final bool wasCancelled;
  final bool wasDeniedByPermission;

  String get message {
    if (wasCancelled || wasDeniedByPermission) return '';
    if (failed == 0) {
      return succeeded == 1
          ? '1 registro eliminado.'
          : '$succeeded registros eliminados.';
    }
    if (succeeded == 0) {
      return failed == 1
          ? '1 registro no pudo eliminarse.'
          : '$failed registros no pudieron eliminarse.';
    }
    final successPart = succeeded == 1
        ? '1 registro eliminado'
        : '$succeeded registros eliminados';
    final failPart =
        failed == 1 ? '1 no pudo eliminarse' : '$failed no pudieron eliminarse';
    return '$successPart. $failPart.';
  }
}

/// Ejecuta deleteRecord una vez por ID (snapshot). No usa clear/replace global.
Future<BulkDeleteSummary> runBulkDeleteSelected({
  required Set<String> selectedIds,
  required bool canDeleteRecords,
  required bool confirmed,
  required Future<RecordDeleteOutcome> Function(String id) deleteRecord,
}) async {
  if (!canDeleteRecords) {
    return BulkDeleteSummary(
      succeeded: 0,
      failed: 0,
      remainingSelectedIds: Set<String>.from(selectedIds),
      wasDeniedByPermission: true,
    );
  }

  if (!confirmed || selectedIds.isEmpty) {
    return BulkDeleteSummary(
      succeeded: 0,
      failed: 0,
      remainingSelectedIds: Set<String>.from(selectedIds),
      wasCancelled: !confirmed,
    );
  }

  // Snapshot inmutable: realtime no debe alterar la iteración.
  final idsToDelete = Set<String>.from(selectedIds);
  var succeeded = 0;
  var failed = 0;
  final remaining = <String>{};

  for (final id in idsToDelete) {
    final outcome = await deleteRecord(id);
    if (isSuccessfulDeleteOutcome(outcome)) {
      succeeded++;
    } else {
      failed++;
      remaining.add(id);
    }
  }

  return BulkDeleteSummary(
    succeeded: succeeded,
    failed: failed,
    remainingSelectedIds: remaining,
  );
}

/// Abre el editor existente para el único seleccionado; limpia selección si OK.
Future<bool> runUpdateSelectedRecord({
  required RecordsMultiSelection selection,
  required List<NepRecord> records,
  required bool canEditRecords,
  required Future<bool> Function(NepRecord record) openEditor,
  void Function()? onUpdated,
}) async {
  if (!selection.canUpdate(canEditRecords: canEditRecords)) return false;
  final record = selection.resolveSingleSelected(records);
  if (record == null) return false;

  final saved = await openEditor(record);
  if (saved) {
    onUpdated?.call();
    selection.clear();
  }
  return saved;
}
