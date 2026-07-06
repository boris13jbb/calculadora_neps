const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {defineString} = require("firebase-functions/params");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {logger} = require("firebase-functions");

const callOptions = {region: "us-central1", invoker: "public"};

const bootstrapSecret = defineString("BOOTSTRAP_SUPER_ADMIN_SECRET");

const WORKSPACE_ID = "vicunha";
const INTERNAL_EMAIL_DOMAIN = "vicunha.local";
const USERNAME_PATTERN = /^[a-z0-9][a-z0-9._-]*$/;

const VALID_ROLES = new Set([
  "super_admin",
  "admin",
  "supervisor",
  "operario",
  "gerencia",
]);

const LEGACY_ROLE_MAP = {
  ADMINISTRADOR: "admin",
  SUPERVISOR: "supervisor",
  OPERARIO: "operario",
  GERENCIA: "gerencia",
};

/**
 * @param {string|null|undefined} raw
 * @return {string}
 */
function normalizeRole(raw) {
  if (!raw || typeof raw !== "string") return "operario";
  const trimmed = raw.trim();
  const lower = trimmed.toLowerCase();
  if (VALID_ROLES.has(lower)) return lower;
  return LEGACY_ROLE_MAP[trimmed.toUpperCase()] || "operario";
}

/**
 * @param {string} raw
 * @return {string}
 */
function normalizeUsername(raw) {
  return String(raw || "").trim().toLowerCase().replace(/\s+/g, "");
}

/**
 * @param {string} username
 * @return {boolean}
 */
function isValidUsername(username) {
  const normalized = normalizeUsername(username);
  if (!normalized || normalized.length > 64) return false;
  return USERNAME_PATTERN.test(normalized);
}

/**
 * @param {string} username
 * @return {string}
 */
function buildInternalEmail(username) {
  return `${normalizeUsername(username)}@${INTERNAL_EMAIL_DOMAIN}`;
}

/**
 * @param {string} role
 * @param {string} username
 * @param {string} workspaceId
 * @return {Object}
 */
function buildClaims(role, username, workspaceId = WORKSPACE_ID) {
  const claims = {
    role,
    workspaceId,
    username: normalizeUsername(username),
  };
  if (role === "super_admin") {
    claims.isSuperAdmin = true;
    claims.superAdmin = true;
  }
  return claims;
}

/**
 * @param {Object|null|undefined} profile
 * @return {string}
 */
function profileUsername(profile) {
  if (!profile) return "";
  if (profile.username) return String(profile.username);
  if (profile.internalEmail) {
    return String(profile.internalEmail).split("@")[0];
  }
  if (profile.realEmail) return String(profile.realEmail).split("@")[0];
  if (profile.email) return String(profile.email).split("@")[0];
  return "";
}

/**
 * @param {import("firebase-admin/firestore").Firestore} db
 * @param {Object} data
 */
async function writeAudit(db, data) {
  await db.collection(`workspaces/${WORKSPACE_ID}/audit_logs`).add({
    ...data,
    createdAt: FieldValue.serverTimestamp(),
  });
}

/**
 * @param {import("firebase-admin/firestore").Firestore} db
 * @param {string} username
 * @param {string|null} excludeUid
 */
async function usernameExists(db, username, excludeUid = null) {
  const normalized = normalizeUsername(username);
  const snap = await db.collection(`workspaces/${WORKSPACE_ID}/users`).get();
  return snap.docs.some((doc) => {
    if (excludeUid && doc.id === excludeUid) return false;
    const data = doc.data() || {};
    if (data.deletedAt) return false;
    const existing = normalizeUsername(data.username || profileUsername(data));
    return existing === normalized;
  });
}

/**
 * @param {import("firebase-functions/v2/https").CallableRequest} request
 */
async function assertSuperAdmin(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Debe iniciar sesión.");
  }

  const token = request.auth.token;
  const role = normalizeRole(token.role);
  const isSuper = role === "super_admin" ||
    token.isSuperAdmin === true ||
    token.superAdmin === true;
  if (!isSuper) {
    throw new HttpsError(
        "permission-denied",
        "Solo un super administrador puede realizar esta acción.",
    );
  }

  const db = getFirestore();
  const userDoc = await db
      .doc(`workspaces/${WORKSPACE_ID}/users/${request.auth.uid}`)
      .get();

  if (!userDoc.exists) {
    throw new HttpsError("permission-denied", "Perfil de usuario no encontrado.");
  }

  const profile = userDoc.data() || {};
  if (profile.isActive === false || profile.deletedAt) {
    throw new HttpsError("permission-denied", "Su cuenta está desactivada.");
  }

  return {
    db,
    uid: request.auth.uid,
    username: profileUsername(profile),
    email: token.email || profile.realEmail || profile.email || "",
  };
}

