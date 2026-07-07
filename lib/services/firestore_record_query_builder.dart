import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/alert_level.dart';
import '../models/record_filters.dart';
import '../utils/record_filter_helper.dart';

/// Construye consultas Firestore eficientes para registros paginados.
class FirestoreRecordQueryBuilder {
  const FirestoreRecordQueryBuilder._();

  /// Filtros que pueden traducirse a cláusulas `where` de Firestore.
  static bool hasRemoteFilters(RecordFilters filters) {
    return filters.telar != null ||
        filters.tela != null ||
        filters.turno != null ||
        filters.operario != null ||
        filters.alertLevel != null ||
        filters.dateFrom != null ||
        filters.dateTo != null ||
        filters.quickRange != null;
  }

  static Query<Map<String, dynamic>> build({
    required CollectionReference<Map<String, dynamic>> collection,
    RecordFilters? filters,
    required int limit,
  }) {
    Query<Map<String, dynamic>> query = collection;

    if (filters != null && hasRemoteFilters(filters)) {
      if (filters.telar != null && filters.telar!.trim().isNotEmpty) {
        query = query.where('telar', isEqualTo: filters.telar!.trim());
      }
      if (filters.tela != null && filters.tela!.trim().isNotEmpty) {
        query = query.where('tela', isEqualTo: filters.tela!.trim());
      }
      if (filters.turno != null && filters.turno!.trim().isNotEmpty) {
        query = query.where('turno', isEqualTo: filters.turno!.trim());
      }
      if (filters.operario != null && filters.operario!.trim().isNotEmpty) {
        query = query.where('operario', isEqualTo: filters.operario!.trim());
      }
      if (filters.alertLevel != null) {
        query = query.where(
          'alertLevel',
          isEqualTo: _alertLevelCode(filters.alertLevel!),
        );
      }

      DateTime? from = filters.dateFrom;
      DateTime? to = filters.dateTo;
      if (filters.quickRange != null) {
        final (qFrom, qTo) =
            RecordFilterHelper.resolveQuickRange(filters.quickRange!);
        from = qFrom;
        to = qTo;
      }

      if (from != null) {
        query = query.where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(from),
        );
      }
      if (to != null) {
        final toEnd = DateTime(to.year, to.month, to.day, 23, 59, 59);
        query = query.where(
          'createdAt',
          isLessThanOrEqualTo: Timestamp.fromDate(toEnd),
        );
      }
    }

    return query.orderBy('createdAt', descending: true).limit(limit);
  }

  static String _alertLevelCode(AlertLevel level) => switch (level) {
        AlertLevel.normal => 'normal',
        AlertLevel.advertencia => 'advertencia',
        AlertLevel.critico => 'critico',
      };
}
