const test = require("node:test");
const assert = require("node:assert/strict");
const {
  resolveAlertRecipientRoleCodes,
  isEligibleAlertRecipient,
  collectUniqueFcmTokens,
} = require("../alert_recipients");

function user(overrides = {}) {
  return {
    role: "supervisor",
    isActive: true,
    deletedAt: null,
    fcmToken: "token-a",
    ...overrides,
  };
}

function eligible(roleDocs, candidate, extraUsers = []) {
  const resolved = resolveAlertRecipientRoleCodes(roleDocs);
  const roleByCode = new Map();
  for (const doc of roleDocs) {
    roleByCode.set(doc.id || doc.code, doc);
    if (doc.code) roleByCode.set(doc.code, doc);
  }
  const tokens = collectUniqueFcmTokens(
      [candidate, ...extraUsers],
      resolved.codes,
      roleByCode,
  );
  return {
    receives: isEligibleAlertRecipient(candidate, resolved.codes, roleByCode),
    tokens,
  };
}

test("custom role con viewAlerts recibe", () => {
  const result = eligible(
      [{
        id: "jefe_calidad",
        code: "jefe_calidad",
        isActive: true,
        permissions: ["viewAlerts", "viewRecords"],
      }],
      user({role: "jefe_calidad", fcmToken: "tok-jefe"}),
  );
  assert.equal(result.receives, true);
  assert.deepEqual(result.tokens, ["tok-jefe"]);
});

test("custom role sin viewAlerts no recibe", () => {
  const result = eligible(
      [{
        id: "auditor",
        code: "auditor",
        isActive: true,
        permissions: ["viewRecords", "exportReports"],
      }],
      user({role: "auditor", fcmToken: "tok-aud"}),
  );
  assert.equal(result.receives, false);
  assert.deepEqual(result.tokens, []);
});

test("custom role inactivo no recibe", () => {
  const result = eligible(
      [{
        id: "jefe_calidad",
        code: "jefe_calidad",
        isActive: false,
        permissions: ["viewAlerts"],
      }],
      user({role: "jefe_calidad", fcmToken: "tok-jefe"}),
  );
  assert.equal(result.receives, false);
});

test("supervisor con RoleDefinition sin viewAlerts no recibe", () => {
  const result = eligible(
      [{
        id: "supervisor",
        code: "supervisor",
        isActive: true,
        permissions: ["viewRecords", "viewWorkspaceRecords"],
      }],
      user({role: "supervisor", fcmToken: "tok-sup"}),
  );
  assert.equal(result.receives, false);
});

test("supervisor con RoleDefinition inactivo no recibe", () => {
  const result = eligible(
      [{
        id: "supervisor",
        code: "supervisor",
        isActive: false,
        permissions: ["viewAlerts", "viewRecords"],
      }],
      user({role: "SUPERVISOR", fcmToken: "tok-sup"}),
  );
  assert.equal(result.receives, false);
});

test("sin roles sembrados usa fallback legacy", () => {
  const resolved = resolveAlertRecipientRoleCodes([]);
  assert.equal(resolved.seeded, false);
  assert.equal(
      isEligibleAlertRecipient(user({role: "supervisor"}), resolved.codes),
      true,
  );
  assert.equal(
      isEligibleAlertRecipient(user({role: "ADMINISTRADOR"}), resolved.codes),
      true,
  );
  assert.equal(
      isEligibleAlertRecipient(user({role: "operario"}), resolved.codes),
      false,
  );
  assert.equal(
      isEligibleAlertRecipient(user({role: "jefe_calidad"}), resolved.codes),
      false,
  );
});

test("super_admin recibe con documento activo y viewAlerts", () => {
  const result = eligible(
      [{
        id: "super_admin",
        code: "super_admin",
        isActive: true,
        permissions: ["viewAlerts", "manageUsers"],
      }],
      user({role: "super_admin", fcmToken: "tok-sa"}),
  );
  assert.equal(result.receives, true);
});

test("usuario inactivo no recibe", () => {
  const result = eligible(
      [{
        id: "supervisor",
        code: "supervisor",
        isActive: true,
        permissions: ["viewAlerts"],
      }],
      user({isActive: false, fcmToken: "tok-sup"}),
  );
  assert.equal(result.receives, false);
});

test("usuario eliminado no recibe", () => {
  const result = eligible(
      [{
        id: "supervisor",
        code: "supervisor",
        isActive: true,
        permissions: ["viewAlerts"],
      }],
      user({deletedAt: "2026-01-01T00:00:00.000Z", fcmToken: "tok-sup"}),
  );
  assert.equal(result.receives, false);
});

test("token vacío no recibe", () => {
  const result = eligible(
      [{
        id: "admin",
        code: "admin",
        isActive: true,
        permissions: ["viewAlerts"],
      }],
      user({role: "admin", fcmToken: "   "}),
  );
  assert.equal(result.receives, false);
});

test("token duplicado genera una sola notificación", () => {
  const roleDocs = [{
    id: "supervisor",
    code: "supervisor",
    isActive: true,
    permissions: ["viewAlerts"],
  }];
  const result = eligible(
      roleDocs,
      user({fcmToken: "mismo-token"}),
      [user({role: "supervisor", fcmToken: "mismo-token"})],
  );
  assert.deepEqual(result.tokens, ["mismo-token"]);
});