/**
 * @param {import("firebase-admin/firestore").Firestore} db
 */
async function countActiveSuperAdmins(db) {
  const snap = await db
      .collection(`workspaces/${WORKSPACE_ID}/users`)
      .where("role", "==", "super_admin")
      .where("isActive", "==", true)
      .get();

  return snap.docs.filter((doc) => !doc.data().deletedAt).length;
}

/**
 * @param {Object|null|undefined} data
 * @return {Object}
 */
function serializeUserDoc(data) {
  if (!data) return {};
  const result = {...data};
  for (const key of ["createdAt", "updatedAt", "lastLoginAt", "deletedAt"]) {
    if (result[key] && typeof result[key].toDate === "function") {
      result[key] = result[key].toDate().toISOString();
    }
  }
  result.role = normalizeRole(result.role);
  if (!result.username) {
    result.username = profileUsername(result);
  }
  return result;
}

/**
 * Fuerza payload JSON plano para clientes web (sin Timestamp/Int64).
 * @param {*} payload
 * @return {*}
 */
function toCallablePayload(payload) {
  return JSON.parse(JSON.stringify(payload, (_key, value) => {
    if (value === null || value === undefined) return value;
    if (typeof value === "object" && typeof value.toDate === "function") {
      return value.toDate().toISOString();
    }
    return value;
  }));
}

/**
 * @param {import("firebase-functions/v2/https").CallableRequest} request
 */
async function assertAuthenticated(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Debe iniciar sesión.");
  }
  const db = getFirestore();
  const snap = await db
      .doc(`workspaces/${WORKSPACE_ID}/users/${request.auth.uid}`)
      .get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Perfil no encontrado.");
  }
  const data = snap.data() || {};
  if (data.isActive === false || data.deletedAt) {
    throw new HttpsError("permission-denied", "Cuenta desactivada.");
  }
  return {db, uid: request.auth.uid, profile: data};
}

/**
 * Valida que el UID solicitante sea super admin activo (ruta de trigger,
 * donde no hay `request.auth`). Lanza Error plano para el manejo de la cola.
 * @param {import("firebase-admin/firestore").Firestore} db
 * @param {string} uid
 * @return {Promise<{profile: Object, username: string}>}
 */
async function assertRequesterIsSuperAdmin(db, uid) {
  if (!uid) {
    throw new Error("Solicitud sin autor.");
  }
  const snap = await db.doc(`workspaces/${WORKSPACE_ID}/users/${uid}`).get();
  if (!snap.exists) {
    throw new Error("Perfil del solicitante no encontrado.");
  }
  const profile = snap.data() || {};
  const isSuper = normalizeRole(profile.role) === "super_admin" ||
    profile.isSuperAdmin === true;
  if (!isSuper) {
    throw new Error("Solo un super administrador puede realizar esta acción.");
  }
  if (profile.isActive === false || profile.deletedAt) {
    throw new Error("Cuenta del solicitante desactivada.");
  }
  return {profile, username: profileUsername(profile)};
}

/**
 * Traduce un Error plano de las funciones execute* a un HttpsError con el
 * código adecuado, preservando el comportamiento previo de los callables.
 * @param {Error} error
 * @return {HttpsError}
 */
function mapUserAdminError(error) {
  if (error instanceof HttpsError) return error;
  const message = error.message || "No se pudo completar la operación.";
  const lower = message.toLowerCase();
  if (lower.includes("ya existe")) {
    return new HttpsError("already-exists", message);
  }
  if (lower.includes("no encontrado")) {
    return new HttpsError("not-found", message);
  }
  if (lower.includes("último super") ||
      lower.includes("no puede") ||
      lower.includes("propia cuenta")) {
    return new HttpsError("failed-precondition", message);
  }
  if (lower.includes("requerido") ||
      lower.includes("inválid") ||
      lower.includes("contraseña") ||
      lower.includes("rol no válido") ||
      lower.includes("super_admin desde el panel") ||
      lower.includes("super administrador")) {
    return new HttpsError("invalid-argument", message);
  }
  return new HttpsError("internal", message);
}

/**
 * Crea un usuario en Auth + Firestore (lógica compartida callable / trigger).
 * @param {import("firebase-admin/firestore").Firestore} db
 * @param {import("firebase-admin/auth").Auth} auth
 * @param {Object} params
 * @return {Promise<Object>}
 */
