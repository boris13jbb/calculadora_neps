import '../../models/app_user_role.dart';
import '../../models/nep_record.dart';
import 'role_catalog.dart';

/// Roles que pueden leer registros de todos los operarios (alineado con firestore.rules).
bool canViewWorkspaceRecords(AppUserRole role) {
  return canViewWorkspaceRecordsForCode(role.code);
}

/// Variante por roleCode (roles parametrizables). Deny-by-default.
bool canViewWorkspaceRecordsForCode(String? roleCode) {
  return RoleCatalog.instance.seesWorkspaceRecords(roleCode);
}

/// Criterio de propiedad verificable.
///
/// - [NepRecord.createdByUid]: autoría del registro (quién lo capturó). Inmutable
///   salvo intervención administrativa explícita en rules.
/// - `ownerUid` en Firestore: propietario del documento (ruta users/{uid}/records
///   y campo en workspace). Debe coincidir con createdByUid en altas normales.
///
/// Un registro legacy sin createdByUid/ownerUid es **ambiguo**: no se atribuye
/// automáticamente al usuario que inicia sesión.
String? verifiedRecordOwnerUid(NepRecord record) {
  final created = record.createdByUid?.trim();
  if (created != null && created.isNotEmpty) return created;
  return null;
}

/// Propietario efectivo para una escritura nueva del usuario autenticado.
///
/// Si el registro ya tiene dueño verificable, lo conserva.
/// Si no tiene dueño (borrador nuevo), usa [currentUid] solo al crear.
/// Nunca reasigna un dueño ajeno al [currentUid].
String recordOwnerUid(NepRecord record, String currentUid) {
  final verified = verifiedRecordOwnerUid(record);
  if (verified != null) return verified;
  return currentUid;
}

/// True si el registro pertenece de forma verificable a [uid].
bool recordBelongsToUid(NepRecord record, String uid) {
  final owner = verifiedRecordOwnerUid(record);
  return owner != null && owner == uid;
}

/// True si el registro no tiene dueño verificable (legacy ambiguo).
bool isAmbiguousOwnership(NepRecord record) {
  return verifiedRecordOwnerUid(record) == null;
}
