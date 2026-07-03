import 'import_row_result.dart';
import 'nep_record.dart';

class RecordImportResult {
  const RecordImportResult({
    required this.records,
    this.skippedRows = 0,
    this.message,
    this.rowResults = const [],
    this.missingColumns = const [],
    this.hasRecognizedHeader = false,
    this.duplicateRows = 0,
    this.errorRows = 0,
  });

  final List<NepRecord> records;
  final int skippedRows;
  final String? message;
  final List<ImportRowResult> rowResults;
  final List<String> missingColumns;
  final bool hasRecognizedHeader;
  final int duplicateRows;
  final int errorRows;

  bool get hasRecords => records.isNotEmpty;

  int get validCount =>
      rowResults.where((r) => r.status == ImportRowStatus.valid).length;

  int get previewTotalRows => rowResults.length;

  /// Registros listos para importar (válidos, sin duplicados internos/externos).
  List<NepRecord> get importableRecords => rowResults
      .where((r) => r.status == ImportRowStatus.valid && r.record != null)
      .map((r) => r.record!)
      .toList();
}
