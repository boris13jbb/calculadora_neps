import '../../models/app_user_role.dart';
import '../../models/nep_record.dart';

/// Roles que pueden leer registros de todos los operarios (alineado con firestore.rules).
bool canViewWorkspaceRecords(AppUserRole role) {
  return role.isSupervisorOrAbove || role.isGerencia;
}

/// UID del propietario del registro en Firestore (subcolección por usuario).
String recordOwnerUid(NepRecord record, String currentUid) {
  final owner = record.createdByUid?.trim();
  if (owner != null && owner.isNotEmpty) return owner;
  return currentUid;
}
