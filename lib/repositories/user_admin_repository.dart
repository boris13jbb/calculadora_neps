import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../models/app_user.dart';
import '../models/app_user_role.dart';
import '../services/user_admin_service.dart';
import '../utils/firestore_json_helper.dart';
import '../utils/username_auth_helper.dart';

/// Repositorio de administración de usuarios.
///
/// La creación usa una cola en Firestore (como un repositorio local fiable):
/// el cliente escribe la solicitud y una Cloud Function crea el usuario en Auth.
class UserAdminRepository {
  UserAdminRepository._({UserAdminService? service})
      : _service = service ?? UserAdminService();

  static final UserAdminRepository instance = UserAdminRepository._();

  static const _workspacePath = 'workspaces/vicunha';
  static const _requestsPath = '$_workspacePath/user_creation_requests';

  final UserAdminService _service;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  FirebaseAuth get _auth => FirebaseAuth.instanceFor(app: Firebase.app());

  Future<AppUser> createUser({
    required String username,
    required String password,
    String? displayName,
    required AppUserRole role,
    bool isActive = true,
  }) async {
    final normalizedUsername = UsernameAuthHelper.normalizeUsername(username);

    try {
      return await _createUserViaFirestoreQueue(
        username: normalizedUsername,
        password: password,
        displayName: displayName,
        role: role,
        isActive: isActive,
      );
    } catch (error) {
      debugPrint('Cola Firestore falló, probando callable: $error');
      return _service.createUser(
        username: normalizedUsername,
        password: password,
        displayName: displayName,
        role: role,
        isActive: isActive,
      );
    }
  }

  Future<AppUser> updateUser({
    required String uid,
    String? displayName,
    AppUserRole? role,
    bool? isActive,
  }) =>
      _service.updateUser(
        uid: uid,
        displayName: displayName,
        role: role,
        isActive: isActive,
      );

  Future<void> resetUserPassword({
    required String uid,
    required String newPassword,
  }) =>
      _service.resetUserPassword(uid: uid, newPassword: newPassword);

  Future<void> disableUser(String uid) => _service.disableUser(uid);

  Future<void> enableUser(String uid) => _service.enableUser(uid);

  Future<void> deleteUser(String uid) => _service.deleteUser(uid);

  Future<List<AppUser>> listUsers({
    String? search,
    String? roleFilter,
    bool? activeOnly,
    bool includeDeleted = false,
  }) =>
      _service.listUsers(
        search: search,
        roleFilter: roleFilter,
        activeOnly: activeOnly,
        includeDeleted: includeDeleted,
      );

  Future<AppUser> _createUserViaFirestoreQueue({
    required String username,
    required String password,
    String? displayName,
    required AppUserRole role,
    required bool isActive,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('Debe iniciar sesión nuevamente.');
    }

    await currentUser.getIdToken(true);

    final profileSnap =
        await _firestore.doc('$_workspacePath/users/${currentUser.uid}').get();
    final profile = profileSnap.data();
    final performerUsername = profile?['username'] as String? ??
        UsernameAuthHelper.normalizeUsername(
          profile?['displayName'] as String? ?? currentUser.uid,
        );

    final requestRef = await _firestore.collection(_requestsPath).add({
      'type': 'create',
      'status': 'pending',
      'username': username,
      'password': password,
      if (displayName != null && displayName.trim().isNotEmpty)
        'displayName': displayName.trim(),
      'role': role.code,
      'isActive': isActive,
      'requestedByUid': currentUser.uid,
      'requestedByUsername': performerUsername,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return _waitForCreationResult(requestRef);
  }

  Future<AppUser> _waitForCreationResult(
    DocumentReference<Map<String, dynamic>> requestRef,
  ) async {
    final completer = Completer<AppUser>();
    late final StreamSubscription<DocumentSnapshot<Map<String, dynamic>>> sub;
    Timer? timeout;

    sub = requestRef.snapshots().listen(
      (snap) {
        final data = snap.data();
        if (data == null) return;

        final status = data['status'] as String?;
        if (status == 'completed') {
          final userRaw = data['user'];
          if (userRaw is Map) {
            completer.complete(
              AppUser.fromJson(
                FirestoreJsonHelper.normalizeMap(
                  Map<String, dynamic>.from(userRaw),
                ),
              ),
            );
          } else {
            completer.completeError(
              Exception('Respuesta incompleta al crear el usuario.'),
            );
          }
          return;
        }

        if (status == 'failed') {
          completer.completeError(
            Exception(
              data['errorMessage']?.toString() ??
                  'No se pudo crear el usuario.',
            ),
          );
        }
      },
      onError: completer.completeError,
    );

    timeout = Timer(const Duration(seconds: 90), () {
      if (!completer.isCompleted) {
        completer.completeError(
          Exception(
            'Tiempo de espera agotado. Verifique la lista de usuarios.',
          ),
        );
      }
    });

    try {
      return await completer.future;
    } finally {
      await sub.cancel();
      timeout.cancel();
    }
  }
}
