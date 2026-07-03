import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../core/permissions/permission.dart';
import '../models/app_user.dart';
import '../models/app_user_role.dart';
import '../services/auth_service.dart';
import '../services/user_admin_service.dart';

enum AuthStatus {
  unknown,
  unauthenticated,
  loadingProfile,
  authenticated,
  accessDenied,
  deactivated,
}

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    AuthService? authService,
    UserAdminService? userAdminService,
  })  : _authService = authService ?? AuthService(),
        _userAdminService = userAdminService ?? UserAdminService();

  final AuthService _authService;
  final UserAdminService _userAdminService;

  AuthStatus status = AuthStatus.unknown;
  AppUser? profile;
  String? errorMessage;
  StreamSubscription<User?>? _authSub;

  User? get firebaseUser => _authService.currentFirebaseUser;

  AppUserRole get role => profile?.role ?? AppUserRole.operario;

  bool get isAuthenticated =>
      status == AuthStatus.authenticated && profile != null && profile!.isActive;

  void initialize() {
    _authSub?.cancel();
    if (Firebase.apps.isEmpty) {
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    _authSub = _authService.authStateChanges().listen(_onAuthChanged);
  }

  Future<void> _onAuthChanged(User? user) async {
    if (user == null) {
      profile = null;
      status = AuthStatus.unauthenticated;
      errorMessage = null;
      notifyListeners();
      return;
    }

    await _loadProfile(user);
  }

  Future<void> _loadProfile(User user) async {
    status = AuthStatus.loadingProfile;
    errorMessage = null;
    notifyListeners();

    try {
      AppUser? loaded;
      try {
        loaded = await _userAdminService.getCurrentUserProfile();
      } catch (_) {
        loaded = await _authService.fetchUserProfile(user.uid);
      }

      if (loaded == null) {
        status = AuthStatus.accessDenied;
        errorMessage = 'No se encontró el perfil del usuario en el sistema.';
        await _authService.signOut();
        notifyListeners();
        return;
      }

      if (!loaded.isActive || loaded.deletedAt != null) {
        status = AuthStatus.deactivated;
        errorMessage =
            'Usuario desactivado. Contacte al super administrador.';
        profile = loaded;
        await _authService.signOut();
        notifyListeners();
        return;
      }

      final claims = await _authService.getIdTokenClaims();
      final claimRole = _authService.resolveRoleFromClaims(claims);
      if (claimRole != loaded.role) {
        loaded = loaded.copyWith(role: claimRole);
      }

      profile = loaded;
      status = AuthStatus.authenticated;
      unawaited(_authService.touchLastLogin(user.uid));
      notifyListeners();
    } catch (error) {
      status = AuthStatus.accessDenied;
      errorMessage = 'No se pudo cargar su perfil: $error';
      await _authService.signOut();
      notifyListeners();
    }
  }

  Future<void> signInWithUsernameOrEmail({
    required String usernameOrEmail,
    required String password,
  }) async {
    errorMessage = null;
    status = AuthStatus.loadingProfile;
    notifyListeners();

    try {
      await _authService.signInWithUsernameOrEmail(
        usernameOrEmail: usernameOrEmail,
        password: password,
      );
      await _authService.refreshIdToken();
    } on FirebaseAuthException catch (error) {
      status = AuthStatus.unauthenticated;
      errorMessage = _mapAuthError(error);
      notifyListeners();
      rethrow;
    } on FormatException catch (error) {
      status = AuthStatus.unauthenticated;
      errorMessage = error.message;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    profile = null;
    status = AuthStatus.unauthenticated;
    errorMessage = null;
    notifyListeners();
  }

  Future<void> sendPasswordReset(String email) {
    return _authService.sendPasswordResetEmail(email);
  }

  Future<void> refreshProfile() async {
    final user = firebaseUser;
    if (user == null) return;
    await _authService.refreshIdToken();
    await _loadProfile(user);
  }

  bool hasPermission(Permission permission) {
    return profile?.hasPermission(permission) ?? false;
  }

  String _mapAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'El usuario o correo no es válido.';
      case 'user-disabled':
        return 'Usuario desactivado. Contacte al super administrador.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Usuario o contraseña incorrectos.';
      case 'too-many-requests':
        return 'Demasiados intentos. Intente más tarde.';
      default:
        return error.message ?? 'No se pudo iniciar sesión.';
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
