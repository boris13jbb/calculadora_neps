/**
 * Destinatarios de alertas push según RoleDefinition.
 * Si no hay roles sembrados, fallback legacy controlado.
 * Si existe el documento del rol, ese documento manda.
 */

const LEGACY_ROLE_MAP = {
  ADMINISTRADOR: "admin",
  SUPERVISOR: "supervisor",
  OPERARIO: "operario",
  GERENCIA: "gerencia",
};

/** Roles que recibían push antes de sembrar RoleDefinition. */
const LEGACY_ALERT_ROLE_CODES = [
  "super_admin",
  "admin",
  "supervisor",
  "ADMINISTRADOR",
  "SUPERVISOR",
];

/**
 * @param {unknown} raw
 * @return {string}
 */
function normalizeAlertRoleCode(raw) {
  if (!raw || typeof raw !== "string") return "";
  const trimmed = raw.trim();
  if (!trimmed) return "";
  const mapped = LEGACY_ROLE_MAP[trimmed.toUpperCase()];
  return mapped || trimmed.toLowerCase();
}

/**
 * @param {object|null|undefined} roleData
 * @return {boolean}
 */
function roleDefinitionReceivesAlerts(roleData) {
  if (!roleData || roleData.isActive === false) return false;
  const permissions = roleData.permissions;
  return Array.isArray(permissions) && permissions.includes("viewAlerts");
}

/**
 * Códigos de rol que pueden recibir alertas.
 * Sin documentos: fallback legacy.
 * Con documentos: solo los activos con viewAlerts, más bases aún no sembrados.
 * @param {Array<{id?: string, code?: string}|object>} roleDocs
 * @return {{seeded: boolean, codes: Set<string>}}
 */
function resolveAlertRecipientRoleCodes(roleDocs) {
  const docs = Array.isArray(roleDocs) ? roleDocs : [];
  if (docs.length === 0) {
    return {
      seeded: false,
      codes: new Set(LEGACY_ALERT_ROLE_CODES),
    };
  }

  const present = new Set();
  const codes = new Set();

  for (const doc of docs) {
    const id = String(doc.id || doc.code || "").trim();
    const normalized = normalizeAlertRoleCode(id || doc.code);
    if (id) present.add(id);
    if (normalized) present.add(normalized);
    if (!roleDefinitionReceivesAlerts(doc)) continue;
    if (id) codes.add(id);
    if (normalized) codes.add(normalized);
  }

  // Base aún no sembrado: conserva el aviso crítico durante la migración.
  if (!present.has("super_admin")) codes.add("super_admin");
  if (!present.has("admin")) {
    codes.add("admin");
    codes.add("ADMINISTRADOR");
  }
  if (!present.has("supervisor")) {
    codes.add("supervisor");
    codes.add("SUPERVISOR");
  }

  return {seeded: true, codes};
}

/**
 * @param {Map<string, object>|Record<string, object>|null} roleByCode
 * @param {string} rawRole
 * @return {object|null}
 */
function lookupRoleDefinition(roleByCode, rawRole) {
  if (!roleByCode) return null;
  const get = (key) => {
    if (roleByCode instanceof Map) return roleByCode.get(key) || null;
    return roleByCode[key] || null;
  };
  const direct = get(rawRole);
  if (direct) return direct;
  const normalized = normalizeAlertRoleCode(rawRole);
  if (!normalized) return null;
  return get(normalized);
}

/**
 * Usuario elegible: activo, no eliminado, token válido y rol autorizado.
 * @param {object|null|undefined} user
 * @param {Set<string>} recipientRoleCodes
 * @param {Map<string, object>|Record<string, object>|null} [roleByCode]
 * @return {boolean}
 */
function isEligibleAlertRecipient(user, recipientRoleCodes, roleByCode) {
  if (!user) return false;
  if (user.isActive === false) return false;
  if (user.deletedAt !== null && user.deletedAt !== undefined) return false;

  const token = user.fcmToken;
  if (typeof token !== "string" || token.trim().length === 0) return false;

  const rawRole = String(user.role || "").trim();
  if (!rawRole) return false;

  const roleDoc = lookupRoleDefinition(roleByCode, rawRole);
  if (roleDoc) {
    return roleDefinitionReceivesAlerts(roleDoc);
  }

  const codes = recipientRoleCodes || new Set();
  const normalized = normalizeAlertRoleCode(rawRole);
  return codes.has(rawRole) || (normalized !== "" && codes.has(normalized));
}

/**
 * @param {object[]} users
 * @param {Set<string>} recipientRoleCodes
 * @param {Map<string, object>|Record<string, object>|null} [roleByCode]
 * @return {string[]}
 */
function collectUniqueFcmTokens(users, recipientRoleCodes, roleByCode) {
  const seen = new Set();
  const tokens = [];
  for (const user of users || []) {
    if (!isEligibleAlertRecipient(user, recipientRoleCodes, roleByCode)) {
      continue;
    }
    const token = user.fcmToken.trim();
    if (seen.has(token)) continue;
    seen.add(token);
    tokens.push(token);
  }
  return tokens;
}

/**
 * @param {Array<{id?: string}>} roleDocs
 * @return {Map<string, object>}
 */
function indexRoleDefinitions(roleDocs) {
  const map = new Map();
  for (const doc of roleDocs || []) {
    const id = String(doc.id || doc.code || "").trim();
    if (id) map.set(id, doc);
    const normalized = normalizeAlertRoleCode(id);
    if (normalized) map.set(normalized, doc);
  }
  return map;
}

/**
 * Carga roles y usuarios y devuelve tokens FCM únicos.
 * No usa consultas `in` (el catálogo de roles puede crecer).
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} workspaceId
 * @return {Promise<string[]>}
 */
async function collectCriticalAlertTokens(db, workspaceId) {
  const rolesSnap = await db
      .collection(`workspaces/${workspaceId}/roles`)
      .get();
  const roleDocs = rolesSnap.docs.map((doc) => ({
    id: doc.id,
    ...(doc.data() || {}),
  }));
  const resolved = resolveAlertRecipientRoleCodes(roleDocs);
  const roleByCode = indexRoleDefinitions(roleDocs);

  const usersSnap = await db
      .collection(`workspaces/${workspaceId}/users`)
      .get();
  const users = usersSnap.docs.map((doc) => doc.data() || {});
  return collectUniqueFcmTokens(users, resolved.codes, roleByCode);
}

module.exports = {
  LEGACY_ALERT_ROLE_CODES,
  normalizeAlertRoleCode,
  roleDefinitionReceivesAlerts,
  resolveAlertRecipientRoleCodes,
  isEligibleAlertRecipient,
  collectUniqueFcmTokens,
  collectCriticalAlertTokens,
};
