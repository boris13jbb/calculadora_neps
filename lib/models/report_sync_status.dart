/// Estado de sincronización de un informe guardado con Firestore.
enum ReportSyncStatus {
  /// Guardado local; pendiente de confirmación cloud.
  localPending,

  /// Sincronización en curso.
  syncing,

  /// Firestore confirmó el dual-write.
  synced,

  /// Error temporal; se puede reintentar.
  retryableError,

  /// Error que no debe reintentarse en bucle (p. ej. permisos).
  permanentError,

  /// Remoto incompatible; no se sobrescribe automáticamente.
  conflict,
}

/// Mensajes de UI en español (fuente única).
abstract final class ReportSyncUserMessages {
  static const synced = 'Informe sincronizado correctamente';
  static const localPending =
      'Informe guardado en este dispositivo. Pendiente de sincronización';
  static const offline =
      'Sin conexión. El informe se conservará en este dispositivo hasta que pueda sincronizarse';
  static const retryableError =
      'No se pudo completar la sincronización. El informe sigue guardado en este dispositivo';
  static const conflict =
      'Se detectó una versión diferente del informe en la nube. No se sobrescribieron los datos';
  static const permanentError =
      'No se pudo sincronizar el informe. Revisa tus permisos o solicita asistencia';

  static String forStatus(
    ReportSyncStatus status, {
    bool offlineHint = false,
  }) {
    switch (status) {
      case ReportSyncStatus.synced:
        return synced;
      case ReportSyncStatus.localPending:
        return offlineHint ? offline : localPending;
      case ReportSyncStatus.syncing:
        return localPending;
      case ReportSyncStatus.retryableError:
        return retryableError;
      case ReportSyncStatus.permanentError:
        return permanentError;
      case ReportSyncStatus.conflict:
        return conflict;
    }
  }

  static String shortLabel(ReportSyncStatus status) {
    switch (status) {
      case ReportSyncStatus.synced:
        return 'Sincronizado';
      case ReportSyncStatus.localPending:
        return 'Pendiente';
      case ReportSyncStatus.syncing:
        return 'Sincronizando…';
      case ReportSyncStatus.retryableError:
        return 'Error temporal';
      case ReportSyncStatus.permanentError:
        return 'Error permanente';
      case ReportSyncStatus.conflict:
        return 'Conflicto';
    }
  }
}
