import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../firebase_options.dart';
import '../models/nep_record.dart';
import '../utils/firestore_json_helper.dart';
import '../models/saved_report.dart';
import '../utils/nep_record_merge_helper.dart';
import 'cloud_sync_port.dart';

class CloudSyncService implements CloudSyncPort {
  bool _bootstrapped = false;
  Future<void>? _bootstrapFuture;
  String? _userId;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _workspace =>
      _firestore.collection('workspaces').doc(cloudWorkspaceId);

  CollectionReference<Map<String, dynamic>> get _records =>
      _workspace.collection('records');

  CollectionReference<Map<String, dynamic>> get _reports =>
      _workspace.collection('reports');

  DocumentReference<Map<String, dynamic>> get _fabricsDoc =>
      _workspace.collection('meta').doc('fabrics');

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

    _firestore.settings = const Settings(
      persistenceEnabled: false,
    );

    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException(
            'Tiempo de espera agotado al autenticar con Firebase.',
          );
        },
      );
    }

    _userId = FirebaseAuth.instance.currentUser?.uid;
    if (_userId == null) {
      throw StateError('No se pudo autenticar el usuario para sincronizar.');
    }

    // Metadatos opcionales: no bloquean la sincronizacion de registros.
    unawaited(_writeWorkspaceMetadata());

    _bootstrapped = true;
    _bootstrapFuture = null;
  }

  Future<void> _writeWorkspaceMetadata() async {
    const timeout = Duration(seconds: 15);

    try {
      await _workspace
          .set(
            {
              'name': 'VICUNHA',
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          )
          .timeout(timeout);
    } catch (_) {
    }

    final userId = _userId;
    if (userId == null) return;

    try {
      await _workspace
          .collection('users')
          .doc(userId)
          .set(
            {
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          )
          .timeout(timeout);
    } catch (_) {
    }
  }

  Future<String> _requireUserId() async {
    await bootstrap();
    final uid = _userId ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('Usuario no autenticado.');
    }
    _userId = uid;
    return uid;
  }

  CollectionReference<Map<String, dynamic>> _userRecords(String userId) {
    return _workspace.collection('users').doc(userId).collection('records');
  }

  String _userMigrationKey(String userId) =>
      '$cloudUserMigrationKeyPrefix$userId';

  String _userToWorkspaceMigrationKey(String userId) =>
      '$cloudUserToWorkspaceMigrationKeyPrefix$userId';

  NepRecord _recordFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = Map<String, dynamic>.from(doc.data());
    data['id'] ??= doc.id;
    return NepRecord.fromJson(data);
  }

  @override
  Stream<List<NepRecord>> watchRecords() {
    return Stream.fromFuture(bootstrap()).asyncExpand((_) {
      return _records.orderBy('createdAt').snapshots().map((snapshot) {
        return snapshot.docs.map(_recordFromDoc).toList();
      });
    });
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
    await _migrateUserScopedRecordsToWorkspace(userId);

    final prefs = await SharedPreferences.getInstance();
    final migrationKey = _userMigrationKey(userId);

    final migrationDone = prefs.getBool(migrationKey) == true;

    if (migrationDone) return;

    if (localRecords.isNotEmpty) {
      await upsertRecords(localRecords);
    }

    if (localFabrics.isNotEmpty) {
      await syncFabricsWithLocal(localFabrics);
    }

    await prefs.setBool(migrationKey, true);
  }

  /// Migra registros historicos por usuario a la coleccion compartida del workspace.
  Future<void> _migrateUserScopedRecordsToWorkspace(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final migrationKey = _userToWorkspaceMigrationKey(userId);
    if (prefs.getBool(migrationKey) == true) return;

    await bootstrap();

    final userSnapshot = await _userRecords(userId).get();
    if (userSnapshot.docs.isEmpty) {
      await prefs.setBool(migrationKey, true);
      return;
    }

    final userRecords = userSnapshot.docs.map(_recordFromDoc).toList();
    final workspaceSnapshot = await _records.get();
    final workspaceRecords = workspaceSnapshot.docs.map(_recordFromDoc).toList();
    final merged = NepRecordMergeHelper.mergeById(workspaceRecords, userRecords);

    await _upsertRecordsToWorkspace(merged);

    await prefs.setBool(migrationKey, true);
  }

  @override
  Future<void> syncFabricsWithLocal(List<String> localFabrics) async {
    await bootstrap();

    final snapshot = await _fabricsDoc.get().timeout(const Duration(seconds: 15));
    final cloudFabrics = _readStringList(snapshot.data()?['items']);
    final merged = _normalizeFabrics([...cloudFabrics, ...localFabrics]);

    if (merged.isNotEmpty) {
      await saveFabrics(merged);
    }
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
    await bootstrap();
    await _records
        .doc(record.id)
        .set(_recordData(record), SetOptions(merge: true));
  }

  @override
  Future<void> upsertRecords(List<NepRecord> records) async {
    await bootstrap();
    await _upsertRecordsToWorkspace(records);
  }

  Future<void> _upsertRecordsToWorkspace(List<NepRecord> records) async {
    for (var start = 0; start < records.length; start += 450) {
      final batch = _firestore.batch();
      final chunk = records.skip(start).take(450);

      for (final record in chunk) {
        batch.set(
          _records.doc(record.id),
          _recordData(record),
          SetOptions(merge: true),
        );
      }

      await batch.commit();
    }
  }

  @override
  Future<void> deleteRecord(String recordId) async {
    await bootstrap();
    await _records.doc(recordId).delete();
  }

  @override
  Future<void> clearRecords() async {
    await bootstrap();
    await _deleteCollection(_records);
  }

  @override
  Future<void> replaceRecords(List<NepRecord> records) async {
    await clearRecords();
    if (records.isEmpty) return;
    await upsertRecords(records);
  }

  @override
  Future<List<SavedReport>> fetchReports() async {
    await bootstrap();

    QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await _reports.orderBy('createdAt', descending: true).get();
    } catch (_) {
      snapshot = await _reports.get();
    }

    final reports = snapshot.docs.map((doc) {
      final data = FirestoreJsonHelper.normalizeMap(
        Map<String, dynamic>.from(doc.data()),
      );
      data['id'] ??= doc.id;
      return SavedReport.fromJson(data);
    }).toList();

    reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return reports;
  }

  @override
  Future<SavedReport> saveReport(SavedReport report) async {
    await bootstrap();

    await _reports.doc(report.id).set(
      {
        ...report.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    return report;
  }

  @override
  Future<void> deleteReport(String reportId) async {
    await bootstrap();
    await _reports.doc(reportId).delete();
  }

  Map<String, dynamic> _recordData(NepRecord record) {
    return {
      ...record.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    while (true) {
      final snapshot = await collection.limit(450).get();
      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
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
}
