import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  static final RoleRepository instance = RoleRepository();

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

  Future<void> ensureBaseRoles() async {
    final batch = _firestore.batch();
    final now = DateTime.now().toUtc();
    for (final role in RoleCatalog.baseRoles) {
      final ref = _rolesRef.doc(role.code);
      batch.set(
        ref,
        {
          ...role.toJson(),
          'createdAt':
              role.createdAt?.toIso8601String() ?? now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
    RoleCatalog.instance.replaceAll(RoleCatalog.baseRoles);
  }

  Future<RoleDefinition> createRole(RoleDefinition role) async {
    final codeError = RoleDefinition.validateCode(role.code);
    if (codeError != null) {
      throw StateError(codeError);
    }
    final code = role.code.trim().toLowerCase();
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
      // System roles keep system flag; name/permissions editable.
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

  /// Soft-delete preferido: desactivar. Eliminación física solo si no es system
  /// y [assignedUserCount] == 0.
  Future<void> deleteRoleIfUnused(String code,
      {required int assignedUserCount}) async {
    final normalized = RoleCatalog.normalizeRoleCode(code);
    if (normalized == null) throw StateError('Código de rol inválido');
    final current = await getRole(normalized);
    if (current == null) return;
    if (current.isSystem || current.isSuperAdmin) {
      throw StateError('No se pueden eliminar roles de sistema');
    }
    if (assignedUserCount > 0) {
      throw StateError(
        'El rol tiene usuarios asignados. Desactívelo en su lugar.',
      );
    }
    await _rolesRef.doc(normalized).delete();
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
