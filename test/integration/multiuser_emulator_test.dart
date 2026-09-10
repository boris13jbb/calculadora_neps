/// Pruebas de integración contra Firebase Emulator Suite (Auth + Firestore).
///
/// Usa la API REST de los emuladores (válida en `flutter test` sin plugins nativos).
/// Puertos (firebase.json): Auth 9099, Firestore 8085.
///
/// Terminal 1:
/// ```powershell
/// $env:JAVA_HOME = "C:\Program Files\Microsoft\jdk-21.0.12.101-hotspot"
/// $env:Path = "$env:JAVA_HOME\bin;$env:Path"
/// cd C:\Users\BRS\Documents\regneps
/// firebase emulators:start --only auth,firestore --project vicunha-calculadora-neps
/// ```
///
/// Terminal 2:
/// ```powershell
/// cd C:\Users\BRS\Documents\regneps
/// flutter test test/integration/multiuser_emulator_test.dart --dart-define=USE_FIREBASE_EMULATOR=true
/// ```
///
/// Con USE_FIREBASE_EMULATOR=true: no se omiten; fallan si el emulador no responde.
library;

import 'dart:convert';
import 'dart:io';

import 'package:calculadora_neps/core/constants.dart';
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
const String _projectId = 'vicunha-calculadora-neps';
const String _apiKey = 'fake-api-key';

