/// Fases visibles de sincronización para la UI.
enum SyncPhase {
  loadingLocal('Cargando datos locales…'),
  syncingCloud('Sincronizando con Firebase…'),
  realtime('Actualizado en tiempo real'),
  offline('Sin sincronización con Firebase, usando datos locales');

  const SyncPhase(this.label);

  final String label;
}
