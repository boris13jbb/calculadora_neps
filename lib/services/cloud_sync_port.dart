import '../models/app_user_role.dart';
import '../models/nep_record.dart';
import '../models/record_filters.dart';
import '../models/records_page_result.dart';
import '../models/saved_report.dart';

/// Contrato de sincronizacion sin dependencias de Firebase en el arranque.
abstract class CloudSyncPort {
  Future<void> bootstrap();

  /// Suscripción legacy (compatibilidad). Preferir [watchRecentRecords].
  Stream<List<NepRecord>> watchRecords({
    AppUserRole viewerRole = AppUserRole.operario,
  });

  /// Últimos registros paginados en tiempo real.
  Stream<RecordsPageResult> watchRecentRecords({
    AppUserRole viewerRole = AppUserRole.operario,
    int limit = 50,
  });

  /// Registros en un rango de fechas (tiempo real).
  Stream<RecordsPageResult> watchRecordsByDateRange({
    required DateTime from,
    required DateTime to,
    AppUserRole viewerRole = AppUserRole.operario,
    int limit = 50,
  });

  /// Registros filtrados con consulta Firestore (tiempo real).
  Stream<RecordsPageResult> watchRecordsByFilters({
    required RecordFilters filters,
    AppUserRole viewerRole = AppUserRole.operario,
    int limit = 50,
  });

  Stream<List<String>> watchFabrics();

  Future<void> migrateLocalDataIfNeeded({
    required List<NepRecord> localRecords,
    required List<String> localFabrics,
  });

  Future<void> syncFabricsWithLocal(List<String> localFabrics);

  Future<List<String>> saveFabrics(List<String> fabrics);

  Future<void> upsertRecord(NepRecord record);

  Future<void> upsertRecords(List<NepRecord> records);

  Future<void> deleteRecord(String recordId, {String? ownerUid});

  Future<void> clearRecords();

  Future<void> replaceRecords(List<NepRecord> records);

  Future<List<SavedReport>> fetchReports();

  Future<SavedReport> saveReport(SavedReport report);

  Future<void> deleteReport(String reportId);

  Future<AppUserRole> fetchUserRole();

  Future<Map<String, dynamic>?> fetchAlertConfig();

  Future<void> saveAlertConfig(Map<String, dynamic> config);

  Future<void> registerFcmToken(String token);
}
