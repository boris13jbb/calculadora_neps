/**
 * Pruebas reales de firestore.rules con Firebase Emulator
 * (vía @firebase/rules-unit-testing). Sin deploy.
 */
const {readFileSync} = require("node:fs");
const {resolve} = require("node:path");
const test = require("node:test");
const assert = require("node:assert/strict");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  collection,
  addDoc,
} = require("firebase/firestore");

const PROJECT_ID = "vicunha-rules-test";
const RULES_PATH = resolve(__dirname, "../../firestore.rules");

/** @type {import("@firebase/rules-unit-testing").RulesTestEnvironment} */
let testEnv;

const WS = "workspaces/vicunha";

function rolePath(code) {
  return `${WS}/roles/${code}`;
}

function userRecordPath(uid, recordId) {
  return `${WS}/users/${uid}/records/${recordId}`;
}

function baseRoleDoc(code, permissions, extras = {}) {
  return {
    code,
    name: code,
    permissions,
    isActive: true,
    isSystem: true,
    isAssignable: code !== "super_admin",
    sortOrder: 10,
    seesWorkspaceRecords: permissions.includes("viewWorkspaceRecords"),
    ...extras,
  };
}

async function seedAdmin(fn) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await fn(db);
  });
}

function authed(uid, role, claims = {}) {
  return testEnv.authenticatedContext(uid, {role, ...claims}).firestore();
}

test.before(async () => {
  // Con `firebase emulators:exec`, FIRESTORE_EMULATOR_HOST ya está definido.
  const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8085";
  const [host, portRaw] = emulatorHost.split(":");
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync(RULES_PATH, "utf8"),
      host,
      port: Number(portRaw || 8085),
    },
  });
});

test.after(async () => {
  if (testEnv) await testEnv.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
});

// --- A) Operario ---
test("A) operario: lee propios, no ajenos; captura sí; edita no", async () => {
  await seedAdmin(async (db) => {
    await setDoc(doc(db, rolePath("operario")), baseRoleDoc("operario", [
      "captureRecords",
      "viewRecords",
    ]));
    await setDoc(doc(db, userRecordPath("op1", "r1")), {
      ownerUid: "op1",
      neps: 1,
    });
    await setDoc(doc(db, userRecordPath("other", "r2")), {
      ownerUid: "other",
      neps: 2,
    });
  });

  const db = authed("op1", "operario");
  await assertSucceeds(getDoc(doc(db, userRecordPath("op1", "r1"))));
  await assertFails(getDoc(doc(db, userRecordPath("other", "r2"))));
  await assertSucceeds(
      setDoc(doc(db, userRecordPath("op1", "r3")), {
        ownerUid: "op1",
        createdByUid: "op1",
        neps: 3,
      }),
  );
  await assertFails(
      updateDoc(doc(db, userRecordPath("op1", "r1")), {neps: 99}),
  );
});

// --- B) Auditor personalizado ---
test("B) auditor: lee workspace; no crea/edita/borra", async () => {
  await seedAdmin(async (db) => {
    await setDoc(doc(db, rolePath("auditor")), {
      code: "auditor",
      name: "Auditor",
      permissions: [
        "viewRecords",
        "viewWorkspaceRecords",
        "exportReports",
      ],
      isActive: true,
      isSystem: false,
      isAssignable: true,
      sortOrder: 60,
    });
    await setDoc(doc(db, userRecordPath("op1", "r1")), {
      ownerUid: "op1",
      neps: 1,
    });
  });

  const db = authed("aud1", "auditor");
  await assertSucceeds(getDoc(doc(db, userRecordPath("op1", "r1"))));
  await assertFails(
      setDoc(doc(db, userRecordPath("aud1", "r2")), {
        ownerUid: "aud1",
        createdByUid: "aud1",
        neps: 1,
      }),
  );
  await assertFails(
      updateDoc(doc(db, userRecordPath("op1", "r1")), {neps: 2}),
  );
  await assertFails(deleteDoc(doc(db, userRecordPath("op1", "r1"))));
});

// --- C) Rol sin permisos ---
test("C) rol personalizado sin permisos: deny lectura/escritura", async () => {
  await seedAdmin(async (db) => {
    await setDoc(doc(db, rolePath("vacio")), {
      code: "vacio",
      name: "Vacío",
      permissions: [],
      isActive: true,
      isSystem: false,
      isAssignable: true,
    });
    await setDoc(doc(db, userRecordPath("u1", "r1")), {
      ownerUid: "u1",
      neps: 1,
    });
  });

  const db = authed("u1", "vacio");
  await assertFails(getDoc(doc(db, userRecordPath("u1", "r1"))));
  await assertFails(
      setDoc(doc(db, userRecordPath("u1", "r2")), {
        ownerUid: "u1",
        createdByUid: "u1",
        neps: 1,
      }),
  );
});

// --- D) Rol inactivo ---
test("D) rol inactivo: pierde privilegios aunque roleCode siga", async () => {
  await seedAdmin(async (db) => {
    await setDoc(doc(db, rolePath("supervisor")), baseRoleDoc("supervisor", [
      "viewRecords",
      "viewWorkspaceRecords",
      "editRecords",
    ], {isActive: false}));
    await setDoc(doc(db, userRecordPath("op1", "r1")), {
      ownerUid: "op1",
      neps: 1,
    });
  });

  const db = authed("sup1", "supervisor");
  await assertFails(getDoc(doc(db, userRecordPath("op1", "r1"))));
  await assertFails(
      updateDoc(doc(db, userRecordPath("op1", "r1")), {neps: 5}),
  );
});