async function executeCreateAppUser(db, auth, params) {
  const username = normalizeUsername(params.username);
  const password = String(params.password || "");
  const displayName = String(params.displayName || "").trim();
  const role = normalizeRole(params.role);
  const isActive = params.isActive !== false;
  const performedByUid = String(params.performedByUid || "");
  const performedByUsername = String(params.performedByUsername || "");

  if (!isValidUsername(username)) {
    throw new Error(
        "Usuario inválido. Use letras, números, punto, guion o guion bajo.",
    );
  }
  if (password.length < 8) {
    throw new Error("La contraseña debe tener al menos 8 caracteres.");
  }
  if (!VALID_ROLES.has(role)) {
    throw new Error("Rol no válido.");
  }
  if (role === "super_admin") {
    throw new Error(
        "Use el script create_super_admin.js para crear super administradores.",
    );
  }
  if (!performedByUid) {
    throw new Error("Solicitud sin autor.");
  }

  if (await usernameExists(db, username)) {
    throw new Error("El usuario ya existe.");
  }

  const internalEmail = buildInternalEmail(username);
  let createdUser;
  let recoveredAuthUser = false;
  let createError;
  try {
    createdUser = await auth.createUser({
      email: internalEmail,
      password,
      displayName: displayName || username,
      disabled: !isActive,
    });
  } catch (error) {
    createError = error;
    const message = String(error.message || "");
    const isEmailInUse =
      error.code === "auth/email-already-exists" ||
      message.toLowerCase().includes("email address is already in use");

    if (isEmailInUse) {
      const existingAuthUser = await auth
          .getUserByEmail(internalEmail)
          .catch(() => null);
      const existingProfile = existingAuthUser ?
        await db
            .doc(`workspaces/${WORKSPACE_ID}/users/${existingAuthUser.uid}`)
            .get() :
        null;

      if (existingAuthUser && existingProfile && !existingProfile.exists) {
        try {
          createdUser = await auth.updateUser(existingAuthUser.uid, {
            password,
            displayName: displayName || username,
            disabled: !isActive,
          });
          recoveredAuthUser = true;
        } catch (recoveryError) {
          createError = recoveryError;
        }
      }
    }

    if (createdUser) {
      logger.warn("createAppUser recovered orphan Auth user", {
        uid: createdUser.uid,
        username,
      });
    }
  }

  if (!createdUser) {
    logger.error("createAppUser error", createError);
    throw new Error(
        createError?.message || "No se pudo crear el usuario.",
    );
  }

  const claims = buildClaims(role, username);
  await auth.setCustomUserClaims(createdUser.uid, claims);

  const userData = {
    uid: createdUser.uid,
    username,
    internalEmail,
    realEmail: null,
    displayName: displayName || username,
    role,
    isActive,
    isSuperAdmin: false,
    createdBy: performedByUid,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
    deletedAt: null,
  };

  await db
      .doc(`workspaces/${WORKSPACE_ID}/users/${createdUser.uid}`)
      .set(userData);

  await writeAudit(db, {
    action: "user_created",
    performedByUid,
    performedByUsername,
    targetUid: createdUser.uid,
    targetUsername: username,
    newValue: {
      role,
      isActive,
      displayName: userData.displayName,
      recoveredAuthUser,
    },
  });

  const nowIso = new Date().toISOString();
  return serializeUserDoc({
    uid: createdUser.uid,
    username,
    internalEmail,
    realEmail: null,
    displayName: displayName || username,
    role,
    isActive,
    isSuperAdmin: false,
    createdBy: performedByUid,
    createdAt: nowIso,
    updatedAt: nowIso,
    deletedAt: null,
  });
}

/**
 * Carga el documento del usuario objetivo o lanza Error si no existe.
 * @param {import("firebase-admin/firestore").Firestore} db
 * @param {string} targetUid
 * @return {Promise<{userRef: Object, existing: Object}>}
 */
async function loadTargetUser(db, targetUid) {
  if (!targetUid) {
    throw new Error("UID requerido.");
  }
  const userRef = db.doc(`workspaces/${WORKSPACE_ID}/users/${targetUid}`);
  const userSnap = await userRef.get();
  if (!userSnap.exists) {
    throw new Error("Usuario no encontrado.");
  }
  return {userRef, existing: userSnap.data() || {}};
}

/**
 * Actualiza nombre, rol y/o estado (lógica compartida callable / trigger).
 * Solo procesa los campos presentes (distintos de undefined).
 * @param {import("firebase-admin/firestore").Firestore} db
 * @param {import("firebase-admin/auth").Auth} auth
 * @param {Object} params
 * @return {Promise<Object>}
 */
