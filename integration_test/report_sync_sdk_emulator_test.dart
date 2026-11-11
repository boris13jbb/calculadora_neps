/// Integración FlutterFire SDK + Auth/Firestore Emulator.
///
/// Solo con:
/// ```
/// firebase emulators:start --only auth,firestore --project demo-vicunha-sync-test
/// flutter test integration_test/report_sync_sdk_emulator_test.dart -d windows \
///   --dart-define=USE_FIREBASE_EMULATOR=true
/// ```
///
/// Sin el dart-define, las pruebas se omiten (no tocan producción).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:calculadora_neps/core/constants.dart';
import 'package:calculadora_neps/models/nep_record.dart';
import 'package:calculadora_neps/models/report_sync_status.dart';
import 'package:calculadora_neps/models/saved_report.dart';
import 'package:calculadora_neps/services/cloud_sync_service.dart';
import 'package:calculadora_neps/services/pending_report_sync_queue_service.dart';
import 'package:calculadora_neps/services/report_storage_service.dart';
import 'package:calculadora_neps/services/report_sync_meta_store.dart';
import 'package:calculadora_neps/utils/report_content_fingerprint.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const bool useFirebaseEmulator = bool.fromEnvironment(
  'USE_FIREBASE_EMULATOR',
  defaultValue: false,
);

