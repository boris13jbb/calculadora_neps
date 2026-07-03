import 'nep_record.dart';

/// Estado de una fila durante la importación.
enum ImportRowStatus {
  valid('Válida'),
  error('Error'),
  duplicate('Duplicada'),
  skipped('Omitida');

  const ImportRowStatus(this.label);

  final String label;
}

/// Resultado detallado por fila del archivo importado.
class ImportRowResult {
  const ImportRowResult({
    required this.rowNumber,
    required this.status,
    this.record,
    this.message,
    this.rawCells = const [],
  });

  final int rowNumber;
  final ImportRowStatus status;
  final NepRecord? record;
  final String? message;
  final List<String> rawCells;
}
