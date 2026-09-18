import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show debugPrint, kDebugMode, visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/errors/error_handler.dart';
import '../core/errors/record_tombstoned_exception.dart';
import '../core/constants.dart';
import '../core/permissions/record_visibility.dart';
import '../firebase_options.dart';
import '../models/app_user_role.dart';
import '../models/nep_record.dart';
import '../models/record_filters.dart';
import '../models/record_tombstone.dart';
import '../models/records_page_result.dart';
import '../utils/firestore_json_helper.dart';
import '../models/saved_report.dart';
import 'cloud_sync_port.dart';
import 'firestore_record_query_builder.dart';

/// Una escritura delete-wins por registro al vaciar (clearRecords).
@visibleForTesting
class ClearRecordsWrite {
  const ClearRecordsWrite({
    required this.recordId,
    required this.ownerUid,
    required this.deletedByUid,
  });

  final String recordId;
  final String ownerUid;
  final String deletedByUid;

  static const int writesPerRecord = 3; // workspace + user + tombstone

  bool get createsTombstone => true;
  bool get deletesWorkspaceMirror => true;
  bool get deletesUserMirror => true;
  bool get touchesReports => false;
}

class CloudSyncService implements CloudSyncPort {
  CloudSyncService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestoreOverride = firestore,
        _authOverride = auth;

  final FirebaseFirestore? _firestoreOverride;
  final FirebaseAuth? _authOverride;

  /// Máximo de operaciones por batch Firestore al vaciar (margen < 500).
  @visibleForTesting
  static const int clearRecordsMaxWritesPerBatch = 450;

  /// Máximo de registros por batch (= floor(450/3)).
  @visibleForTesting
  static const int clearRecordsMaxRecordsPerBatch =
      clearRecordsMaxWritesPerBatch ~/ ClearRecordsWrite.writesPerRecord;

  /// Planifica deletes + tombstones por lotes seguros.
  @visibleForTesting
  static List<List<ClearRecordsWrite>> planClearBatches({
    required Iterable<String> recordIds,
    required String ownerUid,
    required String deletedByUid,
    int? maxRecordsPerBatch,
  }) {
    final limit = maxRecordsPerBatch ?? clearRecordsMaxRecordsPerBatch;
    final safeLimit = limit < 1 ? 1 : limit;
    final ids = recordIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final batches = <List<ClearRecordsWrite>>[];
    for (var i = 0; i < ids.length; i += safeLimit) {
      final end = (i + safeLimit < ids.length) ? i + safeLimit : ids.length;
      batches.add([
        for (final id in ids.sublist(i, end))
          ClearRecordsWrite(
            recordId: id,
            ownerUid: ownerUid,
            deletedByUid: deletedByUid,
          ),
      ]);
    }
    return batches;
  }

  bool _bootstrapped = false;
  Future<void>? _bootstrapFuture;
  String? _userId;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  DocumentReference<Map<String, dynamic>> get _workspace =>
      _firestore.collection('workspaces').doc(cloudWorkspaceId);

  CollectionReference<Map<String, dynamic>> get _workspaceRecords =>
      _workspace.collection('records');

  CollectionReference<Map<String, dynamic>> get _recordTombstones =>
      _workspace.collection('record_tombstones');

  CollectionReference<Map<String, dynamic>> get _reports =>
      _workspace.collection('reports');

  DocumentReference<Map<String, dynamic>> get _fabricsDoc =>
      _workspace.collection('meta').doc('fabrics');

  DocumentReference<Map<String, dynamic>> get _configDoc =>
      _workspace.collection('meta').doc('config');

  /// Limpia el estado de bootstrap tras cerrar sesión.
  void resetSession() {
    _bootstrapped = false;
    _bootstrapFuture = null;
    _userId = null;
  }

  @override
  Future<void> bootstrap() async {
    if (_bootstrapped) return;
    if (_bootstrapFuture != null) return _bootstrapFuture;

    _bootstrapFuture = _doBootstrap().whenComplete(() {
      if (!_bootstrapped) _bootstrapFuture = null;
    });
    await _bootstrapFuture;
  }