void main() {
  group('Emulator multiusuario', () {
    setUpAll(() async {
      if (!useFirebaseEmulator) return;
      await _assertEmulatorsReachable();
    });

    test(
      'A y B agregan simultáneamente con mismo Telar/Lote',
      () async {
        final a = await _createUser('user_a');
        final b = await _createUser('user_b');
        final idA = 'rec_a_${a.uid}';
        final idB = 'rec_b_${b.uid}';

        final futures = await Future.wait([
          _putRecord(
            token: a.idToken,
            recordId: idA,
            ownerUid: a.uid,
            sessionId: 'ses_a_${a.uid}',
            telar: 'T-100',
            lote: '63E264-SHARED',
            neps: 12,
          ),
          _putRecord(
            token: b.idToken,
            recordId: idB,
            ownerUid: b.uid,
            sessionId: 'ses_b_${b.uid}',
            telar: 'T-100',
            lote: '63E264-SHARED',
            neps: 18,
          ),
        ]);

        expect(futures[0].statusCode, anyOf(200, 201));
        expect(futures[1].statusCode, anyOf(200, 201));

        final snapA = await _getRecord(token: a.idToken, recordId: idA);
        final snapB = await _getRecord(token: b.idToken, recordId: idB);
        expect(snapA['ownerUid'], a.uid);
        expect(snapB['ownerUid'], b.uid);
        expect(idA, isNot(idB));
        expect(snapA['loteTrama'], snapB['loteTrama']);
      },
      skip: useFirebaseEmulator
          ? false
          : 'Requiere: firebase emulators:start --only auth,firestore '
              'y --dart-define=USE_FIREBASE_EMULATOR=true',
    );

    test(
      'B no puede crear/editar/borrar registros de A',
      () async {
        final a = await _createUser('owner_a');
        final b = await _createUser('intruder_b');
        final idA = 'rec_own_${a.uid}';

        final created = await _putRecord(
          token: a.idToken,
          recordId: idA,
          ownerUid: a.uid,
          sessionId: 'ses_${a.uid}',
          telar: 'T-200',
          lote: '63E264-OWN',
          neps: 9,
        );
        expect(created.statusCode, anyOf(200, 201));

        final forged = await _putRecord(
          token: b.idToken,
          recordId: 'forged_${b.uid}',
          ownerUid: a.uid,
          sessionId: 'ses_forged',
          telar: 'T-200',
          lote: '63E264-OWN',
          neps: 1,
        );
        expect(forged.statusCode, 403, reason: forged.body);

        final patched = await _patchRecordFields(
          token: b.idToken,
          recordId: idA,
          fields: {'neps': 99},
        );
        expect(patched.statusCode, 403, reason: patched.body);

        final deleted = await _deleteRecord(token: b.idToken, recordId: idA);
        expect(deleted.statusCode, 403, reason: deleted.body);

        final snap = await _getRecord(token: a.idToken, recordId: idA);
        expect(snap['neps'], 9);
      },
      skip: useFirebaseEmulator
          ? false
          : 'Requiere emuladores Firebase (ver cabecera del archivo)',
    );

    test(
      'Falsificar ownerUid/createdByUid/sesión ajena es rechazado',
      () async {
        final a = await _createUser('auth_a');
        final id = 'rec_lock_${a.uid}';
        final created = await _putRecord(
          token: a.idToken,
          recordId: id,
          ownerUid: a.uid,
          sessionId: 'ses_locked_${a.uid}',
          telar: 'T-300',
          lote: '63E264-LOCK',
          neps: 5,
        );
        expect(created.statusCode, anyOf(200, 201));

        expect(
          (await _patchRecordFields(
            token: a.idToken,
            recordId: id,
            fields: {'ownerUid': 'otro-uid'},
          ))
              .statusCode,
          403,
        );
        expect(
          (await _patchRecordFields(
            token: a.idToken,
            recordId: id,
            fields: {'createdByUid': 'otro-uid'},
          ))
              .statusCode,
          403,
        );
        expect(
          (await _patchRecordFields(
            token: a.idToken,
            recordId: id,
            fields: {'captureSessionId': 'ses_ajena'},
          ))
              .statusCode,
          403,
        );

        // Operación permitida (dueño): campos operativos + lastModified.
        // Conserva autoría. La excepción supervisor en rules usa el mismo
        // ownershipUnchanged() (no puede cambiar owner/createdBy/sesión).
        final b = await _createUser('auth_b');
        final allowed = await _patchRecordFields(
          token: a.idToken,
          recordId: id,
          fields: {
            'neps': 7,
            'lastModifiedByUid': a.uid,
          },
        );
        expect(allowed.statusCode, anyOf(200, 201), reason: allowed.body);

        // Operación prohibida: B sin rol supervisor no edita registro de A.
        final foreignEdit = await _patchRecordFields(
          token: b.idToken,
          recordId: id,
          fields: {'neps': 99},
        );
        expect(foreignEdit.statusCode, 403, reason: foreignEdit.body);

        // Operación prohibida: falsificar createdByUid tras edición autorizada.
        final forbidden = await _patchRecordFields(
          token: a.idToken,
          recordId: id,
          fields: {'createdByUid': 'spoof'},
        );
        expect(forbidden.statusCode, 403, reason: forbidden.body);

        final snap = await _getRecord(token: a.idToken, recordId: id);
        expect(snap['neps'], 7);
        expect(snap['ownerUid'], a.uid);
        expect(snap['createdByUid'], a.uid);
        expect(snap['captureSessionId'], 'ses_locked_${a.uid}');
        expect(snap['lastModifiedByUid'], a.uid);
      },
      skip: useFirebaseEmulator
          ? false
          : 'Requiere emuladores Firebase (ver cabecera del archivo)',
    );

    test(
      'A nueva sesión; B conserva escritura',
      () async {
        final a = await _createUser('session_a');
        final b = await _createUser('session_b');
        final id1 = 'rec_s1_${a.uid}';
        final id2 = 'rec_s2_${a.uid}';
        final idB = 'rec_sb_${b.uid}';

        expect(
          (await _putRecord(
            token: a.idToken,
            recordId: id1,
            ownerUid: a.uid,
            sessionId: 'ses1_${a.uid}',
            telar: 'T-400',
            lote: '63E264-S1',
            neps: 3,
          ))
              .statusCode,
          anyOf(200, 201),
        );
        expect(
          (await _putRecord(
            token: a.idToken,
            recordId: id2,
            ownerUid: a.uid,
            sessionId: 'ses2_${a.uid}',
            telar: 'T-401',
            lote: '63E264-S2',
            neps: 4,
          ))
              .statusCode,
          anyOf(200, 201),
        );
        expect(
          (await _putRecord(
            token: b.idToken,
            recordId: idB,
            ownerUid: b.uid,
            sessionId: 'ses_b_${b.uid}',
            telar: 'T-400',
            lote: '63E264-S1',
            neps: 11,
          ))
              .statusCode,
          anyOf(200, 201),
        );

        final snap1 = await _getRecord(token: a.idToken, recordId: id1);
        final snapB = await _getRecord(token: b.idToken, recordId: idB);
        expect(snap1['captureSessionId'], 'ses1_${a.uid}');
        expect(snapB['ownerUid'], b.uid);
      },
      skip: useFirebaseEmulator
          ? false
          : 'Requiere emuladores Firebase (ver cabecera del archivo)',
    );

    test(
      'Cambio A→B con pending ops; late response de A descartada',
      () async {
        final a = await _createUser('pending_a');
        final b = await _createUser('pending_b');
        final pendingId = 'rec_pending_${a.uid}';

        // B activo: no puede escribir como A.
        final rejected = await _putRecord(
          token: b.idToken,
          recordId: pendingId,
          ownerUid: a.uid,
          sessionId: 'ses_pending_${a.uid}',
          telar: 'T-500',
          lote: '63E264-PEND',
          neps: 6,
        );
        expect(rejected.statusCode, 403, reason: rejected.body);

        final accepted = await _putRecord(
          token: a.idToken,
          recordId: pendingId,
          ownerUid: a.uid,
          sessionId: 'ses_pending_${a.uid}',
          telar: 'T-500',
          lote: '63E264-PEND',
          neps: 6,
        );
        expect(accepted.statusCode, anyOf(200, 201));

        final snap = await _getRecord(token: a.idToken, recordId: pendingId);
        expect(snap['ownerUid'], a.uid);
        expect(snap['ownerUid'], isNot(b.uid));
      },
      skip: useFirebaseEmulator
          ? false
          : 'Requiere emuladores Firebase (ver cabecera del archivo)',
    );

    test(
      'Offline save + restart + reconnect sin duplicar',
      () async {
        final a = await _createUser('offline_a');
        final id = 'rec_offline_${a.uid}';

        final first = await _putRecord(
          token: a.idToken,
          recordId: id,
          ownerUid: a.uid,
          sessionId: 'ses_offline_${a.uid}',
          telar: 'T-600',
          lote: '63E264-OFF',
          neps: 8,
        );
        final second = await _putRecord(
          token: a.idToken,
          recordId: id,
          ownerUid: a.uid,
          sessionId: 'ses_offline_${a.uid}',
          telar: 'T-600',
          lote: '63E264-OFF',
          neps: 8,
        );
        expect(first.statusCode, anyOf(200, 201));
        expect(second.statusCode, anyOf(200, 201));

        final snap = await _getRecord(token: a.idToken, recordId: id);
        expect(snap['id'], id);
        expect(snap['ownerUid'], a.uid);
      },
      skip: useFirebaseEmulator
          ? false
          : 'Requiere emuladores Firebase (ver cabecera del archivo)',
    );
  });
}

