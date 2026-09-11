import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../core/constants.dart';
import '../core/permissions/role_catalog.dart';
import '../models/role_definition.dart';
import '../utils/firestore_json_helper.dart';

/// Persistencia de roles en `workspaces/{id}/roles/{roleCode}`.
class RoleRepository {
  RoleRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  static RoleRepository? _singleton;
  static RoleRepository get instance => _singleton ??= RoleRepository();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _rolesRef => _firestore
      .collection('workspaces')
      .doc(cloudWorkspaceId)
      .collection('roles');

  /// Carga roles remotos al [RoleCatalog]. Si no hay docs, siembra bases.
  Future<List<RoleDefinition>> listRoles({bool ensureBase = true}) async {
    final snap = await _rolesRef.get();
    if (snap.docs.isEmpty && ensureBase) {
      await ensureBaseRoles();
      final seeded = await _rolesRef.get();
      return _mapAndCache(seeded.docs);
    }
    return _mapAndCache(snap.docs);
  }

  List<RoleDefinition> _mapAndCache(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final roles = docs.map((doc) {
      final data = FirestoreJsonHelper.normalizeMap(doc.data());
      data['code'] ??= doc.id;
      return RoleDefinition.fromJson(data);
    }).toList();
    RoleCatalog.instance.replaceAll(roles);
    return RoleCatalog.instance.listAll();
  }

  Future<RoleDefinition?> getRole(String code) async {
    final normalized = RoleCatalog.normalizeRoleCode(code);
    if (normalized == null) return null;
    final doc = await _rolesRef.doc(normalized).get();
    if (!doc.exists || doc.data() == null) {
      return RoleCatalog.instance.get(normalized);
    }
    final data = FirestoreJsonHelper.normalizeMap(doc.data()!);
    data['code'] ??= doc.id;
    final role = RoleDefinition.fromJson(data);
    RoleCatalog.instance.upsert(role);
    return role;
  }

  /// Carga la definición del rol autenticado antes de evaluar permisos.
  /// Roles base: fallback local si aún no hay doc. Custom: deny si no existe.
  Future<void> ensureAuthorizationForRole(String roleCode) async {
    final normalized = RoleCatalog.normalizeRoleCode(roleCode) ?? '';
    try {
      if (normalized.isEmpty) {
        RoleCatalog.instance.markAuthorizationReady();
        return;
      }

      final remote = await getRole(normalized);
      if (remote != null) {
        RoleCatalog.instance.upsert(remote);
      } else if (!RoleCatalog.systemRoleCodes.contains(normalized)) {
        // Custom desconocido: no conceder permisos de base.
        RoleCatalog.instance.replaceAll(
          RoleCatalog.instance.listAll().where((r) => r.code != normalized),
        );
      }
      RoleCatalog.instance.markAuthorizationReady();
    } catch (_) {
      // Sin red: base local solo para system roles; custom → deny.
      if (!RoleCatalog.systemRoleCodes.contains(normalized)) {
        RoleCatalog.instance.replaceAll(RoleCatalog.baseRoles);
      }
      RoleCatalog.instance.markAuthorizationReady();
    }
  }

  Future<void> ensureBaseRoles() async {
    final now = DateTime.now().toUtc();
    final existing = await _rolesRef.get();
    final existingIds = existing.docs.map((d) => d.id).toSet();
    final batch = _firestore.batch();
    var writes = 0;
    for (final role in RoleCatalog.baseRoles) {
      if (existingIds.contains(role.code)) continue;
      final ref = _rolesRef.doc(role.code);
      batch.set(ref, {
        ...role.toJson(),
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      });
      writes++;
    }
    if (writes > 0) {
      await batch.commit();
    }
    RoleCatalog.instance.replaceAll(RoleCatalog.baseRoles);
  }

  Future<RoleDefinition> createRole(RoleDefinition role) async {
    final codeError = RoleDefinition.validateCode(role.code);
    if (codeError != null) {
      throw StateError(codeError);
    }
    final code = role.code.trim().toLowerCase();
    if (RoleCatalog.systemRoleCodes.contains(code)) {
      throw StateError('No se pueden crear roles de sistema');
    }
    final existing = await _rolesRef.doc(code).get();
    if (existing.exists) {
      throw StateError('Ya existe un rol con código "$code"');
    }

    final uid = _auth.currentUser?.uid;
    final now = DateTime.now().toUtc();
    final toSave = role.copyWith(
      code: code,
      isSystem: false,
      isAssignable: role.isAssignable,
      createdAt: now,
      updatedAt: now,
      createdBy: uid,
    );
    await _rolesRef.doc(code).set(toSave.toJson());
    RoleCatalog.instance.upsert(toSave);
    return toSave;
  }

  Future<RoleDefinition> updateRole(RoleDefinition role) async {
    final code = RoleCatalog.normalizeRoleCode(role.code);
    if (code == null) throw StateError('Código de rol inválido');
    if (code == 'super_admin') {
      throw StateError('El rol super_admin no se puede modificar');
    }

    final current = await getRole(code);
    if (current == null) throw StateError('Rol no encontrado');

    final uid = _auth.currentUser?.uid;
    final now = DateTime.now().toUtc();
    final toSave = role.copyWith(
      code: code,
      isSystem: current.isSystem,
      updatedAt: now,
      createdAt: current.createdAt,
      createdBy: current.createdBy ?? uid,
    );
    await _rolesRef.doc(code).set(toSave.toJson(), SetOptions(merge: true));
    RoleCatalog.instance.upsert(toSave);
    return toSave;
  }

  Future<RoleDefinition> activateRole(String code) async {
    return _setActive(code, true);
  }

  Future<RoleDefinition> deactivateRole(String code) async {
    return _setActive(code, false);
  }

  Future<RoleDefinition> _setActive(String code, bool active) async {
    final normalized = RoleCatalog.normalizeRoleCode(code);
    if (normalized == null) throw StateError('Código de rol inválido');
    if (normalized == 'super_admin') {
      throw StateError('El rol super_admin no se puede desactivar');
    }
    final current = await getRole(normalized);
    if (current == null) throw StateError('Rol no encontrado');
    final updated = current.copyWith(
      isActive: active,
      updatedAt: DateTime.now().toUtc(),
    );
    await _rolesRef
        .doc(normalized)
        .set(updated.toJson(), SetOptions(merge: true));
    RoleCatalog.instance.upsert(updated);
    return updated;
  }

  /// Eliminación vía Cloud Function (Rules niegan delete directo).
  Future<void> deleteRole(String code) async {
    final normalized = RoleCatalog.normalizeRoleCode(code);
    if (normalized == null) throw StateError('Código de rol inválido');
    if (RoleCatalog.systemRoleCodes.contains(normalized)) {
      throw StateError('No se pueden eliminar roles de sistema');
    }
    final callable = FirebaseFunctions.instanceFor(
      app: Firebase.app(),
      region: 'us-central1',
    ).httpsCallable('deleteRole');
    await callable.call(<String, dynamic>{'code': normalized});
    await listRoles(ensureBase: false);
  }

  Future<int> countUsersWithRole(String code) async {
    final normalized = RoleCatalog.normalizeRoleCode(code);
    if (normalized == null) return 0;
    final snap = await _firestore
        .collection('workspaces')
        .doc(cloudWorkspaceId)
        .collection('users')
        .where('role', isEqualTo: normalized)
        .limit(500)
        .get();
    return snap.docs.where((d) => d.data()['deletedAt'] == null).length;
  }
}
