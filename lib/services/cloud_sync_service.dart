import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../firebase_options.dart';
import '../models/nep_record.dart';
import '../models/saved_report.dart';
import 'cloud_sync_port.dart';

class CloudSyncService implements CloudSyncPort {
  bool _bootstrapped = false;
  Future<void>? _bootstrapFuture;

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

    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }

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

  @override
  Stream<List<NepRecord>> watchRecords() {
    return _records.orderBy('createdAt').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] ??= doc.id;
        return NepRecord.fromJson(data);
      }).toList();
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
    await bootstrap();

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(cloudMigrationKey) == true) return;

    if (localRecords.isNotEmpty) {
      await upsertRecords(localRecords);
    }

    if (localFabrics.isNotEmpty) {
      await syncFabricsWithLocal(localFabrics);
    }

    await prefs.setBool(cloudMigrationKey, true);
  }

  @override
  Future<void> syncFabricsWithLocal(List<String> localFabrics) async {
    await bootstrap();

    final snapshot = await _fabricsDoc.get();
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
    await bootstrap();
    await clearRecords();
    await upsertRecords(records);
  }

  @override
  Future<List<SavedReport>> fetchReports() async {
    await bootstrap();

    final snapshot =
        await _reports.orderBy('createdAt', descending: true).get();
    return snapshot.docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data());
      data['id'] ??= doc.id;
      return SavedReport.fromJson(data);
    }).toList();
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