  Future<void> _doBootstrap() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw StateError('Usuario no autenticado. Inicie sesión primero.');
    }

    // Solo enlaza sesión. No escribe workspaces/{id}: roles de solo lectura
    // (p. ej. auditor_prueba) no tienen manageSettings y Rules denegarían el set.
    _userId = currentUser.uid;
    _bootstrapped = true;
    _bootstrapFuture = null;
  }

  /// El bootstrap de sync es read-only: no toca el documento workspace.
  @visibleForTesting
  static const bool touchesWorkspaceOnBootstrap = false;

  Future<String> _requireUserId() async {
    await bootstrap();
    final uid = _userId ?? _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Usuario no autenticado.');
    }
    _userId = uid;
    return uid;
  }

  CollectionReference<Map<String, dynamic>> _userRecords(String userId) {
    return _workspace.collection('users').doc(userId).collection('records');
  }

  CollectionReference<Map<String, dynamic>> _recordsCollectionForRole(
    AppUserRole viewerRole,
    String userId, {
    String? viewerRoleCode,
  }) {
    final code = viewerRoleCode ?? viewerRole.code;
    if (canViewWorkspaceRecordsForCode(code)) {
      return _workspaceRecords;
    }
    return _userRecords(userId);
  }

  String _userMigrationKey(String userId) =>
      '$cloudUserMigrationKeyPrefix$userId';

  @override
  Stream<List<NepRecord>> watchRecords({
    AppUserRole viewerRole = AppUserRole.operario,
    String? viewerRoleCode,
  }) {
    return watchRecentRecords(
      viewerRole: viewerRole,
      viewerRoleCode: viewerRoleCode,
      limit: recordsMaxPageSize,
    ).map((page) => page.records);
  }

  @override
  Stream<RecordsPageResult> watchRecentRecords({
    AppUserRole viewerRole = AppUserRole.operario,
    String? viewerRoleCode,
    int limit = recordsInitialPageSize,
  }) {
    return Stream.fromFuture(_requireUserId()).asyncExpand((userId) {
      final collection = _recordsCollectionForRole(
        viewerRole,
        userId,
        viewerRoleCode: viewerRoleCode,
      );
      final query = FirestoreRecordQueryBuilder.build(
        collection: collection,
        limit: limit,
      );
      return _watchQuery(query, limit);
    });
  }

  @override
  Stream<RecordsPageResult> watchRecordsByDateRange({
    required DateTime from,
    required DateTime to,
    AppUserRole viewerRole = AppUserRole.operario,
    String? viewerRoleCode,
    int limit = recordsInitialPageSize,
  }) {
    final filters = RecordFilters()
      ..dateFrom = from
      ..dateTo = to;
    return watchRecordsByFilters(
      filters: filters,
      viewerRole: viewerRole,
      viewerRoleCode: viewerRoleCode,
      limit: limit,
    );
  }

  @override
  Stream<RecordsPageResult> watchRecordsByFilters({
    required RecordFilters filters,
    AppUserRole viewerRole = AppUserRole.operario,
    String? viewerRoleCode,
    int limit = recordsInitialPageSize,
  }) {
    return Stream.fromFuture(_requireUserId()).asyncExpand((userId) {
      final collection = _recordsCollectionForRole(
        viewerRole,
        userId,
        viewerRoleCode: viewerRoleCode,
      );
      final query = FirestoreRecordQueryBuilder.build(
        collection: collection,
        filters: filters,
        limit: limit,
      );
      return _watchQuery(query, limit);
    });
  }

  @override
  Future<RecordsPageResult> fetchRecordsByFilters({
    required RecordFilters filters,
    AppUserRole viewerRole = AppUserRole.operario,
    String? viewerRoleCode,
    int limit = reportExportRecordLimit,
  }) async {
    final userId = await _requireUserId();
    final collection = _recordsCollectionForRole(
      viewerRole,
      userId,
      viewerRoleCode: viewerRoleCode,
    );
    final query = FirestoreRecordQueryBuilder.build(
      collection: collection,
      filters: filters,
      limit: limit,
    );
    final snapshot = await query.get();
    final records = snapshot.docs.map(_recordFromDoc).toList();
    return RecordsPageResult(
      records: records,
      hasMore: snapshot.docs.length >= limit,
      queryLimit: limit,
    );
  }

  Stream<RecordsPageResult> _watchQuery(
    Query<Map<String, dynamic>> query,
    int limit,
  ) {
    return query.snapshots().map((snapshot) {
      final records = snapshot.docs.map(_recordFromDoc).toList();
      final hasMore = snapshot.docs.length >= limit;
      if (kDebugMode) {
        debugPrint(
          '[cloudSync] records snapshot: ${records.length} items (limit=$limit)',
        );
      }
      return RecordsPageResult(
        records: records,
        hasMore: hasMore,
        queryLimit: limit,
      );
    });
  }

  NepRecord _recordFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = Map<String, dynamic>.from(doc.data());
    data['id'] ??= doc.id;
    data['createdByUid'] ??=
        data['ownerUid'] ?? doc.reference.parent.parent?.id;
    final createdAt = data['createdAt'];
    if (createdAt is Timestamp) {
      data['createdAt'] = createdAt.toDate().toIso8601String();
    }
    final updatedAt = data['updatedAt'];
    if (updatedAt is Timestamp) {
      data['updatedAt'] = updatedAt.toDate().toIso8601String();
    }
    return NepRecord.fromJson(data);
  }

  @override
  Stream<List<String>> watchFabrics() {
    return _fabricsDoc.snapshots().map((snapshot) {
      final data = snapshot.data();
      return _normalizeFabrics(_readStringList(data?['items']));
    });
  }

  @override
  Future<void> migrateLocalDataIfNeeded({
    required List<NepRecord> localRecords,
    required List<String> localFabrics,
  }) async {
    final userId = await _requireUserId();
    final prefs = await SharedPreferences.getInstance();
    final migrationKey = _userMigrationKey(userId);

    if (prefs.getBool(migrationKey) == true) return;

    // Criterio verificable: solo createdByUid == usuario autenticado.
    // Los registros sin dueño (ambiguos) NO se suben ni se reasignan.
    final migratable = localRecords
        .where((record) => recordBelongsToUid(record, userId))
        .toList(growable: false);

    if (migratable.isNotEmpty) {
      try {
        final allowed = <NepRecord>[];
        for (final record in migratable) {
          if (await hasRecordTombstone(record.id)) {
            continue;
          }
          allowed.add(record);
        }
        if (allowed.isNotEmpty) {
          await upsertRecords(allowed);
        }
      } catch (error, stackTrace) {
        ErrorHandler.log(error, stackTrace, 'migrateRecords');
      }
    }

    if (localFabrics.isNotEmpty) {
      try {
        await syncFabricsWithLocal(localFabrics);
      } catch (error, stackTrace) {
        ErrorHandler.log(error, stackTrace, 'migrateFabrics');
      }
    }

    await prefs.setBool(migrationKey, true);
  }

  @override
  Future<void> syncFabricsWithLocal(List<String> localFabrics) async {
    await bootstrap();

    if (localFabrics.isEmpty) return;

    final snapshot = await _fabricsDoc.get();
    final cloudFabrics = _readStringList(snapshot.data()?['items']);
    final merged = _normalizeFabrics([...cloudFabrics, ...localFabrics]);

    if (_listsEqual(merged, cloudFabrics)) return;

    await saveFabrics(merged);
  }

  @override
  Future<List<String>> saveFabrics(List<String> fabrics) async {
    await bootstrap();

    final normalized = _normalizeFabrics(fabrics);
    await _fabricsDoc.set(
      {
        'items': normalized,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    return normalized;
  }

  @override
  Future<void> upsertRecord(NepRecord record) async {
    final currentUid = await _requireUserId();
    final verified = verifiedRecordOwnerUid(record);
    var ownerUid = verified ?? currentUid;

    if (verified != null && verified != currentUid) {
      final role = await fetchUserRole();
      if (!role.isSupervisorOrAbove) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'No se puede escribir un registro de otro propietario.',
        );
      }
      ownerUid = verified;
    }

    final stamped = record.createdByUid == null || record.createdByUid!.isEmpty
        ? record.copyWith(createdByUid: currentUid)
        : record;
    if (stamped.captureSessionId == null ||
        stamped.captureSessionId!.trim().isEmpty) {
      throw ArgumentError(
        'captureSessionId es obligatorio para escrituras nuevas.',
      );
    }

    final data = _recordData(stamped, ownerUid);
    final tombRef = _recordTombstones.doc(stamped.id);
    final userRef = _userRecords(ownerUid).doc(stamped.id);
    final workspaceRef = _workspaceRecords.doc(stamped.id);

    await _firestore.runTransaction((transaction) async {
      final tombSnap = await transaction.get(tombRef);
      if (tombSnap.exists) {
        throw RecordTombstonedException(stamped.id);
      }
      transaction.set(userRef, data, SetOptions(merge: true));
      transaction.set(workspaceRef, data, SetOptions(merge: true));
    });
  }

  @override
  Future<void> upsertRecords(List<NepRecord> records) async {
    for (final record in records) {
      try {
        await upsertRecord(record);
      } on RecordTombstonedException {
        // DELETE > UPSERT: un ID tombstoned no aborta el resto.
        continue;
      }
    }
  }

  @override
  Future<void> deleteRecord(String recordId, {String? ownerUid}) async {
    final currentUid = await _requireUserId();

    var resolvedOwner = ownerUid?.trim();
    var legacyResolution = 'provided';
    if (resolvedOwner == null || resolvedOwner.isEmpty) {
      legacyResolution = 'unresolved';
      try {
        final snap = await _workspaceRecords.doc(recordId).get();
        if (snap.exists) {
          final resolved = resolveOwnerUidForDelete(
            providedOwnerUid: null,
            workspaceDocData: snap.data(),
          );
          if (resolved != null) {
            resolvedOwner = resolved;
            final data = snap.data();
            final fromOwner = data?['ownerUid']?.toString().trim();
            legacyResolution = (fromOwner != null && fromOwner.isNotEmpty)
                ? 'workspace.ownerUid'
                : 'workspace.createdByUid';
          }
        } else {
          legacyResolution = 'workspace_missing';
        }
      } catch (error, stackTrace) {
        ErrorHandler.log(error, stackTrace, 'resolveDeleteOwnerUid');
      }
    }

    if (kDebugMode) {
      debugPrint(
        '[deleteRecord] LEGACY_OWNER_RESOLUTION=$legacyResolution '
        'owner=${resolvedOwner ?? '(none)'} recordId=$recordId',
      );
    }

    final batch = _firestore.batch();
    // Workspace siempre; espejo de usuario solo con owner verificable.
    batch.delete(_workspaceRecords.doc(recordId));
    if (resolvedOwner != null && resolvedOwner.isNotEmpty) {
      batch.delete(_userRecords(resolvedOwner).doc(recordId));
    }
    batch.set(_recordTombstones.doc(recordId), {
      'recordId': recordId,
      'ownerUid': resolvedOwner ?? '',
      'deletedByUid': currentUid,
      'deletedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  @override
  Stream<List<RecordTombstone>> watchRecordTombstones() {
    return _recordTombstones.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => _tombstoneFromDoc(doc.id, doc.data()))
          .where((t) => t.recordId.isNotEmpty)
          .toList(growable: false);
    });
  }

  @override
  Future<bool> hasRecordTombstone(String recordId) async {
    final id = recordId.trim();
    if (id.isEmpty) return false;
    final snap = await _recordTombstones.doc(id).get();
    return snap.exists;
  }

  RecordTombstone _tombstoneFromDoc(String docId, Map<String, dynamic> data) {
    final deletedAtRaw = data['deletedAt'];
    DateTime deletedAt;
    if (deletedAtRaw is Timestamp) {
      deletedAt = deletedAtRaw.toDate();
    } else {
      deletedAt = DateTime.tryParse(deletedAtRaw?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
    }
    final recordId = data['recordId']?.toString().trim();
    return RecordTombstone(
      recordId: (recordId == null || recordId.isEmpty) ? docId : recordId,
      ownerUid: data['ownerUid']?.toString() ?? '',
      deletedByUid: data['deletedByUid']?.toString() ?? '',
      deletedAt: deletedAt,
    );
  }

  /// Resuelve el dueño para borrar sin asumir el UID del actor autenticado.
  @visibleForTesting
  static String? resolveOwnerUidForDelete({
    required String? providedOwnerUid,
    Map<String, dynamic>? workspaceDocData,
  }) {
    final provided = providedOwnerUid?.trim();
    if (provided != null && provided.isNotEmpty) return provided;
    if (workspaceDocData == null) return null;
    final owner = workspaceDocData['ownerUid']?.toString().trim();
    if (owner != null && owner.isNotEmpty) return owner;
    final created = workspaceDocData['createdByUid']?.toString().trim();
    if (created != null && created.isNotEmpty) return created;
    return null;
  }

  @override
  Future<void> clearRecords() async {
    final userId = await _requireUserId();

    // IDs propios: espejo de usuario + workspace filtrado por ownerUid.
    final ownedIds = <String>{};
    await _collectDocumentIds(_userRecords(userId), ownedIds);
    try {
      QueryDocumentSnapshot<Map<String, dynamic>>? cursor;
      while (true) {
        Query<Map<String, dynamic>> query =
            _workspaceRecords.where('ownerUid', isEqualTo: userId).limit(200);
        if (cursor != null) {
          query = query.startAfterDocument(cursor);
        }
        final snapshot = await query.get();
        if (snapshot.docs.isEmpty) break;
        for (final doc in snapshot.docs) {
          ownedIds.add(doc.id);
        }
        cursor = snapshot.docs.last;
        if (snapshot.docs.length < 200) break;
      }
    } on FirebaseException catch (error, stackTrace) {
      if (error.code != 'permission-denied') {
        ErrorHandler.log(error, stackTrace, 'clearOwnedWorkspaceRecords');
        rethrow;
      }
    }

    final batches = planClearBatches(
      recordIds: ownedIds,
      ownerUid: userId,
      deletedByUid: userId,
    );

    for (final batchWrites in batches) {
      final batch = _firestore.batch();
      for (final write in batchWrites) {
        batch.delete(_workspaceRecords.doc(write.recordId));
        batch.delete(_userRecords(write.ownerUid).doc(write.recordId));
        batch.set(_recordTombstones.doc(write.recordId), {
          'recordId': write.recordId,
          'ownerUid': write.ownerUid,
          'deletedByUid': write.deletedByUid,
          'deletedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }

  @override
  @Deprecated('Evitar: reescribe la caché local como fuente autoritativa.')
  Future<void> replaceRecords(List<NepRecord> records) async {
    throw UnsupportedError(
      'replaceRecords está deshabilitado: no puede reinsertar IDs tombstoned '
      'desde la caché local.',
    );
  }

  @override
  Future<List<SavedReport>> fetchReports() async {
    await bootstrap();

    QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await _reports.orderBy('createdAt', descending: true).get();
    } on FirebaseException catch (error, stackTrace) {
      ErrorHandler.log(error, stackTrace, 'fetchReportsOrderBy');
      if (error.code == 'failed-precondition' ||
          error.code == 'invalid-argument') {
        snapshot = await _reports.get();
      } else {
        rethrow;
      }
    } catch (error, stackTrace) {
      ErrorHandler.log(error, stackTrace, 'fetchReportsOrderByFallback');
      snapshot = await _reports.get();
    }

    final reports = <SavedReport>[];
    var skipped = 0;
    for (final doc in snapshot.docs) {
      try {
        final data = FirestoreJsonHelper.normalizeMap(
          Map<String, dynamic>.from(doc.data()),
        );
        data['id'] ??= doc.id;
        final parsed = SavedReport.tryFromJson(data);
        if (parsed == null) {
          skipped++;
          ErrorHandler.log(
            StateError('Informe cloud omitido id=${doc.id}'),
            StackTrace.current,
            'fetchReports',
          );
          continue;
        }
        reports.add(parsed);
      } catch (error, stackTrace) {
        skipped++;
        ErrorHandler.log(error, stackTrace, 'fetchReportsDoc');
      }
    }
    if (skipped > 0) {
      ErrorHandler.log(
        StateError('fetchReports omitió $skipped documento(s) inválidos'),
        StackTrace.current,
        'fetchReports',
      );
    }

    reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return reports;
  }

  @override
  Future<SavedReport> saveReport(SavedReport report) async {
    await bootstrap();
    final uid = await _requireUserId();
    final stamped =
        (report.createdByUid == null || report.createdByUid!.trim().isEmpty)
            ? SavedReport(
                id: report.id,
                name: report.name,
                createdAt: report.createdAt,
                records: report.records,
                appliedFilters: report.appliedFilters,
                createdByUid: uid,
              )
            : report;

    await _reports.doc(stamped.id).set(
      {
        ...stamped.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    return stamped;
  }

  @override
  Future<void> deleteReport(String reportId) async {
    await bootstrap();
    await _reports.doc(reportId).delete();
  }

  @override
  Future<AppUserRole> fetchUserRole() async {
    final userId = await _requireUserId();
    final snap = await _workspace.collection('users').doc(userId).get();
    return AppUserRole.fromCode(snap.data()?['role']?.toString());
  }

  @override
  Future<Map<String, dynamic>?> fetchAlertConfig() async {
    await bootstrap();
    final snap = await _configDoc.get();
    return snap.data();
  }

  @override
  Future<void> saveAlertConfig(Map<String, dynamic> config) async {
    await bootstrap();
    await _configDoc.set(
      {
        ...config,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> registerFcmToken(String token) async {
    final userId = await _requireUserId();
    await _workspace.collection('users').doc(userId).set(
      {
        'fcmToken': token,
        'fcmUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Map<String, dynamic> _recordData(NepRecord record, String ownerUid) {
    final payload = Map<String, dynamic>.from(record.toJson());
    payload['createdAt'] = Timestamp.fromDate(record.createdAt);
    if (record.fechaRevision != null) {
      payload['fechaRevision'] = Timestamp.fromDate(record.fechaRevision!);
    }
    // Autoría y propietario alineados; no se falsifican desde el payload.
    final createdBy = record.createdByUid?.trim();
    return {
      ...payload,
      'ownerUid': ownerUid,
      'createdByUid':
          (createdBy != null && createdBy.isNotEmpty) ? createdBy : ownerUid,
      'alertLevel': record.alertLevel.name,
      'mtsCalculados': record.mtsCalculados,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Future<void> _collectDocumentIds(
    CollectionReference<Map<String, dynamic>> collection,
    Set<String> into,
  ) async {
    QueryDocumentSnapshot<Map<String, dynamic>>? cursor;
    while (true) {
      Query<Map<String, dynamic>> query = collection.limit(200);
      if (cursor != null) {
        query = query.startAfterDocument(cursor);
      }
      final snapshot = await query.get();
      if (snapshot.docs.isEmpty) return;
      for (final doc in snapshot.docs) {
        into.add(doc.id);
      }
      cursor = snapshot.docs.last;
      if (snapshot.docs.length < 200) return;
    }
  }

  List<String> _readStringList(dynamic value) {
    if (value is! List) return [];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  List<String> _normalizeFabrics(List<String> fabrics) {
    final seen = <String>{};
    final result = <String>[];

    for (final raw in fabrics) {
      final name = raw.trim();
      if (name.isEmpty) continue;

      if (seen.add(name.toUpperCase())) {
        result.add(name);
      }
    }

    result.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return result;
  }

  bool _listsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
