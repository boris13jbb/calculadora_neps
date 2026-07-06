import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../core/errors/app_exception.dart';
import '../models/app_user.dart';
import '../models/app_user_role.dart';
import '../services/user_admin_service.dart';
import '../utils/firestore_json_helper.dart';
import '../utils/username_auth_helper.dart';

/// Repositorio de administración de usuarios.
///
/// Todas las mutaciones usan una cola en Firestore (como un repositorio local
/// fiable): el cliente escribe la solicitud y una Cloud Function la procesa en
/// segundo plano. Así se evita el fallo `Failed to fetch` / CORS de llamar a
/// `cloudfunctions.net` desde el navegador. Si la cola no está disponible
/// (trigger sin desplegar, timeout, error de red), se hace fallback al callable
/// directo, que sigue funcionando en Android/iOS.
class UserAdminRepository {
  UserAdminRepository._({UserAdminService? service})
      : _service = service ?? UserAdminService();

  static final UserAdminRepository instance = UserAdminRepository._();

  static const _workspacePath = 'workspaces/vicunha';
  static const _creationRequestsPath = '$_workspacePath/user_creation_requests';
  static const _creationSecretsPath = '$_workspacePath/user_creation_secrets';
  static const _adminRequestsPath = '$_workspacePath/user_admin_requests';
  static const _adminSecretsPath = '$_workspacePath/user_admin_secrets';

