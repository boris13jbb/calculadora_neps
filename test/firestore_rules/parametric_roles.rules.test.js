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

function tombstonePath(recordId) {
  return `${WS}/record_tombstones/${recordId}`;
}

function workspaceRecordPath(recordId) {
  return `${WS}/records/${recordId}`;
}

// --- K) Tombstones delete-wins ---
test("K1) admin con deleteRecords puede crear tombstone", async () => {
  await seedAdmin(async (db) => {
    await setDoc(doc(db, rolePath("admin")), baseRoleDoc("admin", [
      "viewRecords",
      "viewWorkspaceRecords",
      "deleteRecords",
      "captureRecords",
    ]));
  });

  const db = authed("admin1", "admin");
  await assertSucceeds(setDoc(doc(db, tombstonePath("rec-k1")), {
    recordId: "rec-k1",
    ownerUid: "op1",
    deletedByUid: "admin1",
    deletedAt: new Date(),
  }));
});

test("K2) sin deleteRecords no puede crear tombstone", async () => {
  await seedAdmin(async (db) => {
    await setDoc(doc(db, rolePath("operario")), baseRoleDoc("operario", [
      "viewRecords",
      "captureRecords",
    ], {seesWorkspaceRecords: false}));
  });

  const db = authed("op1", "operario");
  await assertFails(setDoc(doc(db, tombstonePath("rec-k2")), {
    recordId: "rec-k2",
    ownerUid: "op1",
    deletedByUid: "op1",
    deletedAt: new Date(),
  }));
});

test("K3) tombstone bloquea recreate workspace y user mirror", async () => {
  await seedAdmin(async (db) => {
    await setDoc(doc(db, rolePath("operario")), baseRoleDoc("operario", [
      "viewRecords",
      "captureRecords",
    ], {seesWorkspaceRecords: false}));
    await setDoc(doc(db, tombstonePath("rec-dead")), {
      recordId: "rec-dead",
      ownerUid: "op1",
      deletedByUid: "admin1",
      deletedAt: new Date(),
    });
  });

  const db = authed("op1", "operario");
  const payload = {
    ownerUid: "op1",
    createdByUid: "op1",
    captureSessionId: "ses-1",
    telar: "1",
    neps: 1,
  };
  await assertFails(setDoc(doc(db, workspaceRecordPath("rec-dead")), payload));
  await assertFails(setDoc(doc(db, userRecordPath("op1", "rec-dead")), payload));
});

test("K4) sin tombstone create normal sigue permitido", async () => {
  await seedAdmin(async (db) => {
    await setDoc(doc(db, rolePath("operario")), baseRoleDoc("operario", [
      "viewRecords",
      "captureRecords",
    ], {seesWorkspaceRecords: false}));
  });

  const db = authed("op1", "operario");
  const payload = {
    ownerUid: "op1",
    createdByUid: "op1",
    captureSessionId: "ses-1",
    telar: "1",
    neps: 1,
  };
  await assertSucceeds(setDoc(doc(db, workspaceRecordPath("rec-live")), payload));
  await assertSucceeds(setDoc(doc(db, userRecordPath("op1", "rec-live")), payload));
});

test("K5) cliente no puede borrar tombstone; lectura autenticada OK", async () => {
  await seedAdmin(async (db) => {
    await setDoc(doc(db, rolePath("admin")), baseRoleDoc("admin", [
      "viewRecords",
      "viewWorkspaceRecords",
      "deleteRecords",
    ]));
    await setDoc(doc(db, tombstonePath("rec-k5")), {
      recordId: "rec-k5",
      ownerUid: "op1",
      deletedByUid: "admin1",
      deletedAt: new Date(),
    });
  });

  const db = authed("admin1", "admin");
  await assertSucceeds(getDoc(doc(db, tombstonePath("rec-k5"))));
  await assertFails(deleteDoc(doc(db, tombstonePath("rec-k5"))));
});

test("K6) registro+tombstone: UPDATE workspace mirror DENY", async () => {
  await seedAdmin(async (db) => {
    await setDoc(doc(db, rolePath("admin")), baseRoleDoc("admin", [
      "viewRecords",
      "viewWorkspaceRecords",
      "editRecords",
      "deleteRecords",
      "captureRecords",
    ]));
    // Estado inconsistente: documento vivo + tombstone (seed bypass).
    await setDoc(doc(db, workspaceRecordPath("rec-k6")), {
      ownerUid: "op1",
      createdByUid: "op1",
      captureSessionId: "ses-k6",
      telar: "1",
      neps: 5,
    });
    await setDoc(doc(db, tombstonePath("rec-k6")), {
      recordId: "rec-k6",
      ownerUid: "op1",
      deletedByUid: "admin1",
      deletedAt: new Date(),
    });
  });

  const db = authed("admin1", "admin");
  await assertFails(updateDoc(doc(db, workspaceRecordPath("rec-k6")), {
    neps: 99,
  }));
});

test("K7) registro+tombstone: UPDATE user mirror DENY", async () => {
  await seedAdmin(async (db) => {
    await setDoc(doc(db, rolePath("admin")), baseRoleDoc("admin", [
      "viewRecords",
      "viewWorkspaceRecords",
      "editRecords",
      "deleteRecords",
      "captureRecords",
    ]));
    await setDoc(doc(db, userRecordPath("op1", "rec-k7")), {
      ownerUid: "op1",
      createdByUid: "op1",
      captureSessionId: "ses-k7",
      telar: "1",
      neps: 5,
    });
    await setDoc(doc(db, tombstonePath("rec-k7")), {
      recordId: "rec-k7",
      ownerUid: "op1",
      deletedByUid: "admin1",
      deletedAt: new Date(),
    });
  });

  const db = authed("admin1", "admin");
  await assertFails(updateDoc(doc(db, userRecordPath("op1", "rec-k7")), {
    neps: 99,
  }));
});

// Sanity: assert helper used
test("sanity assert", () => {
  assert.equal(typeof collection, "function");
  assert.equal(typeof addDoc, "function");
});
