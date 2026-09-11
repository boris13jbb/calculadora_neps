import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../core/constants.dart';
import '../core/permissions/role_catalog.dart';
import '../models/role_definition.dart';
import 'role_collection_gateway.dart';

/// Persistencia de roles en `workspaces/{id}/roles/{roleCode}`.
class RoleRepository {
  RoleRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    RoleCollectionGateway? roles,
    Future<int> Function(String roleCode)? countUsersWithRole,
  })  : _firestore = firestore,
        _auth = auth,
        _roles = roles ??
            FirestoreRoleCollectionGateway(
              firestore ?? FirebaseFirestore.instance,
            ),
        _countUsersWithRole = countUsersWithRole;

  static RoleRepository? _singleton;
  static RoleRepository get instance => _singleton ??= RoleRepository();

  final FirebaseFirestore? _firestore;
  final FirebaseAuth? _auth;
  final RoleCollectionGateway _roles;
  final Future<int> Function(String roleCode)? _countUsersWithRole;

  /// Lee roles remotos. Una lectura nunca crea documentos.
  Future<List<RoleDefinition>> listRoles() async {
    final docs = await _roles.listDocuments();
    final roles = docs.map(RoleDefinition.fromJson).toList()
      ..sort((a, b) {
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        if (byOrder != 0) return byOrder;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    RoleCatalog.instance.replaceAll(roles);
    return roles;
  }

  Future<RoleDefinition?> getRole(String code) async {
    final normalized = RoleCatalog.normalizeRoleCode(code);
    if (normalized == null) return null;
    final data = await _roles.getDocument(normalized);
    if (data == null) {
      return RoleCatalog.instance.get(normalized);
    }
    final role = RoleDefinition.fromJson(data);
    RoleCatalog.instance.upsert(role);
    return role;
  }

  /// Carga la definición del rol autenticado antes de evaluar permisos.
  /// Solo lectura: roles base usan fallback local si no hay documento.
  /// Un rol custom inexistente se niega y no se crea.
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

  /// Crea los 5 roles base solo si faltan. Idempotente. No es una lectura.
  Future<void> ensureBaseRoles() async {
    final now = DateTime.now().toUtc();
    final existing = await _roles.listDocuments();
    final existingIds = existing
        .map((doc) => (doc['code'] ?? '').toString())
        .where((code) => code.isNotEmpty)
        .toSet();
    for (final role in RoleCatalog.baseRoles) {
      if (existingIds.contains(role.code)) continue;
      await _roles.setDocument(role.code, {
        ...role.toJson(),
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      });
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
    final existing = await _roles.getDocument(code);
    if (existing != null) {
      throw StateError('Ya existe un rol con código "$code"');
    }

    final uid = _auth?.currentUser?.uid;
    final now = DateTime.now().toUtc();
    final toSave = role.copyWith(
      code: code,
      isSystem: false,
      isAssignable: role.isAssignable,
      createdAt: now,
      updatedAt: now,
      createdBy: uid,
    );
    await _roles.setDocument(code, toSave.toJson());
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

    final uid = _auth?.currentUser?.uid;
    final now = DateTime.now().toUtc();
    final toSave = role.copyWith(
      code: code,
      isSystem: current.isSystem,
      updatedAt: now,
      createdAt: current.createdAt,
      createdBy: current.createdBy ?? uid,
    );
    await _roles.setDocument(code, toSave.toJson(), merge: true);
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
    await _roles.setDocument(normalized, updated.toJson(), merge: true);
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
    await listRoles();
  }

  Future<int> countUsersWithRole(String code) async {
    final normalized = RoleCatalog.normalizeRoleCode(code);
    if (normalized == null) return 0;
    final override = _countUsersWithRole;
    if (override != null) return override(normalized);
    final firestore = _firestore ?? FirebaseFirestore.instance;
    final snap = await firestore
        .collection('workspaces')
        .doc(cloudWorkspaceId)
        .collection('users')
        .where('role', isEqualTo: normalized)
        .limit(500)
        .get();
    return snap.docs.where((d) => d.data()['deletedAt'] == null).length;
  }
}