const String _projectId = 'demo-vicunha-sync-test';
const String _authHost = '127.0.0.1';
const int _authPort = 9099;
const String _fsHost = '127.0.0.1';
const int _fsPort = 8085;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('FlutterFire SDK + Emulator (cola informes)', () {
    setUpAll(() async {
      if (!useFirebaseEmulator) return;
      await _assertLocalEmulators();
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'fake-api-key',
          appId: '1:1234567890:web:demo-vicunha-sync-test',
          messagingSenderId: '1234567890',
          projectId: _projectId,
        ),
      );
      FirebaseFirestore.instance.useFirestoreEmulator(_fsHost, _fsPort);
      await FirebaseAuth.instance.useAuthEmulator(_authHost, _authPort);
    });

    tearDown(() async {
      if (!useFirebaseEmulator) return;
      await FirebaseAuth.instance.signOut();
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets(
      '1) guardado online → reports+summary synced',
      (tester) async {
        final user = await _signInAdmin('online');
        final storage = _buildStorage();
        final report = _report(user.uid, name: 'Online SDK', records: 2);

        final outcome = await storage.saveExistingReport(
          report,
          saveFiles: false,
          actorUid: user.uid,
        );
        expect(outcome.status, ReportSyncStatus.synced);
        expect(outcome.pendingOp, isNull);

        final full = await FirebaseFirestore.instance
            .collection('workspaces')
            .doc(cloudWorkspaceId)
            .collection('reports')
            .doc(report.id)
            .get();
        final summary = await FirebaseFirestore.instance
            .collection('workspaces')
            .doc(cloudWorkspaceId)
            .collection('reportSummaries')
            .doc(report.id)
            .get();
        expect(full.exists, isTrue);
        expect(summary.exists, isTrue);
        expect(full.data()?['createdByUid'], user.uid);
        expect(summary.data()?['recordCount'], 2);
        expect(summary.data()?.containsKey('records'), isFalse);

        final pending = await storage.pendingReportQueue.loadForUid(user.uid);
        expect(pending, isEmpty);
      },
      skip: !useFirebaseEmulator,
    );

    testWidgets(
      '2-3) offline → pendiente; reconexión → synced sin duplicar',
      (tester) async {
        final user = await _signInAdmin('offline');
        final storageOffline = _buildStorage(sessionActive: false);
        final report = _report(user.uid, name: 'Offline SDK', records: 1);

        final offline = await storageOffline.saveExistingReport(
          report,
          saveFiles: false,
          actorUid: user.uid,
        );
        expect(offline.status, ReportSyncStatus.localPending);
        expect(offline.offlineHint, isTrue);
        expect(offline.userMessage, isNot(contains('sincronizado')));

        var pending =
            await storageOffline.pendingReportQueue.loadForUid(user.uid);
        expect(pending.length, 1);
        expect(pending.first.reportId, report.id);

        final storageOnline = _buildStorage(sessionActive: true);
        final flushed = await storageOnline.flushPendingReports(uid: user.uid);
        expect(flushed, isNotEmpty);
        expect(flushed.first.status, ReportSyncStatus.synced);

        pending = await storageOnline.pendingReportQueue.loadForUid(user.uid);
        expect(pending, isEmpty);

        final again = await storageOnline.saveExistingReport(
          report,
          saveFiles: false,
          actorUid: user.uid,
        );
        expect(again.status, ReportSyncStatus.synced);

        final summaries = await FirebaseFirestore.instance
            .collection('workspaces')
            .doc(cloudWorkspaceId)
            .collection('reportSummaries')
            .where(FieldPath.documentId, isEqualTo: report.id)
            .get();
        expect(summaries.docs.length, 1);
      },
      skip: !useFirebaseEmulator,
    );

    testWidgets(
      '5) conflicto entre versiones no sobrescribe',
      (tester) async {
        final user = await _signInAdmin('conflict');
        final storage = _buildStorage();
        final base = _report(user.uid, name: 'Base', records: 1);
        final synced = await storage.saveExistingReport(
          base,
          saveFiles: false,
          actorUid: user.uid,
        );
        expect(synced.status, ReportSyncStatus.synced);

        // Simula otro dispositivo: actualiza con base conocida (legítimo).
        final remote = SavedReport(
          id: base.id,
          name: 'Remoto-dispositivo-B',
          createdAt: base.createdAt,
          records: base.records,
          createdByUid: user.uid,
        );
        await CloudSyncService().saveReport(
          remote,
          expectedBaseFingerprint: reportContentFingerprint(base),
        );

        // Cliente A intenta subir otra versión sin baseFingerprint remota.
        SharedPreferences.setMockInitialValues({});
        final storageA = _buildStorage();
        await storageA.pendingReportQueue.clear(user.uid);
        final localA = SavedReport(
          id: base.id,
          name: 'Local-dispositivo-A',
          createdAt: base.createdAt,
          records: [
            NepRecord(
              id: 'rA',
              telar: '7',
              tela: 'BOLTON',
              loteTrama: 'L-A',
              neps: 20,
              createdAt: DateTime.utc(2026, 11, 10, 12),
            ),
          ],
          createdByUid: user.uid,
        );
        final conflict = await storageA.saveExistingReport(
          localA,
          saveFiles: false,
          actorUid: user.uid,
        );
        expect(conflict.status, ReportSyncStatus.conflict);

        final remoteSnap = await FirebaseFirestore.instance
            .collection('workspaces')
            .doc(cloudWorkspaceId)
            .collection('reports')
            .doc(base.id)
            .get();
        expect(remoteSnap.data()?['name'], 'Remoto-dispositivo-B');
      },
      skip: !useFirebaseEmulator,
    );

    testWidgets(
      '6) usuario B no ve cola de A',
      (tester) async {
        final a = await _signInAdmin('user_a');
        final storageA = _buildStorage(sessionActive: false);
        final report = _report(a.uid, name: 'Solo A', records: 1);
        await storageA.saveExistingReport(
          report,
          saveFiles: false,
          actorUid: a.uid,
        );
        final pendingA = await storageA.pendingReportQueue.loadForUid(a.uid);
        expect(pendingA, isNotEmpty);

        await FirebaseAuth.instance.signOut();
        final b = await _signInAdmin('user_b');
        final storageB = _buildStorage();
        final pendingB = await storageB.pendingReportQueue.loadForUid(b.uid);
        expect(pendingB, isEmpty);
        final flushed = await storageB.flushPendingReports(uid: b.uid);
        expect(flushed, isEmpty);
        expect(a.uid, isNot(b.uid));
      },
      skip: !useFirebaseEmulator,
    );

    testWidgets(
      '8-10) reinicio conserva pendiente; personalSessions intacto',
      (tester) async {
        final user = await _signInAdmin('restart');
        final prefsSeed = <String, Object>{
          personalSessionsKeyForUid(user.uid): '[{"keep":true}]',
        };
        SharedPreferences.setMockInitialValues(prefsSeed);

        final storage1 = _buildStorage(sessionActive: false);
        final report = _report(user.uid, name: 'Persist', records: 1);
        await storage1.saveExistingReport(
          report,
          saveFiles: false,
          actorUid: user.uid,
        );

        // Nueva instancia (reinicio de servicio).
        final storage2 = _buildStorage(sessionActive: false);
        final pending = await storage2.pendingReportQueue.loadForUid(user.uid);
        expect(pending.length, 1);
        expect(pending.first.reportId, report.id);

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString(personalSessionsKeyForUid(user.uid)),
          '[{"keep":true}]',
        );
      },
      skip: !useFirebaseEmulator,
    );
  });
}

