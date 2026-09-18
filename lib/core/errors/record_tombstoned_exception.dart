/// El registro fue eliminado de forma definitiva (delete-wins).
///
/// No es un error de red: el cliente debe descartar upserts pendientes
/// del [recordId] y no reintentar la recreación.
class RecordTombstonedException implements Exception {
  const RecordTombstonedException(this.recordId, {this.message});

  final String recordId;
  final String? message;

  @override
  String toString() =>
      message ?? 'Registro $recordId eliminado (tombstone); upsert rechazado.';
}