async function executeUpdateAppUser(db, auth, params) {
  const targetUid = String(params.targetUid || "");
  const performedByUid = String(params.performedByUid || "");
  const performedByUsername = String(params.performedByUsername || "");

  const {userRef, existing} = await loadTargetUser(db, targetUid);
  const updates = {updatedAt: FieldValue.serverTimestamp()};

  if (params.displayName !== undefined && params.displayName !== null) {
    updates.displayName = String(params.displayName).trim();
    await auth.updateUser(targetUid, {displayName: updates.displayName});
  }

  let roleChanged = false;
  if (params.role !== undefined && params.role !== null) {
    const newRole = normalizeRole(params.role);
    if (!VALID_ROLES.has(newRole)) {
      throw new Error("Rol no válido.");
    }

    const oldRole = normalizeRole(existing.role);
    if (oldRole === "super_admin" && newRole !== "super_admin") {
      const count = await countActiveSuperAdmins(db);
      if (count <= 1 && existing.isActive !== false) {
        throw new Error(
            "No se puede cambiar el rol del último super administrador activo.",
        );
      }
    }

    if (targetUid === performedByUid && newRole !== "super_admin") {
      const count = await countActiveSuperAdmins(db);
      if (count <= 1) {
        throw new Error(
            "No puede quitarse el rol de super administrador siendo el único.",
        );
      }
    }

    if (newRole === "super_admin" && oldRole !== "super_admin") {
      throw new Error("No se puede promover a super_admin desde el panel.");
    }

    updates.role = newRole;
    roleChanged = oldRole !== newRole;
    await auth.setCustomUserClaims(
        targetUid,
        buildClaims(newRole, profileUsername(existing)),
    );
  }

  if (params.isActive !== undefined && params.isActive !== null) {
    const isActive = params.isActive === true;
    updates.isActive = isActive;
    await auth.updateUser(targetUid, {disabled: !isActive});
  }

  await userRef.set(updates, {merge: true});

  await writeAudit(db, {
    action: roleChanged ? "user_role_changed" : "user_updated",
    performedByUid,
    performedByUsername,
    targetUid,
    targetUsername: profileUsername(existing),
    oldValue: {
      role: normalizeRole(existing.role),
      isActive: existing.isActive !== false,
      displayName: existing.displayName,
    },
    newValue: updates,
  });

  const saved = await userRef.get();
  return serializeUserDoc({uid: targetUid, ...saved.data()});
}

/**
 * Activa o desactiva un usuario (lógica compartida callable / trigger).
 * @param {import("firebase-admin/firestore").Firestore} db
 * @param {import("firebase-admin/auth").Auth} auth
 * @param {Object} params
 * @param {boolean} enable
 * @return {Promise<Object>}
 */
async function executeSetUserActive(db, auth, params, enable) {
  const targetUid = String(params.targetUid || "");
  const performedByUid = String(params.performedByUid || "");
  const performedByUsername = String(params.performedByUsername || "");

  const {userRef, existing} = await loadTargetUser(db, targetUid);

  if (!enable && normalizeRole(existing.role) === "super_admin") {
    const count = await countActiveSuperAdmins(db);
    if (count <= 1 && existing.isActive !== false) {
      throw new Error("No se puede desactivar al último super administrador.");
    }
  }

  await auth.updateUser(targetUid, {disabled: !enable});
  await userRef.set(
      {isActive: enable, updatedAt: FieldValue.serverTimestamp()},
      {merge: true},
  );

  await writeAudit(db, {
    action: enable ? "user_enabled" : "user_disabled",
    performedByUid,
    performedByUsername,
    targetUid,
    targetUsername: profileUsername(existing),
  });

  const saved = await userRef.get();
  return serializeUserDoc({uid: targetUid, ...saved.data()});
}

/**
 * Elimina (soft delete) un usuario (lógica compartida callable / trigger).
 * @param {import("firebase-admin/firestore").Firestore} db
 * @param {import("firebase-admin/auth").Auth} auth
 * @param {Object} params
 * @return {Promise<Object>}
 */
