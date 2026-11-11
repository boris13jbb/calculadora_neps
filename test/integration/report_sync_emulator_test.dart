/// Pruebas de integración de sync de informes contra Firebase Emulator.
///
/// Requiere Auth (9099) + Firestore (8085) y:
/// ```
/// flutter test test/integration/report_sync_emulator_test.dart \
///   --dart-define=USE_FIREBASE_EMULATOR=true
/// ```
///
/// Proyecto ficticio de prueba: demo-vicunha-sync-test (no producción).
/// Sin USE_FIREBASE_EMULATOR=true las pruebas se omiten (no tocan prod).
library;

import 'dart:convert';
import 'dart:io';

import 'package:calculadora_neps/core/constants.dart';
import 'package:calculadora_neps/utils/report_content_fingerprint.dart';
import 'package:calculadora_neps/utils/report_upsert_decision.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

const bool useFirebaseEmulator = bool.fromEnvironment(
  'USE_FIREBASE_EMULATOR',
  defaultValue: false,
);

const String _authHost = '127.0.0.1';
const int _authPort = 9099;
const String _fsHost = '127.0.0.1';
const int _fsPort = 8085;

/// Proyecto demo aislado — nunca el ID productivo en estas pruebas.
const String _projectId = 'demo-vicunha-sync-test';
const String _apiKey = 'fake-api-key';

void main() {
  group('Emulator sync de informes', () {
    setUpAll(() async {
      if (!useFirebaseEmulator) return;
      await _assertEmulatorsReachable();
    });

    test(
      'A) dual-write online: reports + reportSummaries',
      () async {
        final user = await _createUser('rep_online');
        final reportId = 'rep_online_${user.uid}';
        final payload = _reportPayload(
          id: reportId,
          ownerUid: user.uid,
          name: 'Online',
          recordCount: 2,
        );
        final summary = _summaryPayload(
          id: reportId,
          ownerUid: user.uid,
          name: 'Online',
          recordCount: 2,
        );

        final fullRes = await _putDoc(
          token: user.idToken,
          collection: 'reports',
          docId: reportId,
          fields: payload,
        );
        final sumRes = await _putDoc(
          token: user.idToken,
          collection: 'reportSummaries',
          docId: reportId,
          fields: summary,
        );
        expect(fullRes.statusCode, anyOf(200, 201));
        expect(sumRes.statusCode, anyOf(200, 201));

        final full = await _getDoc(
          token: user.idToken,
          collection: 'reports',
          docId: reportId,
        );
        final sum = await _getDoc(
          token: user.idToken,
          collection: 'reportSummaries',
          docId: reportId,
        );
        expect(full['name'], 'Online');
        expect(sum['recordCount'], 2);
        expect(sum.containsKey('records'), isFalse);
      },
      skip: useFirebaseEmulator
          ? false
          : 'Requiere emuladores Auth+Firestore y '
              '--dart-define=USE_FIREBASE_EMULATOR=true',
    );

    test(
      'D/E) política de conflicto: remoto distinto sin base → conflict',
      () {
        final decision = decideReportUpsert(
          localFingerprint: 'local-v2',
          remoteFingerprint: 'remote-v1',
        );
        expect(decision, ReportUpsertDecision.conflict);
        expect(
          decideReportUpsert(
            localFingerprint: 'local-v2',
            remoteFingerprint: 'remote-v1',
            expectedBaseFingerprint: 'remote-v1',
          ),
          ReportUpsertDecision.write,
        );
      },
    );

    test('huella estable no depende del emulador', () {
      // Smoke: fingerprint util disponible en suite de integración.
      expect(reportContentFingerprint.hashCode, isA<int>());
      expect(cloudWorkspaceId, 'vicunha');
    });
  });
}

Future<void> _assertEmulatorsReachable() async {
  for (final entry in [
    ('Auth', _authHost, _authPort),
    ('Firestore', _fsHost, _fsPort),
  ]) {
    final label = entry.$1;
    try {
      final socket = await Socket.connect(
        entry.$2,
        entry.$3,
        timeout: const Duration(seconds: 2),
      );
      await socket.close();
    } catch (_) {
      fail(
        'USE_FIREBASE_EMULATOR=true pero el emulador $label no responde en '
        '${entry.$2}:${entry.$3}. No se usará producción.',
      );
    }
  }
}

class _EmuUser {
  _EmuUser({required this.uid, required this.idToken});
  final String uid;
  final String idToken;
}