// --- E) Supervisor con RoleDefinition modificado ---
test("E) supervisor sin editRecords en RoleDefinition: no edita", async () => {
  await seedAdmin(async (db) => {
    await setDoc(doc(db, rolePath("supervisor")), baseRoleDoc("supervisor", [
      "viewRecords",
      "viewWorkspaceRecords",
      "viewAlerts",
      // sin editRecords
    ]));
    await setDoc(doc(db, userRecordPath("op1", "r1")), {
      ownerUid: "op1",
      neps: 1,
    });
  });

  const db = authed("sup1", "supervisor");
  await assertSucceeds(getDoc(doc(db, userRecordPath("op1", "r1"))));
  await assertFails(
      updateDoc(doc(db, userRecordPath("op1", "r1")), {neps: 7}),
  );
});

// --- F) Supervisor doc inactivo: NO legacy ---
test("F) supervisor inactivo no usa bypass legacy", async () => {
  await seedAdmin(async (db) => {
    await setDoc(doc(db, rolePath("supervisor")), baseRoleDoc("supervisor", [
      "viewRecords",
      "viewWorkspaceRecords",
      "editRecords",
    ], {isActive: false}));
    await setDoc(doc(db, userRecordPath("x", "r1")), {
      ownerUid: "x",
      neps: 1,
    });
  });

  const db = authed("sup1", "supervisor");
  await assertFails(getDoc(doc(db, userRecordPath("x", "r1"))));
});

// --- G) Legacy sin role doc ---
test("G) legacy: operario base sin doc de rol sigue funcionando", async () => {
  await seedAdmin(async (db) => {
    // Sin roles/* — solo un registro propio.
    await setDoc(doc(db, userRecordPath("op1", "r1")), {
      ownerUid: "op1",
      neps: 1,
    });
    await setDoc(doc(db, userRecordPath("other", "r2")), {
      ownerUid: "other",
      neps: 2,
    });
  });

  const db = authed("op1", "operario");
  await assertSucceeds(getDoc(doc(db, userRecordPath("op1", "r1"))));
  await assertFails(getDoc(doc(db, userRecordPath("other", "r2"))));
  await assertSucceeds(
      setDoc(doc(db, userRecordPath("op1", "r3")), {
        ownerUid: "op1",
        createdByUid: "op1",
        neps: 3,
      }),
  );
});

test("G2) legacy: supervisor sin doc puede leer workspace", async () => {
  await seedAdmin(async (db) => {
    await setDoc(doc(db, userRecordPath("op1", "r1")), {
      ownerUid: "op1",
      neps: 1,
    });
  });

  const db = authed("sup1", "supervisor");
  await assertSucceeds(getDoc(doc(db, userRecordPath("op1", "r1"))));
});

// --- H) Super admin ---
test("H) super_admin mantiene acceso administrativo", async () => {
  await seedAdmin(async (db) => {
    await setDoc(doc(db, rolePath("super_admin")), baseRoleDoc("super_admin", [
      "manageUsers",
      "changeRoles",
      "viewRecords",
      "viewWorkspaceRecords",
    ], {isAssignable: false}));
    await setDoc(doc(db, userRecordPath("op1", "r1")), {
      ownerUid: "op1",
      neps: 1,
    });
  });

  const db = authed("sa1", "super_admin", {isSuperAdmin: true});
  await assertSucceeds(getDoc(doc(db, userRecordPath("op1", "r1"))));
  await assertSucceeds(
      setDoc(doc(db, rolePath("auditor")), {
        code: "auditor",
        name: "Auditor",
        permissions: ["viewRecords"],
        isActive: true,
        isSystem: false,
        isAssignable: true,
      }),
  );
});

// --- I) Custom no administra roles ---
test("I) rol personalizado no puede crear/modificar roles", async () => {
  await seedAdmin(async (db) => {
    await setDoc(doc(db, rolePath("auditor")), {
      code: "auditor",
      name: "Auditor",
      permissions: ["viewRecords", "viewWorkspaceRecords", "exportReports"],
      isActive: true,
      isSystem: false,
      isAssignable: true,
    });
  });

  const db = authed("aud1", "auditor");
  await assertFails(
      setDoc(doc(db, rolePath("otro")), {
        code: "otro",
        name: "Otro",
        permissions: [],
        isActive: true,
        isSystem: false,
        isAssignable: true,
      }),
  );
  await assertFails(
      updateDoc(doc(db, rolePath("auditor")), {
        permissions: ["manageUsers"],
      }),
  );
});

// --- J) isSystem inmutable a false ---
test("J) isSystem no puede cambiarse a false por cliente", async () => {
  await seedAdmin(async (db) => {
    await setDoc(doc(db, rolePath("admin")), baseRoleDoc("admin", [
      "viewRecords",
      "viewWorkspaceRecords",
      "manageSettings",
    ]));
  });

  const db = authed("sa1", "super_admin", {isSuperAdmin: true});
  await assertFails(
      updateDoc(doc(db, rolePath("admin")), {
        code: "admin",
        isSystem: false,
        isActive: true,
        isAssignable: true,
        permissions: ["viewRecords"],
      }),
  );
});

test("J2) delete de /roles denegado al cliente", async () => {
  await seedAdmin(async (db) => {
    await setDoc(doc(db, rolePath("auditor")), {
      code: "auditor",
      name: "Auditor",
      permissions: ["viewRecords"],
      isActive: true,
      isSystem: false,
      isAssignable: true,
    });
  });

  const db = authed("sa1", "super_admin", {isSuperAdmin: true});
  await assertFails(deleteDoc(doc(db, rolePath("auditor"))));
});

// Sanity: assert helper used
test("sanity assert", () => {
  assert.equal(typeof collection, "function");
  assert.equal(typeof addDoc, "function");
});
