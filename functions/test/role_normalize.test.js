const test = require("node:test");
const assert = require("node:assert/strict");

/**
 * Copia ligera de la lógica de normalización / asignación para unit test
 * sin inicializar Firebase Admin.
 */
const LEGACY_ROLE_MAP = {
  ADMINISTRADOR: "admin",
  SUPERVISOR: "supervisor",
  OPERARIO: "operario",
  GERENCIA: "gerencia",
};

function normalizeRole(raw) {
  if (!raw || typeof raw !== "string") return "";
  const trimmed = raw.trim();
  if (!trimmed) return "";
  if (LEGACY_ROLE_MAP[trimmed.toUpperCase()]) {
    return LEGACY_ROLE_MAP[trimmed.toUpperCase()];
  }
  return trimmed.toLowerCase();
}

test("normalizeRole no convierte códigos personalizados a operario", () => {
  assert.equal(normalizeRole("auditor"), "auditor");
  assert.equal(normalizeRole("jefe_turno"), "jefe_turno");
  assert.equal(normalizeRole("ADMINISTRADOR"), "admin");
  assert.equal(normalizeRole(""), "");
});

test("códigos de rol inválidos para patrón UI", () => {
  const pattern = /^[a-z][a-z0-9_]*$/;
  assert.equal(pattern.test("jefe_turno"), true);
  assert.equal(pattern.test("Jefe Turno"), false);
  assert.equal(pattern.test("super_admin"), true);
});