/// Crea usuario en Auth emulator y le asigna claim `role=admin` (legacyHas).
/// El claim se aplica vía Admin SDK local contra el emulador; no toca producción.
Future<_EmuUser> _createUser(String prefix) async {
  final email = '${prefix}_${DateTime.now().microsecondsSinceEpoch}@test.local';
  final uri = Uri.parse(
    'http://$_authHost:$_authPort/identitytoolkit.googleapis.com/v1/'
    'accounts:signUp?key=$_apiKey',
  );
  final res = await http.post(
    uri,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'email': email,
      'password': 'test-password-123',
      'returnSecureToken': true,
    }),
  );
  if (res.statusCode != 200) {
    fail('No se pudo crear usuario en Auth emulator: ${res.body}');
  }
  final body = jsonDecode(res.body) as Map<String, dynamic>;
  final uid = body['localId']?.toString() ?? '';
  final refreshToken = body['refreshToken']?.toString() ?? '';
  if (uid.isEmpty || refreshToken.isEmpty) {
    fail('Respuesta Auth emulator incompleta: ${res.body}');
  }

  // Copia el entorno sin credenciales productivas (el helper las rechaza).
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

  final claimResult = await Process.run(
    'node',
    [
      'scripts/seed_emulator_admin_claim.js',
      uid,
    ],
    workingDirectory:
        '${Directory.current.path}${Platform.pathSeparator}functions',
    environment: env,
  );
  if (claimResult.exitCode != 0) {
    fail(
      'No se pudo asignar claim admin en emulator: '
      '${claimResult.stderr}\n${claimResult.stdout}',
    );
  }

  final tokenUri = Uri.parse(
    'http://$_authHost:$_authPort/securetoken.googleapis.com/v1/token?key=$_apiKey',
  );
  final tokenRes = await http.post(
    tokenUri,
    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    body: 'grant_type=refresh_token&refresh_token=$refreshToken',
  );
  if (tokenRes.statusCode != 200) {
    fail('No se pudo refrescar idToken con claims: ${tokenRes.body}');
  }
  final tokenBody = jsonDecode(tokenRes.body) as Map<String, dynamic>;
  final idToken = tokenBody['id_token']?.toString() ??
      tokenBody['idToken']?.toString() ??
      '';
  if (idToken.isEmpty) {
    fail('idToken vacío tras refresh: ${tokenRes.body}');
  }
  return _EmuUser(uid: uid, idToken: idToken);
}

Map<String, dynamic> _reportPayload({
  required String id,
  required String ownerUid,
  required String name,
  required int recordCount,
}) {
  return {
    'fields': {
      'id': {'stringValue': id},
      'name': {'stringValue': name},
      'createdAt': {'stringValue': '2026-11-10T14:00:00.000Z'},
      'createdByUid': {'stringValue': ownerUid},
      'records': {
        'arrayValue': {
          'values': [
            for (var i = 0; i < recordCount; i++)
              {
                'mapValue': {
                  'fields': {
                    'id': {'stringValue': 'r$i'},
                    'telar': {'stringValue': '7'},
                    'neps': {'doubleValue': 12},
                    'tela': {'stringValue': 'BOLTON'},
                    'loteTrama': {'stringValue': 'L-r$i'},
                    'createdAt': {'stringValue': '2026-11-10T12:00:00.000Z'},
                  },
                },
              },
          ],
        },
      },
    },
  };
}

Map<String, dynamic> _summaryPayload({
  required String id,
  required String ownerUid,
  required String name,
  required int recordCount,
}) {
  return {
    'fields': {
      'id': {'stringValue': id},
      'name': {'stringValue': name},
      'createdAt': {'stringValue': '2026-11-10T14:00:00.000Z'},
      'createdByUid': {'stringValue': ownerUid},
      'recordCount': {'integerValue': '$recordCount'},
    },
  };
}

Future<http.Response> _putDoc({
  required String token,
  required String collection,
  required String docId,
  required Map<String, dynamic> fields,
}) {
  final uri = Uri.parse(
    'http://$_fsHost:$_fsPort/v1/projects/$_projectId/databases/(default)/'
    'documents/workspaces/$cloudWorkspaceId/$collection/$docId',
  );
  return http.patch(
    uri,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
    body: jsonEncode(fields),
  );
}

Future<Map<String, dynamic>> _getDoc({
  required String token,
  required String collection,
  required String docId,
}) async {
  final uri = Uri.parse(
    'http://$_fsHost:$_fsPort/v1/projects/$_projectId/databases/(default)/'
    'documents/workspaces/$cloudWorkspaceId/$collection/$docId',
  );
  final res = await http.get(
    uri,
    headers: {'Authorization': 'Bearer $token'},
  );
  if (res.statusCode != 200) {
    fail('GET $collection/$docId falló: ${res.statusCode} ${res.body}');
  }
  final body = jsonDecode(res.body) as Map<String, dynamic>;
  final fields = body['fields'] as Map<String, dynamic>? ?? {};
  return {
    for (final e in fields.entries) e.key: _decodeField(e.value),
  };
}

dynamic _decodeField(dynamic value) {
  if (value is! Map) return value;
  if (value.containsKey('stringValue')) return value['stringValue'];
  if (value.containsKey('integerValue')) {
    return int.tryParse(value['integerValue'].toString()) ??
        value['integerValue'];
  }
  if (value.containsKey('doubleValue')) return value['doubleValue'];
  if (value.containsKey('arrayValue')) {
    final values = (value['arrayValue'] as Map?)?['values'];
    if (values is List) return values.map(_decodeField).toList();
  }
  if (value.containsKey('mapValue')) {
    final fields = (value['mapValue'] as Map?)?['fields'];
    if (fields is Map) {
      return {
        for (final e in fields.entries) e.key.toString(): _decodeField(e.value),
      };
    }
  }
  return value;
}