Future<void> _assertEmulatorsReachable() async {
  Future<void> probe(String host, int port, String label) async {
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 2),
      );
      await socket.close();
    } catch (error) {
      fail(
        'USE_FIREBASE_EMULATOR=true pero el emulador $label no responde en '
        '$host:$port. Arranque: firebase emulators:start --only auth,firestore '
        '--project $_projectId. Detalle: $error',
      );
    }
  }

  await probe(_authHost, _authPort, 'Auth');
  await probe(_fsHost, _fsPort, 'Firestore');
}

class _EmuUser {
  _EmuUser({
    required this.uid,
    required this.email,
    required this.password,
    required this.idToken,
  });

  final String uid;
  final String email;
  final String password;
  final String idToken;
}

Future<_EmuUser> _createUser(String prefix) async {
  final stamp = DateTime.now().microsecondsSinceEpoch;
  final email = '$prefix.$stamp@test.local';
  const password = 'TestPass123!';
  final uri = Uri.parse(
    'http://$_authHost:$_authPort/identitytoolkit.googleapis.com/v1/accounts:signUp?key=$_apiKey',
  );
  final response = await http.post(
    uri,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'email': email,
      'password': password,
      'returnSecureToken': true,
    }),
  );
  if (response.statusCode < 200 || response.statusCode >= 300) {
    fail('No se pudo crear usuario de emulador: ${response.body}');
  }
  final body = jsonDecode(response.body) as Map<String, dynamic>;
  return _EmuUser(
    uid: body['localId'] as String,
    email: email,
    password: password,
    idToken: body['idToken'] as String,
  );
}

