import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants.dart';
import '../models/app_user.dart';
import '../models/app_user_role.dart';
import '../utils/firestore_json_helper.dart';
import '../utils/username_auth_helper.dart';

class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _authOverride = auth,
        _firestoreOverride = firestore;

  final FirebaseAuth? _authOverride;
  final FirebaseFirestore? _firestoreOverride;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  User? get currentFirebaseUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Login con usuario visible o correo real del super_admin.
  Future<UserCredential> signInWithUsernameOrEmail({
    required String usernameOrEmail,
    required String password,
  }) async {
    final authEmail = UsernameAuthHelper.resolveSignInEmail(usernameOrEmail);
    return _auth.signInWithEmailAndPassword(
      email: authEmail,
      password: password,
    );
  }

  Future<void> signOut() => _auth.signOut();

  /// Recuperación por correo — solo aplica a super_admin con email real.
  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
  }

  Future<void> refreshIdToken() async {
    await _auth.currentUser?.getIdToken(true);
  }

  Future<Map<String, dynamic>> getIdTokenClaims() async {
    final user = _auth.currentUser;
    if (user == null) return {};
    final result = await user.getIdTokenResult(true);
    return Map<String, dynamic>.from(result.claims ?? {});
  }

  static bool isEmail(String value) => UsernameAuthHelper.isEmail(value);

  static String buildInternalEmail(String username) =>
      UsernameAuthHelper.buildInternalEmail(username);

  static String normalizeUsername(String value) =>
      UsernameAuthHelper.normalizeUsername(value);

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) {
    return _firestore
        .collection('workspaces')
        .doc(cloudWorkspaceId)
        .collection('users')
        .doc(uid);
  }

  Future<AppUser?> fetchUserProfile(String uid) async {
    final snap = await _userDoc(uid).get();
    if (!snap.exists || snap.data() == null) return null;

    final data = FirestoreJsonHelper.normalizeMap(
      Map<String, dynamic>.from(snap.data()!),
    );
    data['uid'] ??= uid;
    return AppUser.fromJson(data);
  }

  Future<void> touchLastLogin(String uid) async {
    await _userDoc(uid).set(
      {'lastLoginAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  AppUserRole resolveRoleFromClaims(Map<String, dynamic> claims) {
    final role = claims['role']?.toString();
    if (role != null && role.isNotEmpty) {
      return AppUserRole.fromCode(role);
    }
    if (claims['isSuperAdmin'] == true || claims['superAdmin'] == true) {
      return AppUserRole.superAdmin;
    }
    return AppUserRole.operario;
  }
}
