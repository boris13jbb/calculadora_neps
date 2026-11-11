/**
 * Asigna claim role=admin a un UID SOLO en Authentication Emulator.
 *
 * Uso:
 *   FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
 *   FIRESTORE_EMULATOR_HOST=127.0.0.1:8085 \
 *   GCLOUD_PROJECT=demo-vicunha-sync-test \
 *   node scripts/seed_emulator_admin_claim.js <uid>
 *
 * Seguridad:
 * - Rechaza proyectos productivos.
 * - Exige variables de emulador (sin defaults silenciosos a producción).
 * - Verifica endpoint Auth local antes de mutar claims.
 * - No usa service accounts reales ni registra tokens.
 */
'use strict';

const http = require('http');
const admin = require('firebase-admin');

const ALLOWED_PROJECT_IDS = new Set(['demo-vicunha-sync-test']);
const BLOCKED_PROJECT_IDS = new Set(['vicunha-calculadora-neps']);

/**
 * Valida entorno. Exportado para pruebas unitarias.
 * @param {NodeJS.ProcessEnv} env
 * @param {string|undefined} uid
 * @returns {{ ok: true, uid: string, projectId: string, authHost: string } | { ok: false, error: string }}
 */
function validateSeedEmulatorClaimEnv(env, uid) {
  const trimmedUid = typeof uid === 'string' ? uid.trim() : '';
  if (!trimmedUid) {
    return { ok: false, error: 'Uso: node scripts/seed_emulator_admin_claim.js <uid>' };
  }

  const authHost = (env.FIREBASE_AUTH_EMULATOR_HOST || '').trim();
  if (!authHost) {
    return {
      ok: false,
      error:
        'FIREBASE_AUTH_EMULATOR_HOST es obligatorio (p. ej. 127.0.0.1:9099). ' +
        'Sin emulador Auth este script se niega a ejecutarse.',
    };
  }
  if (!isLocalEmulatorHost(authHost)) {
    return {
      ok: false,
      error: `FIREBASE_AUTH_EMULATOR_HOST no es local/seguro: ${authHost}`,
    };
  }

  const fsHost = (env.FIRESTORE_EMULATOR_HOST || '').trim();
  if (!fsHost) {
    return {
      ok: false,
      error:
        'FIRESTORE_EMULATOR_HOST es obligatorio (p. ej. 127.0.0.1:8085). ' +
        'Sin emulador Firestore este script se niega a ejecutarse.',
    };
  }
  if (!isLocalEmulatorHost(fsHost)) {
    return {
      ok: false,
      error: `FIRESTORE_EMULATOR_HOST no es local/seguro: ${fsHost}`,
    };
  }

  const projectId = (
    env.GCLOUD_PROJECT ||
    env.GOOGLE_CLOUD_PROJECT ||
    ''
  ).trim();
  if (!projectId) {
    return {
      ok: false,
      error:
        'GCLOUD_PROJECT/GOOGLE_CLOUD_PROJECT es obligatorio y debe ser demo-vicunha-sync-test.',
    };
  }
  if (BLOCKED_PROJECT_IDS.has(projectId)) {
    return {
      ok: false,
      error: `Proyecto productivo rechazado: ${projectId}`,
    };
  }
  if (!ALLOWED_PROJECT_IDS.has(projectId)) {
    return {
      ok: false,
      error: `Project ID no autorizado: ${projectId}. Solo demo-vicunha-sync-test.`,
    };
  }

  // Si hay GAC en el entorno del desarrollador, no fallamos aquí: main() lo
  // elimina del process.env antes de inicializar Admin, y solo tras validar
  // emuladores locales + project demo. Sin emulador, este script ya rechazó.
  return {
    ok: true,
    uid: trimmedUid,
    projectId,
    authHost,
    hadGoogleApplicationCredentials: Boolean(
      firstEnv(env, [
        'GOOGLE_APPLICATION_CREDENTIALS',
        'google_application_credentials',
      ]),
    ),
  };
}

function firstEnv(env, keys) {
  for (const key of keys) {
    const direct = env[key];
    if (typeof direct === 'string' && direct.trim()) return direct.trim();
  }
  for (const [key, value] of Object.entries(env)) {
    if (
      keys.some((k) => k.toLowerCase() === String(key).toLowerCase()) &&
      typeof value === 'string' &&
      value.trim()
    ) {
      return value.trim();
    }
  }
  return '';
}

function isLocalEmulatorHost(hostPort) {
  const host = String(hostPort).split(':')[0].toLowerCase();
  return (
    host === '127.0.0.1' ||
    host === 'localhost' ||
    host === '[::1]' ||
    host === '::1'
  );
}

/**
 * GET al root del Auth emulator. Falla si no responde localmente.
 * @param {string} authHost host:port
 * @returns {Promise<void>}
 */
function assertAuthEmulatorReachable(authHost) {
  return new Promise((resolve, reject) => {
    const [host, portRaw] = authHost.split(':');
    const port = Number(portRaw || 9099);
    const req = http.get({ host, port, path: '/', timeout: 2000 }, (res) => {
      res.resume();
      resolve();
    });
    req.on('timeout', () => {
      req.destroy();
      reject(new Error(`Timeout al contactar Auth emulator en ${authHost}`));
    });
    req.on('error', (err) => {
      reject(
        new Error(
          `Auth emulator no alcanzable en ${authHost}: ${err.message}`,
        ),
      );
    });
  });
}

async function main(argv = process.argv, env = process.env) {
  const parsed = validateSeedEmulatorClaimEnv(env, argv[2]);
  if (!parsed.ok) {
    console.error(parsed.error);
    process.exitCode = 1;
    return;
  }

  await assertAuthEmulatorReachable(parsed.authHost);

  // Asegura que Admin SDK hable solo con emuladores (ya validados).
  process.env.FIREBASE_AUTH_EMULATOR_HOST = env.FIREBASE_AUTH_EMULATOR_HOST;
  process.env.FIRESTORE_EMULATOR_HOST = env.FIRESTORE_EMULATOR_HOST;
  // Nunca usar SA productiva: borrar credenciales del proceso hijo.
  for (const key of Object.keys(process.env)) {
    if (key.toLowerCase() === 'google_application_credentials') {
      delete process.env[key];
    }
  }

  try {
    admin.app();
  } catch (e) {
    void e;
    admin.initializeApp({ projectId: parsed.projectId });
  }

  await admin.auth().setCustomUserClaims(parsed.uid, { role: 'admin' });
  // No registrar tokens ni PII; solo confirmación de UID.
  console.log(`claim admin OK uid=${parsed.uid} project=${parsed.projectId}`);
}

module.exports = {
  validateSeedEmulatorClaimEnv,
  isLocalEmulatorHost,
  assertAuthEmulatorReachable,
  ALLOWED_PROJECT_IDS,
  BLOCKED_PROJECT_IDS,
  main,
};

if (require.main === module) {
  main().catch((e) => {
    console.error(e && e.message ? e.message : e);
    process.exit(1);
  });
}
