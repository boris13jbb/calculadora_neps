/// Integración delete-wins contra Auth + Firestore Emulator (API REST).
///
/// Valida el contrato que [CloudSyncService.deleteRecord]/[CloudSyncService.upsertRecord]
/// aplica en Firestore (mirrors + tombstone + anti-resurrección). El plugin nativo
/// de Firebase no inicializa en `flutter test` (VM); este archivo usa el mismo
/// mecanismo REST que [multiuser_emulator_test.dart].
///
/// Terminal 1:
/// ```powershell
/// firebase emulators:start --only auth,firestore --project vicunha-calculadora-neps
/// ```
///
/// Terminal 2:
/// ```powershell
/// flutter test test/integration/tombstone_delete_wins_emulator_test.dart --dart-define=USE_FIREBASE_EMULATOR=true
/// ```
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
  group('Emulator tombstone delete-wins (contrato CloudSyncService)', () {
    setUpAll(() async {
      if (!useFirebaseEmulator) return;
      await _assertEmulatorsReachable();
    });

    test(
      'delete atómico + tombstone rechaza recreate; upsert C OK',
      () async {
        final admin = await _createUser('tomb_admin');
        await _setCustomClaims(admin.uid, {
          'role': 'admin',
          'isSuperAdmin': true,
        });
        // Token fresco con claims.
        final session = await _signIn(admin.email, admin.password);
        await _seedAdminRole(session.idToken);

        final stamp = DateTime.now().microsecondsSinceEpoch;
        final idB = 'rec_b_$stamp';
        final idC = 'rec_c_$stamp';

        // A/B: crear B en ambos mirrors (como upsertRecord).
        final createdWs = await _putDoc(
          token: session.idToken,
          path: 'workspaces/$cloudWorkspaceId/records/$idB',
          data: _recordPayload(
            id: idB,
            ownerUid: session.uid,
            sessionId: 'ses_b_$stamp',
            telar: 'T-B',
            neps: 11,
          ),
        );
        final createdUser = await _putDoc(
          token: session.idToken,
          path:
              'workspaces/$cloudWorkspaceId/users/${session.uid}/records/$idB',
          data: _recordPayload(
            id: idB,
            ownerUid: session.uid,
            sessionId: 'ses_b_$stamp',
            telar: 'T-B',
            neps: 11,
          ),
        );
        expect(createdWs.statusCode, anyOf(200, 201));
        expect(createdUser.statusCode, anyOf(200, 201));
        expect(
          (await _getDoc(
            token: session.idToken,
            path: 'workspaces/$cloudWorkspaceId/records/$idB',
          ))
              .statusCode,
          200,
        );
        expect(
          (await _getDoc(
            token: session.idToken,
            path:
                'workspaces/$cloudWorkspaceId/users/${session.uid}/records/$idB',
          ))
              .statusCode,
          200,
        );

        // C/D: deleteRecord atómico (workspace + user + tombstone).
        final deleted = await _commitDeleteWithTombstone(
          token: session.idToken,
          recordId: idB,
          ownerUid: session.uid,
          deletedByUid: session.uid,
        );
        expect(deleted.statusCode, anyOf(200, 201));

        expect(
          (await _getDoc(
            token: session.idToken,
            path: 'workspaces/$cloudWorkspaceId/records/$idB',
          ))
              .statusCode,
          404,
        );
        expect(
          (await _getDoc(
            token: session.idToken,
            path:
                'workspaces/$cloudWorkspaceId/users/${session.uid}/records/$idB',
          ))
              .statusCode,
          404,
        );
        final tomb = await _getDoc(
          token: session.idToken,
          path: 'workspaces/$cloudWorkspaceId/record_tombstones/$idB',
        );
        expect(tomb.statusCode, 200);
        final tombFields = _fieldsOf(tomb);
        expect(tombFields['recordId'], idB);
        expect(tombFields['ownerUid'], session.uid);
        expect(tombFields['deletedByUid'], session.uid);

        // E/F: recreate = upsert stale → DENY (equivalente RecordTombstonedException).
        final reviveWs = await _putDoc(
          token: session.idToken,
          path: 'workspaces/$cloudWorkspaceId/records/$idB',
          data: _recordPayload(
            id: idB,
            ownerUid: session.uid,
            sessionId: 'ses_b_$stamp',
            telar: 'T-B',
            neps: 11,
          ),
        );
        final reviveUser = await _putDoc(
          token: session.idToken,
          path:
              'workspaces/$cloudWorkspaceId/users/${session.uid}/records/$idB',
          data: _recordPayload(
            id: idB,
            ownerUid: session.uid,
            sessionId: 'ses_b_$stamp',
            telar: 'T-B',
            neps: 11,
          ),
        );
        expect(reviveWs.statusCode, anyOf(403, 400));
        expect(reviveUser.statusCode, anyOf(403, 400));
        expect(
          (await _getDoc(
            token: session.idToken,
            path: 'workspaces/$cloudWorkspaceId/records/$idB',
          ))
              .statusCode,
          404,
        );
        expect(
          (await _getDoc(
            token: session.idToken,
            path:
                'workspaces/$cloudWorkspaceId/users/${session.uid}/records/$idB',
          ))
              .statusCode,
          404,
        );

        // G: upsert C sin tombstone → ambos mirrors OK.
        final createCWs = await _putDoc(
          token: session.idToken,
          path: 'workspaces/$cloudWorkspaceId/records/$idC',
          data: _recordPayload(
            id: idC,
            ownerUid: session.uid,
            sessionId: 'ses_c_$stamp',
            telar: 'T-C',
            neps: 22,
          ),
        );
        final createCUser = await _putDoc(
          token: session.idToken,
          path:
              'workspaces/$cloudWorkspaceId/users/${session.uid}/records/$idC',
          data: _recordPayload(
            id: idC,
            ownerUid: session.uid,
            sessionId: 'ses_c_$stamp',
            telar: 'T-C',
            neps: 22,
          ),
        );
        expect(createCWs.statusCode, anyOf(200, 201));
        expect(createCUser.statusCode, anyOf(200, 201));
        expect(
          (await _getDoc(
            token: session.idToken,
            path: 'workspaces/$cloudWorkspaceId/records/$idC',
          ))
              .statusCode,
          200,
        );
        expect(
          (await _getDoc(
            token: session.idToken,
            path:
                'workspaces/$cloudWorkspaceId/users/${session.uid}/records/$idC',
          ))
              .statusCode,
          200,
        );
      },
      skip: useFirebaseEmulator
          ? false
          : 'Requiere: firebase emulators:start --only auth,firestore '
              'y --dart-define=USE_FIREBASE_EMULATOR=true',
    );
  });
}