async function executeDeleteAppUser(db, auth, params) {
  const targetUid = String(params.targetUid || "");
  const performedByUid = String(params.performedByUid || "");
  const performedByUsername = String(params.performedByUsername || "");

  if (!targetUid) {
    throw new Error("UID requerido.");
  }
  if (targetUid === performedByUid) {
    throw new Error("No puede eliminar su propia cuenta.");
  }

  const {userRef, existing} = await loadTargetUser(db, targetUid);

  if (normalizeRole(existing.role) === "super_admin") {
    const count = await countActiveSuperAdmins(db);
    if (count <= 1) {
      throw new Error("No se puede eliminar al último super administrador.");
    }
  }

  await userRef.set(
      {
        isActive: false,
        deletedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
  );

  try {
    await auth.updateUser(targetUid, {disabled: true});
  } catch (error) {
    logger.warn("Usuario Auth ya eliminado o inexistente", {targetUid, error});
  }

  await writeAudit(db, {
    action: "user_deleted",
    performedByUid,
    performedByUsername,
    targetUid,
    targetUsername: profileUsername(existing),
  });

  const saved = await userRef.get();
  return serializeUserDoc({uid: targetUid, ...saved.data()});
}

/**
 * Resetea la contraseña de un usuario (lógica compartida callable / trigger).
 * @param {import("firebase-admin/firestore").Firestore} db
 * @param {import("firebase-admin/auth").Auth} auth
 * @param {Object} params
 * @return {Promise<void>}
 */
async function executeResetAppUserPassword(db, auth, params) {
  const targetUid = String(params.targetUid || "");
  const newPassword = String(params.newPassword || "");
  const performedByUid = String(params.performedByUid || "");
  const performedByUsername = String(params.performedByUsername || "");

  if (!targetUid) {
    throw new Error("UID requerido.");
  }
  if (newPassword.length < 8) {
    throw new Error("La contraseña debe tener al menos 8 caracteres.");
  }

  const {existing} = await loadTargetUser(db, targetUid);
  const targetRole = normalizeRole(existing.role);

  await auth.updateUser(targetUid, {password: newPassword});

  await writeAudit(db, {
    action: "password_reset",
    performedByUid,
    performedByUsername,
    targetUid,
    targetUsername: profileUsername(existing),
    metadata: {targetRole},
  });
}

/**
 * @param {import("firebase-functions/v2/https").CallableRequest} request
 */
const createAppUser = onCall(callOptions, async (request) => {
  try {
    const {db, uid: performedByUid, username: performedByUsername} =
      await assertSuperAdmin(request);

    const user = await executeCreateAppUser(db, getAuth(), {
      username: request.data?.username,
      password: request.data?.password,
      displayName: request.data?.displayName,
      role: request.data?.role,
      isActive: request.data?.isActive,
      performedByUid,
      performedByUsername,
    });

    return toCallablePayload({user});
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    const message = error.message || "No se pudo crear el usuario.";
    if (message.includes("ya existe")) {
      throw new HttpsError("already-exists", message);
    }
    if (message.includes("inválid") ||
        message.includes("contraseña") ||
        message.includes("Rol") ||
        message.includes("super administrador")) {
      throw new HttpsError("invalid-argument", message);
    }
    throw new HttpsError("internal", message);
  }
});

/**
 * @param {import("firebase-functions/v2/https").CallableRequest} request
 */
const updateAppUser = onCall(callOptions, async (request) => {
  const {db, uid: performedByUid, username: performedByUsername} =
    await assertSuperAdmin(request);

  try {
    const user = await executeUpdateAppUser(db, getAuth(), {
      targetUid: request.data?.uid,
      displayName: request.data?.displayName ?? undefined,
      role: request.data?.role ?? undefined,
      isActive: request.data?.isActive ?? undefined,
      performedByUid,
      performedByUsername,
    });
    return toCallablePayload({user});
  } catch (error) {
    throw mapUserAdminError(error);
  }
});

/**
 * @param {import("firebase-functions/v2/https").CallableRequest} request
 */
const changeUserRole = onCall(callOptions, async (request) => {
  const {db, uid: performedByUid, username: performedByUsername} =
    await assertSuperAdmin(request);

  const targetUid = String(request.data?.uid || "");
  const newRole = normalizeRole(request.data?.role);

  if (!targetUid) {
    throw new HttpsError("invalid-argument", "UID requerido.");
  }
  if (!VALID_ROLES.has(newRole)) {
    throw new HttpsError("invalid-argument", "Rol no válido.");
  }

  const userRef = db.doc(`workspaces/${WORKSPACE_ID}/users/${targetUid}`);
  const userSnap = await userRef.get();
  if (!userSnap.exists) {
    throw new HttpsError("not-found", "Usuario no encontrado.");
  }

  const existing = userSnap.data() || {};
  const oldRole = normalizeRole(existing.role);

  if (oldRole === "super_admin" && newRole !== "super_admin") {
    const count = await countActiveSuperAdmins(db);
    if (count <= 1 && existing.isActive !== false) {
      throw new HttpsError(
          "failed-precondition",
          "No se puede cambiar el rol del último super administrador activo.",
      );
    }
  }

  if (targetUid === performedByUid && newRole !== "super_admin") {
    const count = await countActiveSuperAdmins(db);
    if (count <= 1) {
      throw new HttpsError(
          "failed-precondition",
          "No puede quitarse el rol de super administrador siendo el único.",
      );
    }
  }

  await getAuth().setCustomUserClaims(
      targetUid,
      buildClaims(newRole, profileUsername(existing)),
  );
  await userRef.set(
      {role: newRole, updatedAt: FieldValue.serverTimestamp()},
      {merge: true},
  );

  await writeAudit(db, {
    action: "user_role_changed",
    performedByUid,
    performedByUsername,
    targetUid,
    targetUsername: profileUsername(existing),
    oldValue: {role: oldRole},
    newValue: {role: newRole},
  });

  const saved = await userRef.get();
  return toCallablePayload({user: serializeUserDoc({uid: targetUid, ...saved.data()})});
});

/**
 * @param {import("firebase-functions/v2/https").CallableRequest} request
 */
const disableAppUser = onCall(callOptions, async (request) => {
  const {db, uid: performedByUid, username: performedByUsername} =
    await assertSuperAdmin(request);

  try {
    const user = await executeSetUserActive(db, getAuth(), {
      targetUid: request.data?.uid,
      performedByUid,
      performedByUsername,
    }, false);
    return toCallablePayload({user});
  } catch (error) {
    throw mapUserAdminError(error);
  }
});

/**
 * @param {import("firebase-functions/v2/https").CallableRequest} request
 */
const enableAppUser = onCall(callOptions, async (request) => {
  const {db, uid: performedByUid, username: performedByUsername} =
    await assertSuperAdmin(request);

  try {
    const user = await executeSetUserActive(db, getAuth(), {
      targetUid: request.data?.uid,
      performedByUid,
      performedByUsername,
    }, true);
    return toCallablePayload({user});
  } catch (error) {
    throw mapUserAdminError(error);
  }
});

/**
 * @param {import("firebase-functions/v2/https").CallableRequest} request
 */
const deleteAppUser = onCall(callOptions, async (request) => {
  const {db, uid: performedByUid, username: performedByUsername} =
    await assertSuperAdmin(request);

  try {
    await executeDeleteAppUser(db, getAuth(), {
      targetUid: request.data?.uid,
      performedByUid,
      performedByUsername,
    });
    return toCallablePayload({success: true});
  } catch (error) {
    throw mapUserAdminError(error);
  }
});

/**
 * @param {import("firebase-functions/v2/https").CallableRequest} request
 */
const resetAppUserPassword = onCall(callOptions, async (request) => {
  const {db, uid: performedByUid, username: performedByUsername} =
    await assertSuperAdmin(request);

  try {
    await executeResetAppUserPassword(db, getAuth(), {
      targetUid: request.data?.uid,
      newPassword: request.data?.newPassword,
      performedByUid,
      performedByUsername,
    });
    return toCallablePayload({success: true});
  } catch (error) {
    throw mapUserAdminError(error);
  }
});

/**
 * @param {import("firebase-functions/v2/https").CallableRequest} request
 */
const listAppUsers = onCall(callOptions, async (request) => {
  const {db} = await assertSuperAdmin(request);

  const search = String(request.data?.search || "").trim().toLowerCase();
  const roleFilter = request.data?.role ?
    normalizeRole(request.data.role) :
    null;
  const activeOnly = request.data?.activeOnly;
  const includeDeleted = request.data?.includeDeleted === true;

  const snap = await db.collection(`workspaces/${WORKSPACE_ID}/users`).get();
  let users = snap.docs
      .map((doc) => serializeUserDoc({uid: doc.id, ...doc.data()}));

  if (!includeDeleted) {
    users = users.filter((user) => !user.deletedAt);
  }

  if (roleFilter) {
    users = users.filter((user) => normalizeRole(user.role) === roleFilter);
  }

  if (activeOnly === true) {
    users = users.filter((user) => user.isActive !== false);
  } else if (activeOnly === false) {
    users = users.filter((user) => user.isActive === false);
  }

  if (search) {
    users = users.filter((user) => {
      const username = String(user.username || "").toLowerCase();
      const name = String(user.displayName || "").toLowerCase();
      const role = String(user.role || "").toLowerCase();
      return username.includes(search) ||
        name.includes(search) ||
        role.includes(search);
    });
  }

  users.sort((a, b) =>
    String(a.username || a.displayName || "")
        .localeCompare(String(b.username || b.displayName || "")),
  );

  return toCallablePayload({users});
});

/**
 * @param {import("firebase-functions/v2/https").CallableRequest} request
 */
const getCurrentUserProfile = onCall(callOptions, async (request) => {
  const {profile, uid} = await assertAuthenticated(request);
  return toCallablePayload({user: serializeUserDoc({uid, ...profile})});
});

/**
 * @param {import("firebase-functions/v2/https").CallableRequest} request
 */
const bootstrapFirstSuperAdmin = onCall(callOptions, async (request) => {
  const secret = bootstrapSecret.value();
  if (!secret || secret.length < 16) {
    throw new HttpsError(
        "failed-precondition",
        "Bootstrap no configurado en el servidor.",
    );
  }

  if (request.data?.secret !== secret) {
    throw new HttpsError("permission-denied", "Secreto inválido.");
  }

  const email = String(request.data?.email || "").trim().toLowerCase();
  const password = String(request.data?.password || "");
  const displayName = String(request.data?.displayName || "Super Administrador")
      .trim();

  if (!email || password.length < 8) {
    throw new HttpsError("invalid-argument", "Email y contraseña requeridos.");
  }

  const db = getFirestore();
  const auth = getAuth();

  const existingSupers = await countActiveSuperAdmins(db);
  if (existingSupers > 0) {
    throw new HttpsError(
        "already-exists",
        "Ya existe un super administrador. Bootstrap deshabilitado.",
    );
  }

  const userRecord = await auth.createUser({
    email,
    password,
    displayName,
  });

  const username = "superadmin";
  const claims = buildClaims("super_admin", username);
  await auth.setCustomUserClaims(userRecord.uid, claims);

  await db.doc(`workspaces/${WORKSPACE_ID}/users/${userRecord.uid}`).set({
    uid: userRecord.uid,
    username,
    internalEmail: null,
    realEmail: email,
    displayName,
    role: "super_admin",
    isActive: true,
    isSuperAdmin: true,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
    createdBy: "bootstrap",
    deletedAt: null,
  });

  await writeAudit(db, {
    action: "user_created",
    performedByUid: "bootstrap",
    performedByUsername: "bootstrap",
    targetUid: userRecord.uid,
    targetUsername: username,
    newValue: {role: "super_admin"},
    metadata: {source: "bootstrapFirstSuperAdmin"},
  });

  logger.warn("Bootstrap super admin creado. Deshabilite BOOTSTRAP_SUPER_ADMIN_SECRET.");

  return toCallablePayload({uid: userRecord.uid, username, realEmail: email});
});

/**
 * Procesa solicitudes de creación de usuario escritas en Firestore por el cliente.
 */
const processUserCreationRequest = onDocumentCreated({
  document: `workspaces/${WORKSPACE_ID}/user_creation_requests/{requestId}`,
  region: "us-central1",
}, async (event) => {
  const snap = event.data;
  if (!snap) return;

  const data = snap.data() || {};
  if (data.type !== "create" || data.status !== "pending") return;

  const ref = snap.ref;
  const db = getFirestore();
  const auth = getAuth();
  const requestId = event.params.requestId;
  const secretRef = db.doc(
      `workspaces/${WORKSPACE_ID}/user_creation_secrets/${requestId}`);

  await ref.set({status: "processing"}, {merge: true});

  try {
    const requesterUid = String(data.requestedByUid || "");
    const requesterSnap = await db
        .doc(`workspaces/${WORKSPACE_ID}/users/${requesterUid}`)
        .get();
    if (!requesterSnap.exists) {
      throw new Error("Perfil del solicitante no encontrado.");
    }
    const requester = requesterSnap.data() || {};
    const requesterRole = normalizeRole(requester.role);
    const isSuper = requesterRole === "super_admin" ||
      requester.isSuperAdmin === true;
    if (!isSuper) {
      throw new Error("Solo un super administrador puede crear usuarios.");
    }
    if (requester.isActive === false || requester.deletedAt) {
      throw new Error("Cuenta del solicitante desactivada.");
    }

    const secretSnap = await secretRef.get();
    const secretPassword = String(secretSnap.data()?.password || "");

    const user = await executeCreateAppUser(db, auth, {
      username: data.username,
      password: secretPassword || data.password,
      displayName: data.displayName,
      role: data.role,
      isActive: data.isActive,
      performedByUid: requesterUid,
      performedByUsername: String(
          data.requestedByUsername || profileUsername(requester),
      ),
    });

    await ref.set({
      status: "completed",
      user,
      completedAt: FieldValue.serverTimestamp(),
      errorMessage: FieldValue.delete(),
    }, {merge: true});
    await secretRef.delete().catch(() => undefined);
  } catch (error) {
    logger.error("processUserCreationRequest error", error);
    await ref.set({
      status: "failed",
      errorMessage: error.message || "No se pudo crear el usuario.",
      completedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    await secretRef.delete().catch(() => undefined);
  }
});

/**
 * Ejecuta la operación de administración según el tipo de solicitud.
 * @param {import("firebase-admin/firestore").Firestore} db
 * @param {import("firebase-admin/auth").Auth} auth
 * @param {Object} data
 * @param {string} performedByUsername
 * @return {Promise<{user?: Object}>}
 */
async function dispatchUserAdminRequest(db, auth, data, performedByUsername) {
  const base = {
    targetUid: data.uid,
    performedByUid: String(data.requestedByUid || ""),
    performedByUsername,
  };

  switch (data.type) {
    case "update":
      return {
        user: await executeUpdateAppUser(db, auth, {
          ...base,
          displayName: data.displayName ?? undefined,
          role: data.role ?? undefined,
          isActive: data.isActive ?? undefined,
        }),
      };
    case "disable":
      return {user: await executeSetUserActive(db, auth, base, false)};
    case "enable":
      return {user: await executeSetUserActive(db, auth, base, true)};
    case "delete":
      return {user: await executeDeleteAppUser(db, auth, base)};
    case "resetPassword":
      await executeResetAppUserPassword(db, auth, {
        ...base,
        newPassword: data.newPassword,
      });
      return {};
    default:
      throw new Error(`Tipo de solicitud no soportado: ${data.type}`);
  }
}

/**
 * Procesa solicitudes de administración de usuarios (editar, activar,
 * desactivar, eliminar, resetear contraseña) escritas en Firestore por el
 * cliente. Las contraseñas de reset se leen desde user_admin_secrets.
 * Evita el fallo CORS de llamar callables desde el navegador.
 */
const processUserAdminRequest = onDocumentCreated({
  document: `workspaces/${WORKSPACE_ID}/user_admin_requests/{requestId}`,
  region: "us-central1",
}, async (event) => {
  const snap = event.data;
  if (!snap) return;

  const data = snap.data() || {};
  if (data.status !== "pending") return;

  const ref = snap.ref;
  const db = getFirestore();
  const auth = getAuth();
  const requestId = event.params.requestId;
  const secretRef = db.doc(
      `workspaces/${WORKSPACE_ID}/user_admin_secrets/${requestId}`);

  await ref.set({status: "processing"}, {merge: true});

  try {
    const requesterUid = String(data.requestedByUid || "");
    const {username} = await assertRequesterIsSuperAdmin(db, requesterUid);
    const performedByUsername = String(data.requestedByUsername || username);

    const payload = {...data};
    if (payload.type === "resetPassword") {
      const secretSnap = await secretRef.get();
      payload.newPassword = String(secretSnap.data()?.newPassword || "");
    }

    const result = await dispatchUserAdminRequest(
        db, auth, payload, performedByUsername,
    );

    await ref.set({
      status: "completed",
      ...(result.user ? {user: result.user} : {success: true}),
      completedAt: FieldValue.serverTimestamp(),
      errorMessage: FieldValue.delete(),
    }, {merge: true});
    await secretRef.delete().catch(() => undefined);
  } catch (error) {
    logger.error("processUserAdminRequest error", error);
    await ref.set({
      status: "failed",
      errorMessage: error.message || "No se pudo completar la operación.",
      completedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    await secretRef.delete().catch(() => undefined);
  }
});

// Exportaciones con nombres nuevos
exports.createAppUser = createAppUser;
exports.updateAppUser = updateAppUser;
exports.changeUserRole = changeUserRole;
exports.disableAppUser = disableAppUser;
exports.enableAppUser = enableAppUser;
exports.deleteAppUser = deleteAppUser;
exports.resetAppUserPassword = resetAppUserPassword;
exports.listAppUsers = listAppUsers;
exports.getCurrentUserProfile = getCurrentUserProfile;
exports.bootstrapFirstSuperAdmin = bootstrapFirstSuperAdmin;
exports.processUserCreationRequest = processUserCreationRequest;
exports.processUserAdminRequest = processUserAdminRequest;

// Alias legacy (compatibilidad con clientes anteriores)
exports.createUserBySuperAdmin = createAppUser;
exports.updateUserBySuperAdmin = updateAppUser;
exports.updateUserRoleBySuperAdmin = changeUserRole;
exports.disableUserBySuperAdmin = disableAppUser;
exports.enableUserBySuperAdmin = enableAppUser;
exports.deleteUserBySuperAdmin = deleteAppUser;
exports.listUsersBySuperAdmin = listAppUsers;
