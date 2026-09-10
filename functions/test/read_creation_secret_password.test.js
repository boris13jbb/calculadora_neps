/**
 * Regresión: lectura del secreto de creación con reintentos acotados.
 * Ejecutar: node --test test/read_creation_secret_password.test.js
 */
const {describe, it} = require("node:test");
const assert = require("node:assert/strict");
const {readCreationSecretPassword} = require("../read_creation_secret_password");

/**
 * @param {Array<{exists: boolean, password?: string}>} responses
 * @return {{get: () => Promise<{exists: boolean, data: () => Object}>}}
 */
function fakeSecretRef(responses) {
  let index = 0;
  return {
    async get() {
      const next = responses[Math.min(index, responses.length - 1)];
      index += 1;
      return {
        exists: next.exists,
        data: () => (next.exists ? {password: next.password} : undefined),
      };
    },
  };
}

describe("readCreationSecretPassword", () => {
  it("devuelve la contraseña cuando el secreto ya existe (batch atómico)", async () => {
    const ref = fakeSecretRef([{exists: true, password: "Prueba123!"}]);
    const password = await readCreationSecretPassword(ref, {
      attempts: 3,
      delayMs: 1,
    });
    assert.equal(password, "Prueba123!");
  });

  it("reintenta si el secreto llega tarde (cliente antiguo)", async () => {
    const ref = fakeSecretRef([
      {exists: false},
      {exists: false},
      {exists: true, password: "Prueba123!"},
    ]);
    const password = await readCreationSecretPassword(ref, {
      attempts: 5,
      delayMs: 5,
    });
    assert.equal(password, "Prueba123!");
  });

  it("error explícito si el secreto nunca aparece", async () => {
    const ref = fakeSecretRef([
      {exists: false},
      {exists: false},
      {exists: false},
    ]);
    await assert.rejects(
        () => readCreationSecretPassword(ref, {attempts: 3, delayMs: 1}),
        (error) => {
          assert.match(
              error.message,
              /No se recibió la contraseña temporal/,
          );
          assert.doesNotMatch(error.message, /8 caracteres/);
          return true;
        },
    );
  });

  it("contraseña corta existente sigue siendo rechazada", async () => {
    const ref = fakeSecretRef([{exists: true, password: "corta"}]);
    await assert.rejects(
        () => readCreationSecretPassword(ref, {attempts: 2, delayMs: 1}),
        (error) => {
          assert.match(error.message, /8 caracteres/);
          return true;
        },
    );
  });
});
