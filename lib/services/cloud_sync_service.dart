import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/errors/error_handler.dart';
import '../core/constants.dart';
import '../firebase_options.dart';
import '../models/app_user_role.dart';
import '../models/nep_record.dart';
import '../utils/firestore_json_helper.dart';
import '../models/saved_report.dart';
import 'cloud_sync_port.dart';

class CloudSyncService implements CloudSyncPort {
  bool _bootstrapped = false;
  Future<void>? _bootstrapFuture;
  String? _userId;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _workspace =>
      _firestore.collection('workspaces').doc(cloudWorkspaceId);

  CollectionReference<Map<String, dynamic>> get _reports =>
      _workspace.collection('reports');

  DocumentReference<Map<String, dynamic>> get _fabricsDoc =>
      _workspace.collection('meta').doc('fabrics');

  DocumentReference<Map<String, dynamic>> get _configDoc =>
      _workspace.collection('meta').doc('config');

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

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw StateError('Usuario no autenticado. Inicie sesión primero.');
    }

    _userId = currentUser.uid;

    await _workspace.set(
      {
        'name': 'VICUNHA',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    _bootstrapped = true;
    _bootstrapFuture = null;
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

  @override
  Stream<List<NepRecord>> watchRecords() {
    return Stream.fromFuture(_requireUserId()).asyncExpand((userId) {
      return _userRecords(userId).orderBy('createdAt').snapshots().map(
        (snapshot) {
          return snapshot.docs.map((doc) {
            final data = Map<String, dynamic>.from(doc.data());
            data['id'] ??= doc.id;
            return NepRecord.fromJson(data);
          }).toList();
        },
      );
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
    final prefs = await SharedPreferences.getInstance();
    final migrationKey = _userMigrationKey(userId);

    if (prefs.getBool(migrationKey) == true) return;

    if (localRecords.isNotEmpty) {
      try {
        await upsertRecords(localRecords);
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
    final userId = await _requireUserId();
    await _userRecords(userId)
        .doc(record.id)
        .set(_recordData(record), SetOptions(merge: true));
  }

  @override
  Future<void> upsertRecords(List<NepRecord> records) async {
    final userId = await _requireUserId();

    for (var start = 0; start < records.length; start += 450) {
      final batch = _firestore.batch();
      final chunk = records.skip(start).take(450);

      for (final record in chunk) {
        batch.set(
          _userRecords(userId).doc(record.id),
          _recordData(record),
          SetOptions(merge: true),
        );
      }

      await batch.commit();
    }
  }

  @override
  Future<void> deleteRecord(String recordId) async {
    final userId = await _requireUserId();
    await _userRecords(userId).doc(recordId).delete();
  }

  @override
  Future<void> clearRecords() async {
    final userId = await _requireUserId();
    await _deleteCollection(_userRecords(userId));
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

  bool _listsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