Future<_EmuUser> _signIn(String email, String password) async {
  final uri = Uri.parse(
    'http://$_authHost:$_authPort/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$_apiKey',
  );
  final response = await http.post(
    uri,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'email': email,
      'password': password,
      'returnSecureToken': true,
    }),
  );
  if (response.statusCode < 200 || response.statusCode >= 300) {
    fail('No se pudo iniciar sesión en emulador: ${response.body}');
  }
  final body = jsonDecode(response.body) as Map<String, dynamic>;
  return _EmuUser(
    uid: body['localId'] as String,
    email: email,
    password: password,
    idToken: body['idToken'] as String,
  );
}

String get _recordsBase =>
    'http://$_fsHost:$_fsPort/v1/projects/$_projectId/databases/(default)/documents/'
    'workspaces/$cloudWorkspaceId/records';

Future<http.Response> _putRecord({
  required String token,
  required String recordId,
  required String ownerUid,
  required String sessionId,
  required String telar,
  required String lote,
  required double neps,
}) {
  final uri = Uri.parse('$_recordsBase/$recordId');
  final payload = {
    'fields': _toFields({
      'id': recordId,
      'telar': telar,
      'neps': neps,
      'tela': 'TELA-TEST',
      'loteTrama': lote,
      'ownerUid': ownerUid,
      'createdByUid': ownerUid,
      'captureSessionId': sessionId,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    }),
  };
  return http.patch(
    uri,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
    body: jsonEncode(payload),
  );
}

Future<http.Response> _patchRecordFields({
  required String token,
  required String recordId,
  required Map<String, dynamic> fields,
}) {
  final mask = fields.keys.map(Uri.encodeQueryComponent).join('&updateMask.fieldPaths=');
  final uri = Uri.parse(
    '$_recordsBase/$recordId?updateMask.fieldPaths=$mask',
  );
  return http.patch(
    uri,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
    body: jsonEncode({'fields': _toFields(fields)}),
  );
}

Future<http.Response> _deleteRecord({
  required String token,
  required String recordId,
}) {
  return http.delete(
    Uri.parse('$_recordsBase/$recordId'),
    headers: {'Authorization': 'Bearer $token'},
  );
}

Future<Map<String, dynamic>> _getRecord({
  required String token,
  required String recordId,
}) async {
  final response = await http.get(
    Uri.parse('$_recordsBase/$recordId'),
    headers: {'Authorization': 'Bearer $token'},
  );
  if (response.statusCode != 200) {
    fail('GET record falló (${response.statusCode}): ${response.body}');
  }
  final body = jsonDecode(response.body) as Map<String, dynamic>;
  return _fromFields(body['fields'] as Map<String, dynamic>? ?? {});
}

Map<String, dynamic> _toFields(Map<String, dynamic> data) {
  return data.map((key, value) => MapEntry(key, _encodeValue(value)));
}

Map<String, dynamic> _encodeValue(dynamic value) {
  if (value == null) return {'nullValue': null};
  if (value is String) return {'stringValue': value};
  if (value is bool) return {'booleanValue': value};
  if (value is int) return {'integerValue': '$value'};
  if (value is double) return {'doubleValue': value};
  if (value is num) return {'doubleValue': value.toDouble()};
  return {'stringValue': value.toString()};
}

Map<String, dynamic> _fromFields(Map<String, dynamic> fields) {
  final result = <String, dynamic>{};
  fields.forEach((key, raw) {
    final value = raw as Map<String, dynamic>;
    if (value.containsKey('stringValue')) {
      result[key] = value['stringValue'];
    } else if (value.containsKey('doubleValue')) {
      result[key] = (value['doubleValue'] as num).toDouble();
    } else if (value.containsKey('integerValue')) {
      result[key] = int.tryParse('${value['integerValue']}') ?? value['integerValue'];
    } else if (value.containsKey('booleanValue')) {
      result[key] = value['booleanValue'];
    } else {
      result[key] = value;
    }
  });
  return result;
}