  static const _requestTimeout = Duration(seconds: 90);

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
    } on UserAdminException {
      rethrow;
    } catch (error) {
      debugPrint('Cola creación falló, probando callable: $error');
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
  }) async {
    try {
      final data = await _enqueueAdminRequest(
        {
          'type': 'update',
          'uid': uid,
          if (displayName != null) 'displayName': displayName.trim(),
          if (role != null) 'role': role.code,
          if (isActive != null) 'isActive': isActive,
        },
        failureFallbackMessage: 'No se pudo actualizar el usuario.',
      );
      return _userFromResult(
        data,
        incompleteMessage: 'Respuesta incompleta al actualizar el usuario.',
      );
    } on UserAdminException {
      rethrow;
    } catch (error) {
      debugPrint('Cola update falló, probando callable: $error');
      return _service.updateUser(
        uid: uid,
        displayName: displayName,
        role: role,
        isActive: isActive,
      );
    }
  }

  Future<void> resetUserPassword({
    required String uid,
    required String newPassword,
  }) async {
    try {
      await _resetPasswordViaFirestoreQueue(
        uid: uid,
        newPassword: newPassword,
      );
    } on UserAdminException {
      rethrow;
    } catch (error) {
      debugPrint('Cola resetPassword falló, probando callable: $error');
      await _service.resetUserPassword(uid: uid, newPassword: newPassword);
    }
  }

  Future<void> _resetPasswordViaFirestoreQueue({
    required String uid,
    required String newPassword,
  }) async {
    final requestRef = await _writeRequest(
      _adminRequestsPath,
      {
        'type': 'resetPassword',
        'uid': uid,
      },
    );

    await _firestore.doc('$_adminSecretsPath/${requestRef.id}').set({
      'newPassword': newPassword,
      'requestedByUid': _auth.currentUser!.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _awaitRequestCompletion(
      requestRef,
      failureFallbackMessage: 'No se pudo restablecer la contraseña.',
    );
  }

  Future<void> disableUser(String uid) => _setUserActive(uid, false);

  Future<void> enableUser(String uid) => _setUserActive(uid, true);

  Future<void> _setUserActive(String uid, bool enable) async {
    final type = enable ? 'enable' : 'disable';
    try {
      await _enqueueAdminRequest(
        {'type': type, 'uid': uid},
        failureFallbackMessage: enable
            ? 'No se pudo activar el usuario.'
            : 'No se pudo desactivar el usuario.',
      );
    } on UserAdminException {
      rethrow;
    } catch (error) {
      debugPrint('Cola $type falló, probando callable: $error');
      if (enable) {
        await _service.enableUser(uid);
      } else {
        await _service.disableUser(uid);
      }
    }
  }

  Future<void> deleteUser(String uid) async {
    try {
      await _enqueueAdminRequest(
        {'type': 'delete', 'uid': uid},
        failureFallbackMessage: 'No se pudo eliminar el usuario.',
      );
    } on UserAdminException {
      rethrow;
    } catch (error) {
      debugPrint('Cola delete falló, probando callable: $error');
      await _service.deleteUser(uid);
    }
  }

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
    final requestRef = await _writeRequest(
      _creationRequestsPath,
      {
        'type': 'create',
        'username': username,
        if (displayName != null && displayName.trim().isNotEmpty)
          'displayName': displayName.trim(),
        'role': role.code,
        'isActive': isActive,
      },
    );

    await _firestore.doc('$_creationSecretsPath/${requestRef.id}').set({
      'password': password,
      'requestedByUid': _auth.currentUser!.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final data = await _awaitRequestCompletion(
      requestRef,
      failureFallbackMessage: 'No se pudo crear el usuario.',
    );
    return _userFromResult(
      data,
      incompleteMessage: 'Respuesta incompleta al crear el usuario.',
    );
  }

  /// Escribe una solicitud de administración genérica y espera su resultado.
  Future<Map<String, dynamic>> _enqueueAdminRequest(
    Map<String, dynamic> payload, {
    required String failureFallbackMessage,
  }) async {
    final requestRef = await _writeRequest(_adminRequestsPath, payload);
    return _awaitRequestCompletion(
      requestRef,
      failureFallbackMessage: failureFallbackMessage,
    );
  }

  /// Crea el documento de solicitud con los metadatos del solicitante.
  Future<DocumentReference<Map<String, dynamic>>> _writeRequest(
    String collectionPath,
    Map<String, dynamic> payload,
  ) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('Debe iniciar sesión nuevamente.');
    }

    await currentUser.getIdToken(true);
    final performerUsername = await _resolvePerformerUsername(currentUser);

    return _firestore.collection(collectionPath).add({
      ...payload,
      'status': 'pending',
      'requestedByUid': currentUser.uid,
      'requestedByUsername': performerUsername,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> _resolvePerformerUsername(User currentUser) async {
    final profileSnap =
        await _firestore.doc('$_workspacePath/users/${currentUser.uid}').get();
    final profile = profileSnap.data();
    return profile?['username'] as String? ??
        UsernameAuthHelper.normalizeUsername(
          profile?['displayName'] as String? ?? currentUser.uid,
        );
  }

  /// Escucha el documento de solicitud hasta que el trigger lo complete.
  ///
  /// Devuelve los datos finales en `completed`, lanza [UserAdminException]
  /// en `failed` (error de negocio definitivo) y una excepción genérica ante
  /// timeout o error de stream (recuperable vía fallback al callable).
  Future<Map<String, dynamic>> _awaitRequestCompletion(
    DocumentReference<Map<String, dynamic>> requestRef, {
    required String failureFallbackMessage,
  }) async {
    final completer = Completer<Map<String, dynamic>>();
    late final StreamSubscription<DocumentSnapshot<Map<String, dynamic>>> sub;
    Timer? timeout;

    sub = requestRef.snapshots().listen(
      (snap) {
        final data = snap.data();
        if (data == null) return;

        final status = data['status'] as String?;
        if (status == 'completed') {
          if (!completer.isCompleted) completer.complete(data);
        } else if (status == 'failed') {
          if (!completer.isCompleted) {
            completer.completeError(
              UserAdminException(
                data['errorMessage']?.toString() ?? failureFallbackMessage,
              ),
            );
          }
        }
      },
      onError: (Object error) {
        if (!completer.isCompleted) completer.completeError(error);
      },
    );

    timeout = Timer(_requestTimeout, () {
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

  AppUser _userFromResult(
    Map<String, dynamic> data, {
    required String incompleteMessage,
  }) {
    final userRaw = data['user'];
    if (userRaw is Map) {
      return AppUser.fromJson(
        FirestoreJsonHelper.normalizeMap(
          Map<String, dynamic>.from(userRaw),
        ),
      );
    }
    throw Exception(incompleteMessage);
  }
}