Future<void> _assertEmulatorsReachable() async {
  Future<void> ping(String label, Uri uri) async {
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 2));
      if (response.statusCode >= 500) {
        fail('Emulador $label respondió ${response.statusCode}');
      }
    } on SocketException catch (error) {
      fail(
        'USE_FIREBASE_EMULATOR=true pero el emulador $label no responde en '
        '${uri.host}:${uri.port} ($error)',
      );
    }
  }

  await ping('Auth', Uri.parse('http://$_authHost:$_authPort/'));
  await ping('Firestore', Uri.parse('http://$_fsHost:$_fsPort/'));
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
    fail('signUp falló: ${response.body}');
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
    fail('signIn falló: ${response.body}');
  }
  final body = jsonDecode(response.body) as Map<String, dynamic>;
  return _EmuUser(
    uid: body['localId'] as String,
    email: email,
    password: password,
    idToken: body['idToken'] as String,
  );
}

/// Claims vía Admin API del Auth Emulator (Bearer owner = privilegio admin local).
Future<void> _setCustomClaims(String uid, Map<String, dynamic> claims) async {
  final uri = Uri.parse(
    'http://$_authHost:$_authPort/identitytoolkit.googleapis.com/v1/'
    'projects/$_projectId/accounts:update?key=$_apiKey',
  );
  final response = await http.post(
    uri,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer owner',
    },
    body: jsonEncode({
      'localId': uid,
      'customAttributes': jsonEncode(claims),
    }),
  );
  if (response.statusCode < 200 || response.statusCode >= 300) {
    fail('claims falló: ${response.body}');
  }
}

