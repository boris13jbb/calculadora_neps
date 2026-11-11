'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const {
  validateSeedEmulatorClaimEnv,
  isLocalEmulatorHost,
} = require('../scripts/seed_emulator_admin_claim');

const safeEnv = {
  FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:9099',
  FIRESTORE_EMULATOR_HOST: '127.0.0.1:8085',
  GCLOUD_PROJECT: 'demo-vicunha-sync-test',
};

describe('seed_emulator_admin_claim isolation', () => {
  it('acepta entorno demo + emuladores locales', () => {
    const result = validateSeedEmulatorClaimEnv(safeEnv, 'uid-test');
    assert.equal(result.ok, true);
    assert.equal(result.projectId, 'demo-vicunha-sync-test');
    assert.equal(result.uid, 'uid-test');
  });

  it('rechaza sin uid', () => {
    const result = validateSeedEmulatorClaimEnv(safeEnv, '');
    assert.equal(result.ok, false);
  });

  it('rechaza sin FIREBASE_AUTH_EMULATOR_HOST', () => {
    const env = { ...safeEnv };
    delete env.FIREBASE_AUTH_EMULATOR_HOST;
    const result = validateSeedEmulatorClaimEnv(env, 'uid-test');
    assert.equal(result.ok, false);
    assert.match(result.error, /FIREBASE_AUTH_EMULATOR_HOST/);
  });

  it('rechaza sin FIRESTORE_EMULATOR_HOST', () => {
    const env = { ...safeEnv };
    delete env.FIRESTORE_EMULATOR_HOST;
    const result = validateSeedEmulatorClaimEnv(env, 'uid-test');
    assert.equal(result.ok, false);
    assert.match(result.error, /FIRESTORE_EMULATOR_HOST/);
  });

  it('rechaza proyecto productivo', () => {
    const result = validateSeedEmulatorClaimEnv(
      { ...safeEnv, GCLOUD_PROJECT: 'vicunha-calculadora-neps' },
      'uid-test',
    );
    assert.equal(result.ok, false);
    assert.match(result.error, /productivo|rechazado/i);
  });

  it('rechaza project id no autorizado', () => {
    const result = validateSeedEmulatorClaimEnv(
      { ...safeEnv, GCLOUD_PROJECT: 'otro-proyecto' },
      'uid-test',
    );
    assert.equal(result.ok, false);
  });

  it('con emuladores demo acepta entorno aunque exista GAC (se eliminará en main)', () => {
    const result = validateSeedEmulatorClaimEnv(
      {
        ...safeEnv,
        GOOGLE_APPLICATION_CREDENTIALS: 'C:\\secrets\\sa.json',
      },
      'uid-test',
    );
    assert.equal(result.ok, true);
    assert.equal(result.hadGoogleApplicationCredentials, true);
  });

  it('sin emulador Auth sigue rechazando aunque haya GAC', () => {
    const env = {
      ...safeEnv,
      GOOGLE_APPLICATION_CREDENTIALS: 'C:\\secrets\\sa.json',
    };
    delete env.FIREBASE_AUTH_EMULATOR_HOST;
    const result = validateSeedEmulatorClaimEnv(env, 'uid-test');
    assert.equal(result.ok, false);
  });

  it('rechaza host Auth remoto', () => {
    const result = validateSeedEmulatorClaimEnv(
      { ...safeEnv, FIREBASE_AUTH_EMULATOR_HOST: 'auth.example.com:9099' },
      'uid-test',
    );
    assert.equal(result.ok, false);
  });

  it('isLocalEmulatorHost solo acepta loopback', () => {
    assert.equal(isLocalEmulatorHost('127.0.0.1:9099'), true);
    assert.equal(isLocalEmulatorHost('localhost:8085'), true);
    assert.equal(isLocalEmulatorHost('10.0.0.5:9099'), false);
  });
});
