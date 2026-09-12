/// Resultado explícito de [AppState.deleteRecord].
enum RecordDeleteOutcome {
  /// Eliminado en Firebase y luego en local.
  deletedRemote,

  /// Eliminado en local; PendingDelete encolado (offline real).
  deletedLocalPendingSync,

  /// Firebase permission-denied (el registro permanece en UI).
  permissionDenied,

  /// Denegado por permiso local / ownership de operario.
  permissionDeniedLocal,

  /// Otro error de Firebase (no offline).
  firebaseError,

  /// El id no estaba en la lista local.
  notFound,
}
