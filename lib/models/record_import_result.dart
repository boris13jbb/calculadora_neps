import 'nep_record.dart';

class RecordImportResult {
  const RecordImportResult({
    required this.records,
    this.skippedRows = 0,
    this.message,
  });

  final List<NepRecord> records;
  final int skippedRows;
  final String? message;

  bool get hasRecords => records.isNotEmpty;
}