ReportStorageService _buildStorage({bool sessionActive = true}) {
  return ReportStorageService(
    cloudSync: CloudSyncService(),
    pendingReportQueue: PendingReportSyncQueueService(),
    syncMetaStore: ReportSyncMetaStore(),
    isSessionActive: () => sessionActive,
  );
}

SavedReport _report(String uid, {required String name, required int records}) {
  return SavedReport(
    id: 'rep_sdk_${uid}_${DateTime.now().microsecondsSinceEpoch}',
    name: name,
    createdAt: DateTime.utc(2026, 11, 10, 14),
    createdByUid: uid,
    records: [
      for (var i = 0; i < records; i++)
        NepRecord(
          id: 'r$i',
          telar: '7',
          tela: 'BOLTON',
          loteTrama: 'L-$i',
          neps: 12,
          createdAt: DateTime.utc(2026, 11, 10, 12),
        ),
    ],
  );
}

Future<User> _signInAdmin(String prefix) async {
  final email = '${prefix}_${DateTime.now().microsecondsSinceEpoch}@test.local';
  final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
    email: email,
    password: 'test-password-123',
  );
  final user = cred.user;
  if (user == null) {
    fail('Auth emulator no devolvió usuario');
  }
  final emailForResign = user.email;
  await _seedAdminClaim(user.uid);
  // Tras setCustomUserClaims: re-login en lugar de getIdToken(true)
  // (en Windows+emulator el force-refresh a veces falla con unknown-error).
  await FirebaseAuth.instance.signOut();
  if (emailForResign == null || emailForResign.isEmpty) {
    fail('Usuario sin email tras createUser');
  }
  final again = await FirebaseAuth.instance.signInWithEmailAndPassword(
    email: emailForResign,
    password: 'test-password-123',
  );
  final signed = again.user;
  if (signed == null) {
    fail('Re-login tras claim admin falló');
  }
  return signed;
}

Future<void> _seedAdminClaim(String uid) async {
  final env = Map<String, String>.from(Platform.environment);
  env.removeWhere(
    (key, _) =>
        key.toLowerCase() == 'google_application_credentials' ||
        key.toLowerCase() == 'firebase_config',
  );
  env['FIREBASE_AUTH_EMULATOR_HOST'] = '$_authHost:$_authPort';
  env['FIRESTORE_EMULATOR_HOST'] = '$_fsHost:$_fsPort';
  env['GCLOUD_PROJECT'] = _projectId;
  env['GOOGLE_CLOUD_PROJECT'] = _projectId;
  final result = await Process.run(
    'node',
    ['scripts/seed_emulator_admin_claim.js', uid],
    workingDirectory:
        '${Directory.current.path}${Platform.pathSeparator}functions',
    environment: env,
  );
  if (result.exitCode != 0) {
    fail('seed claim falló: ${result.stderr}\n${result.stdout}');
  }
}

Future<void> _assertLocalEmulators() async {
  for (final entry in [
    ('Auth', _authHost, _authPort),
    ('Firestore', _fsHost, _fsPort),
  ]) {
    try {
      final socket = await Socket.connect(
        entry.$2,
        entry.$3,
        timeout: const Duration(seconds: 2),
      );
      await socket.close();
    } catch (_) {
      fail(
        'Emulador ${entry.$1} no responde en ${entry.$2}:${entry.$3}. '
        'Usar solo demo-vicunha-sync-test.',
      );
    }
  }
  // Defensa adicional: no permitir project productivo en este harness.
  expect(_projectId, 'demo-vicunha-sync-test');
  expect(reportContentFingerprint.hashCode, isA<int>());
  // Ping HTTP Auth (sin tokens en logs).
  final res = await http.get(Uri.parse('http://$_authHost:$_authPort/'));
  expect(res.statusCode, lessThan(500));
  // Evita usar jsonDecode de respuesta Auth en logs.
  expect(jsonEncode({'ok': true}), contains('ok'));
}
