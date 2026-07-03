import '../models/nep_record.dart';
import '../models/saved_report.dart';
import '../models/user_role.dart';

/// Contrato de sincronizacion sin dependencias de Firebase en el arranque.
abstract class CloudSyncPort {
  Future<void> bootstrap();

  Stream<List<NepRecord>> watchRecords();

  Stream<List<String>> watchFabrics();

  Future<void> migrateLocalDataIfNeeded({
    required List<NepRecord> localRecords,
    required List<String> localFabrics,
  });

  Future<void> syncFabricsWithLocal(List<String> localFabrics);

  Future<List<String>> saveFabrics(List<String> fabrics);

  Future<void> upsertRecord(NepRecord record);

  Future<void> upsertRecords(List<NepRecord> records);

  Future<void> deleteRecord(String recordId);

  Future<void> clearRecords();

  Future<void> replaceRecords(List<NepRecord> records);

  Future<List<SavedReport>> fetchReports();

  Future<SavedReport> saveReport(SavedReport report);

  Future<void> deleteReport(String reportId);

  Future<UserRole> fetchUserRole();

  Future<Map<String, dynamic>?> fetchAlertConfig();

  Future<void> saveAlertConfig(Map<String, dynamic> config);

  Future<void> registerFcmToken(String token);
}
