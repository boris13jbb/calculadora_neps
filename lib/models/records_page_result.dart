import 'nep_record.dart';

/// Resultado paginado de una consulta de registros (Firestore o caché local).
class RecordsPageResult {
  const RecordsPageResult({
    required this.records,
    this.hasMore = false,
    this.queryLimit = 0,
  });

  final List<NepRecord> records;
  final bool hasMore;

  /// Límite usado en la consulta (para detectar si hay más páginas).
  final int queryLimit;
}