Future<void> _seedAdminRole(String token) async {
  final response = await _putDoc(
    token: token,
    path: 'workspaces/$cloudWorkspaceId/roles/admin',
    data: {
      'code': 'admin',
      'name': 'admin',
      'permissions': [
        'viewRecords',
        'viewWorkspaceRecords',
        'editRecords',
        'deleteRecords',
        'captureRecords',
        'manageSettings',
      ],
      'isActive': true,
      'isSystem': true,
      'isAssignable': true,
      'sortOrder': 10,
    },
  );
  expect(response.statusCode, anyOf(200, 201));
}

String get _docsBase =>
    'http://$_fsHost:$_fsPort/v1/projects/$_projectId/databases/(default)/documents';

Map<String, dynamic> _recordPayload({
  required String id,
  required String ownerUid,
  required String sessionId,
  required String telar,
  required double neps,
}) {
  return {
    'id': id,
    'telar': telar,
    'neps': neps,
    'tela': 'TELA-TEST',
    'loteTrama': '63E264-TEST',
    'ownerUid': ownerUid,
    'createdByUid': ownerUid,
    'captureSessionId': sessionId,
    'createdAt': DateTime.now().toUtc().toIso8601String(),
  };
}

Map<String, dynamic> _toFields(Map<String, dynamic> data) {
  final fields = <String, dynamic>{};
  for (final entry in data.entries) {
    final value = entry.value;
    if (value is String) {
      fields[entry.key] = {'stringValue': value};
    } else if (value is int) {
      fields[entry.key] = {'integerValue': '$value'};
    } else if (value is double) {
      fields[entry.key] = {'doubleValue': value};
    } else if (value is bool) {
      fields[entry.key] = {'booleanValue': value};
    } else if (value is List) {
      fields[entry.key] = {
        'arrayValue': {
          'values':
              value.map((item) => {'stringValue': item.toString()}).toList(),
        },
      };
    }
  }
  return fields;
}

Map<String, dynamic> _fieldsOf(http.Response response) {
  final body = jsonDecode(response.body) as Map<String, dynamic>;
  final fields = body['fields'] as Map<String, dynamic>? ?? {};
  final out = <String, dynamic>{};
  for (final entry in fields.entries) {
    final map = entry.value as Map<String, dynamic>;
    out[entry.key] = map['stringValue'] ??
        map['integerValue'] ??
        map['doubleValue'] ??
        map['booleanValue'];
  }
  return out;
}

Future<http.Response> _putDoc({
  required String token,
  required String path,
  required Map<String, dynamic> data,
}) {
  final uri = Uri.parse('$_docsBase/$path');
  return http.patch(
    uri,
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({'fields': _toFields(data)}),
  );
}

Future<http.Response> _getDoc({
  required String token,
  required String path,
}) {
  final uri = Uri.parse('$_docsBase/$path');
  return http.get(
    uri,
    headers: {'Authorization': 'Bearer $token'},
  );
}

/// Réplica del batch de [CloudSyncService.deleteRecord]: 2 deletes + tombstone.
Future<http.Response> _commitDeleteWithTombstone({
  required String token,
  required String recordId,
  required String ownerUid,
  required String deletedByUid,
}) {
  final uri = Uri.parse(
    'http://$_fsHost:$_fsPort/v1/projects/$_projectId/databases/(default)/documents:commit',
  );
  final wsName =
      'projects/$_projectId/databases/(default)/documents/workspaces/$cloudWorkspaceId/records/$recordId';
  final userName =
      'projects/$_projectId/databases/(default)/documents/workspaces/$cloudWorkspaceId/users/$ownerUid/records/$recordId';
  final tombName =
      'projects/$_projectId/databases/(default)/documents/workspaces/$cloudWorkspaceId/record_tombstones/$recordId';

  return http.post(
    uri,
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'writes': [
        {'delete': wsName},
        {'delete': userName},
        {
          'update': {
            'name': tombName,
            'fields': _toFields({
              'recordId': recordId,
              'ownerUid': ownerUid,
              'deletedByUid': deletedByUid,
              'deletedAt': DateTime.now().toUtc().toIso8601String(),
            }),
          },
        },
      ],
    }),
  );
}
