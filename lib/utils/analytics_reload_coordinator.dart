/// Coordina recargas de historial analítico: una sola carga a la vez y
/// «última solicitud gana» (sin recursión ni paralelismo).
///
/// Uso típico:
/// 1. [run] ejecuta [action] en un bucle mientras haya pendiente.
/// 2. Si llega otra solicitud mientras [isBusy], marcar con [markPending]
///    (o llamar [run] de nuevo: también marca pendiente y retorna).
/// 3. Dentro de [action], si el período UI cambió durante el await,
///    llamar [markPending] y no aplicar el resultado obsoleto.
class LatestWinsReloadGate {
  bool _busy = false;
  bool _pending = false;

  bool get isBusy => _busy;

  bool get hasPending => _pending;

  /// Indica que, al terminar la pasada actual, hace falta otra con el estado UI vigente.
  void markPending() => _pending = true;

  /// Coalesce: el resultado aplicado ya coincide con la UI (mismo período).
  void clearPending() => _pending = false;

  /// Ejecuta [action] en exclusiva. Solicitudes concurrentes solo marcan pendiente.
  Future<void> run(Future<void> Function() action) async {
    if (_busy) {
      _pending = true;
      return;
    }

    _busy = true;
    try {
      do {
        _pending = false;
        await action();
      } while (_pending);
    } finally {
      _busy = false;
    }
  }
}
