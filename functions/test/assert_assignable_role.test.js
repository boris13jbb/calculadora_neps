const test = require("node:test");
const assert = require("node:assert/strict");

/**
 * Lógica de decisión de assertAssignableRole (espejo de admin_users.js)
 * para validar sin inicializar Admin SDK.
 */
const BASE_ROLES = new Set([
  "super_admin", "admin", "supervisor", "operario", "gerencia",
]);

/**
 * @param {string} code
 * @param {object|null} roleData null = doc inexistente
 * @param {{allowSuperAdmin?: boolean}} opts
 * @return {{ok: boolean, error?: string}}
 */
function evaluateAssignable(code, roleData, opts = {}) {
  const allowSuperAdmin = opts.allowSuperAdmin === true;
  if (!code) return {ok: false, error: "required"};
  if (code === "super_admin" && !allowSuperAdmin) {
    return {ok: false, error: "super_admin_panel"};
  }
  if (roleData === null || roleData === undefined) {
    if (BASE_ROLES.has(code) && code !== "super_admin") return {ok: true};
    if (code === "super_admin" && allowSuperAdmin) return {ok: true};
    return {ok: false, error: "not_found"};
  }
  if (roleData.isActive === false) return {ok: false, error: "inactive"};
  if (roleData.isAssignable === false && code !== "super_admin") {
    return {ok: false, error: "not_assignable"};
  }
  if (code === "super_admin" && !allowSuperAdmin) {
    return {ok: false, error: "super_admin_panel"};
  }
  return {ok: true};
}

/**
 * Política deleteRole (espejo).
 * @param {string} code
 * @param {object|null} roleData
 * @param {boolean} hasUsers
 */
function evaluateDeleteRole(code, roleData, hasUsers) {
  const system = new Set([
    "super_admin", "admin", "supervisor", "operario", "gerencia",
  ]);
  if (!code) return {ok: false, error: "required"};
  if (system.has(code)) return {ok: false, error: "system_code"};
  if (!roleData) return {ok: false, error: "not_found"};
  if (roleData.isSystem === true) return {ok: false, error: "system_flag"};
  if (hasUsers) return {ok: false, error: "has_users"};
  return {ok: true};
}

test("assertAssignable: rol inexistente custom → rechazado", () => {
  assert.equal(evaluateAssignable("auditor", null).ok, false);
});

test("assertAssignable: rol base sin seed → aceptado (migración)", () => {
  assert.equal(evaluateAssignable("supervisor", null).ok, true);
  assert.equal(evaluateAssignable("operario", null).ok, true);
});

test("assertAssignable: rol inactivo → rechazado", () => {
  assert.equal(
      evaluateAssignable("auditor", {
        isActive: false,
        isAssignable: true,
      }).error,
      "inactive",
  );
});

test("assertAssignable: isAssignable false → rechazado", () => {
  assert.equal(
      evaluateAssignable("locked", {
        isActive: true,
        isAssignable: false,
      }).error,
      "not_assignable",
  );
});

test("assertAssignable: super_admin desde panel → rechazado", () => {
  assert.equal(
      evaluateAssignable("super_admin", {
        isActive: true,
        isAssignable: false,
      }).error,
      "super_admin_panel",
  );
});

test("assertAssignable: custom válido → aceptado", () => {
  assert.equal(
      evaluateAssignable("auditor", {
        isActive: true,
        isAssignable: true,
      }).ok,
      true,
  );
});

test("assertAssignable: con RoleDefinition base, el doc manda", () => {
  assert.equal(
      evaluateAssignable("supervisor", {
        isActive: false,
        isAssignable: true,
      }).error,
      "inactive",
  );
});

test("deleteRole: system / usuarios / ok", () => {
  assert.equal(evaluateDeleteRole("admin", {isSystem: true}, false).ok, false);
  assert.equal(
      evaluateDeleteRole("auditor", {isSystem: false}, true).error,
      "has_users",
  );
  assert.equal(
      evaluateDeleteRole("auditor", {isSystem: false}, false).ok,
      true,
  );
});
