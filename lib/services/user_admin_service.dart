import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;

import '../models/app_user.dart';
import '../models/app_user_role.dart';
import '../utils/callable_http_client.dart';
import '../utils/firestore_json_helper.dart';
import '../utils/username_auth_helper.dart';

class UserAdminService {
  UserAdminService({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _functionsOverride = functions,
        _firestoreOverride = firestore,
        _authOverride = auth;

  static const _functionsRegion = 'us-central1';

  final FirebaseFunctions? _functionsOverride;
  final FirebaseFirestore? _firestoreOverride;
  final FirebaseAuth? _authOverride;

  FirebaseFunctions get _functions =>
      _functionsOverride ??
      FirebaseFunctions.instanceFor(
        app: Firebase.app(),
        region: _functionsRegion,
      );

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  Future<AppUser> createUser({
    required String username,
    required String password,
    String? displayName,
    required AppUserRole role,
    bool isActive = true,
  }) async {
    final normalizedUsername = UsernameAuthHelper.normalizeUsername(username);
    final payload = {
      'username': normalizedUsername,
      'password': password,
      if (displayName != null && displayName.trim().isNotEmpty)
        'displayName': displayName.trim(),
      'role': role.code,
      'isActive': isActive,
    };

    try {
      final result = await _call('createAppUser', payload);
      return _userFromResult(result);
    } on FirebaseFunctionsException catch (error) {
      if (_isDuplicateUserError(error)) {
        throw FirebaseFunctionsException(
          code: error.code,
          message: _friendlyErrorMessage(error),
          details: error.details,
        );
      }
      if (!_isRecoverableCallError(error)) {
        throw FirebaseFunctionsException(
          code: error.code,
          message: _friendlyErrorMessage(error),
          details: error.details,
        );
      }
      return _confirmUserExists(
        normalizedUsername,
        originalError: error,
      );
    } catch (error) {
      if (!_isRecoverableCallError(error)) {
        throw Exception(_friendlyErrorMessage(error));
      }
      return _confirmUserExists(
        normalizedUsername,
        originalError: error,
      );
    }
  }

  Future<AppUser> updateUser({
    required String uid,
    String? displayName,
    AppUserRole? role,
    bool? isActive,
  }) async {
    final payload = <String, dynamic>{'uid': uid};
    if (displayName != null) payload['displayName'] = displayName.trim();
    if (role != null) payload['role'] = role.code;
    if (isActive != null) payload['isActive'] = isActive;

    try {
      final result = await _call('updateAppUser', payload);
      return _userFromResult(result);
    } catch (error) {
      if (!_isRecoverableCallError(error)) rethrow;
      return _findUserByUid(uid);
    }
  }

  Future<AppUser> updateUserRole({
    required String uid,
    required AppUserRole role,
  }) async {
    try {
      final result = await _call('changeUserRole', {
        'uid': uid,
        'role': role.code,
      });
      return _userFromResult(result);
    } catch (error) {
      if (!_isRecoverableCallError(error)) rethrow;
      return _findUserByUid(uid);
    }
  }

  Future<void> resetUserPassword({
    required String uid,
    required String newPassword,
  }) async {
    await _callVoid('resetAppUserPassword', {
      'uid': uid,
      'newPassword': newPassword,
    });
  }

  Future<void> disableUser(String uid) async {
    await _callVoid('disableAppUser', {'uid': uid});
  }

  Future<void> enableUser(String uid) async {
    await _callVoid('enableAppUser', {'uid': uid});
  }

  Future<void> deleteUser(String uid) async {
    await _callVoid('deleteAppUser', {'uid': uid});
  }

  Future<List<AppUser>> listUsers({
    String? search,
    String? roleFilter,
    bool? activeOnly,
    bool includeDeleted = false,
  }) async {
    try {
      final result = await _call('listAppUsers', {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (roleFilter != null && roleFilter.isNotEmpty) 'role': roleFilter,
        if (activeOnly != null) 'activeOnly': activeOnly,
        if (includeDeleted) 'includeDeleted': true,
      });

      return _usersFromResult(result);
    } catch (error) {
      if (!_canFallbackToFirestoreRead(error)) rethrow;
      return _listUsersFromFirestore(
        search: search,
        roleFilter: roleFilter,
        activeOnly: activeOnly,
        includeDeleted: includeDeleted,
      );
    }
  }

  Future<List<AppUser>> _listUsersFromFirestore({
    String? search,
    String? roleFilter,
    bool? activeOnly,
    bool includeDeleted = false,
  }) async {
    final snap = await _firestore.collection('workspaces/vicunha/users').get();
    final normalizedSearch = search?.trim().toLowerCase() ?? '';
    final normalizedRole = roleFilter?.trim();
    var users = snap.docs.map(_userFromDoc).toList();

    if (!includeDeleted) {
      users = users.where((user) => user.deletedAt == null).toList();
    }
    if (normalizedRole != null && normalizedRole.isNotEmpty) {
      users = users.where((user) => user.role.code == normalizedRole).toList();
    }
    if (activeOnly == true) {
      users = users.where((user) => user.isActive).toList();
    } else if (activeOnly == false) {
      users = users.where((user) => !user.isActive).toList();
    }
    if (normalizedSearch.isNotEmpty) {
      users = users.where((user) {
        final username = user.username.toLowerCase();
        final name = user.displayName.toLowerCase();
        final role = user.role.code.toLowerCase();
        return username.contains(normalizedSearch) ||
            name.contains(normalizedSearch) ||
            role.contains(normalizedSearch);
      }).toList();
    }

    users.sort(
      (a, b) => a.effectiveDisplayName.compareTo(b.effectiveDisplayName),
    );
    return users;
  }

  Future<AppUser> _confirmUserExists(
    String username, {
    Object? originalError,
  }) async {
    try {
      return await _findUserByUsername(username);
    } catch (error) {
      final detail = originalError ?? error;
      throw Exception(
        _friendlyErrorMessage(detail),
      );
    }
  }

  Future<AppUser> _findUserByUsername(String username) async {
    final normalizedUsername = UsernameAuthHelper.normalizeUsername(username);
    Object? lastError;

    for (var attempt = 0; attempt < 6; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(Duration(milliseconds: 300 * attempt));
      }

      try {
        final snap = await _firestore
            .collection('workspaces/vicunha/users')
            .where('username', isEqualTo: normalizedUsername)
            .limit(1)
            .get(const GetOptions(source: Source.server));
        if (snap.docs.isNotEmpty) {
          return _userFromDoc(snap.docs.first);
        }
      } catch (error) {
        lastError = error;
      }

      try {
        final users = await _listUsersFromFirestore();
        for (final user in users) {
          if (user.username == normalizedUsername) return user;
        }
      } catch (error) {
        lastError = error;
      }
    }

    throw Exception(
      'No se pudo confirmar la creación del usuario. '
      'Actualice la lista antes de intentarlo de nuevo.'
      '${lastError == null ? '' : ' Detalle: $lastError'}',
    );
  }

  Future<AppUser> _findUserByUid(String uid) async {
    final doc = await _firestore.doc('workspaces/vicunha/users/$uid').get();
    final data = doc.data();
    if (data == null) {
      throw Exception('No se pudo confirmar la actualización del usuario.');
    }
    return _userFromMap({'uid': doc.id, ...data});
  }

  List<AppUser> _usersFromResult(Map<String, dynamic> result) {
    final users = result['users'] as List<dynamic>? ?? [];
    return users
        .map((item) => _userFromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  AppUser _userFromResult(Map<String, dynamic> result) {
    return _userFromMap(Map<String, dynamic>.from(result['user'] as Map));
  }

  AppUser _userFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return _userFromMap({'uid': doc.id, ...doc.data()});
  }

  AppUser _userFromMap(Map<String, dynamic> data) {
    return AppUser.fromJson(FirestoreJsonHelper.normalizeMap(data));
  }

  Future<AppUser> getCurrentUserProfile() async {
    try {
      final result = await _call('getCurrentUserProfile', {});
      return _userFromResult(result);
    } catch (error) {
      if (!_canFallbackToFirestoreRead(error)) rethrow;
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        throw Exception('No hay una sesión activa.');
      }
      return _findUserByUid(uid);
    }
  }

  Future<void> _refreshAuthToken() async {
    var user = _auth.currentUser;
    user ??= await _auth
        .authStateChanges()
        .where((candidate) => candidate != null)
        .cast<User>()
        .first
        .timeout(
          const Duration(seconds: 3),
          onTimeout: () => throw FirebaseFunctionsException(
            code: 'unauthenticated',
            message: 'Debe iniciar sesión nuevamente.',
          ),
        );
    await user.getIdToken(true);
    await user.getIdTokenResult(true);
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data,
  ) async {
    await _refreshAuthToken();

    // Web: solo SDK (el fetch HTTP directo a cloudfunctions.net falla por CORS).
    if (kIsWeb) {
      return _callWithSdk(name, data, retryAfterUnauthenticated: true);
    }

    // Android/iOS: HTTP con Bearer explícito; fallback al SDK si falla.
    try {
      final httpResult = await postCallableFunction(name, data);
      if (httpResult != null) {
        return _normalizeCallableResponse(httpResult);
      }
    } on FirebaseFunctionsException catch (error) {
      debugPrint('Callable HTTP $name falló (${error.code}); probando SDK.');
    } catch (error) {
      debugPrint('Callable HTTP $name fallback al SDK: $error');
    }

    return _callWithSdk(name, data, retryAfterUnauthenticated: true);
  }

  Future<Map<String, dynamic>> _callWithSdk(
    String name,
    Map<String, dynamic> data, {
    required bool retryAfterUnauthenticated,
  }) async {
    try {
      final callable = _functions.httpsCallable(name);
      final response = await callable.call(data);
      return _normalizeCallableResponse(response.data);
    } on FirebaseFunctionsException catch (error) {
      if (retryAfterUnauthenticated &&
          error.code == 'unauthenticated' &&
          _auth.currentUser != null) {
        debugPrint('Cloud Function $name sin auth; renovando token.');
        await Future<void>.delayed(const Duration(milliseconds: 400));
        await _refreshAuthToken();
        return _callWithSdk(name, data, retryAfterUnauthenticated: false);
      }

      debugPrint('Cloud Function $name error: ${error.code} ${error.message}');
      throw FirebaseFunctionsException(
        code: error.code,
        message: _friendlyErrorMessage(error),
        details: error.details,
      );
    } catch (error) {
      debugPrint('Cloud Function $name error: $error');
      rethrow;
    }
  }

  Future<void> _callVoid(
    String name,
    Map<String, dynamic> data,
  ) async {
    try {
      await _call(name, data);
    } catch (error) {
      if (!_isRecoverableCallError(error)) rethrow;
      debugPrint(
          'Cloud Function $name: respuesta no legible, operación asumida OK.');
    }
  }

  Map<String, dynamic> _normalizeCallableResponse(dynamic data) {
    if (data == null) return {};
    try {
      final decoded = jsonDecode(jsonEncode(data));
      return FirestoreJsonHelper.normalizeCallableRoot(decoded);
    } catch (_) {
      return FirestoreJsonHelper.normalizeCallableRoot(data);
    }
  }

  bool _isRecoverableCallError(Object error) {
    if (error is FirebaseFunctionsException) {
      if (_isDuplicateUserError(error)) return false;
      if (error.code == 'permission-denied' ||
          error.code == 'unauthenticated' ||
          error.code == 'invalid-argument' ||
          error.code == 'failed-precondition') {
        return false;
      }
      return error.code == 'internal' || error.code == 'unknown';
    }

    final message = error.toString().toLowerCase();
    return message.contains('int64') ||
        message.contains('dart2js') ||
        message.contains('unsupported operation');
  }

  bool _canFallbackToFirestoreRead(Object error) {
    if (_isRecoverableCallError(error)) return true;
    return error is FirebaseFunctionsException &&
        error.code == 'unauthenticated' &&
        _auth.currentUser != null;
  }

  bool _isDuplicateUserError(FirebaseFunctionsException error) {
    return error.code == 'already-exists';
  }

  String _friendlyErrorMessage(Object error) {
    if (error is FirebaseFunctionsException) {
      final message = error.message?.trim();
      if (message != null && message.isNotEmpty) return message;
      return switch (error.code) {
        'permission-denied' =>
          'No tiene permisos de super administrador. Cierre sesión y vuelva a entrar.',
        'unauthenticated' => 'Debe iniciar sesión nuevamente.',
        'invalid-argument' => 'Datos inválidos para crear el usuario.',
        'already-exists' => 'El usuario ya existe.',
        _ => 'Error en la operación (${error.code}).',
      };
    }

    final text = error.toString().toLowerCase();
    if (text.contains('failed to fetch') ||
        text.contains('clientexception') ||
        text.contains('network')) {
      return 'No se pudo conectar con el servidor. Verifique su conexión e intente de nuevo.';
    }
    return error.toString();
  }
}
