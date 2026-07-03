/**
 * Script local para crear o promover un super_admin (con correo real).
 *
 * Crea el usuario en Firebase Auth si no existe (con contraseña), le asigna
 * los custom claims de super administrador y crea/actualiza su perfil en
 * Firestore. Usa las credenciales del Firebase CLI (firebase login) mediante
 * llamadas REST (Identity Toolkit Admin + Firestore), por lo que no requiere
 * una service account ni la instalación de gcloud.
 *
 * Uso:
 *   node scripts/create_super_admin.js --email correo@empresa.com --password Secreta123
 *   node scripts/create_super_admin.js --email correo@empresa.com --password Secreta123 --username miusuario --displayName "Nombre"
 *
 * No suba serviceAccountKey.json ni credenciales al repositorio.
 */
const {loadFirebaseCliTokens} = require('./load_firebase_cli_tokens');

const WORKSPACE_ID = 'vicunha';
const PROJECT_ID = 'vicunha-calculadora-neps';
const WEB_API_KEY = 'AIzaSyDXX4MxQtESuyX5UF-WHB7g6Wcln5tOp48';
const USERNAME_PATTERN = /^[a-z0-9][a-z0-9._-]*$/;

// Clientes OAuth conocidos para refrescar el token según su origen.
const OAUTH_CLIENTS = [
  {
    client_id:
      '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
    client_secret: 'j9pDscCJS3REPKoNEzuo1P9m8RvDdC3QT3sSRpD9',
  },
  {
    client_id: '32555940559.apps.googleusercontent.com',
    client_secret: 'ZmssLNjJy2998hD4CTg2ejr2',
  },
];

function parseArgs(argv) {
  const args = {};
  for (let i = 2; i < argv.length; i += 2) {
    const key = argv[i]?.replace(/^--/, '');
    const value = argv[i + 1];
    if (key && value) args[key] = value;
  }
  return args;
}

/**
 * Deriva un username válido a partir del correo (parte local saneada).
 * @param {string} email
 * @return {string}
 */
function deriveUsername(email) {
  const local = email.split('@')[0].toLowerCase();
  const sanitized = local.replace(/[^a-z0-9._-]/g, '');
  return USERNAME_PATTERN.test(sanitized) ? sanitized : `sa${Date.now()}`;
}

/**
 * Obtiene un access token OAuth válido a partir de las credenciales del CLI.
 * Reutiliza el access token cacheado si sigue vigente; de lo contrario lo
 * refresca probando los clientes OAuth conocidos.
 * @return {Promise<string>}
 */
async function getAccessToken() {
  const tokens = loadFirebaseCliTokens();

  const expiresAt = Number(tokens.expires_at || 0);
  if (tokens.access_token && expiresAt > Date.now() + 60_000) {
    return tokens.access_token;
  }

  const clients = [];
  if (tokens.client_id && tokens.client_secret) {
    clients.push({
      client_id: tokens.client_id,
      client_secret: tokens.client_secret,
    });
  }
  clients.push(...OAUTH_CLIENTS);

  let lastError = 'desconocido';
  for (const client of clients) {
    const response = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: new URLSearchParams({
        client_id: client.client_id,
        client_secret: client.client_secret,
        refresh_token: tokens.refresh_token,
        grant_type: 'refresh_token',
      }),
    });
    const data = await response.json();
    if (response.ok && data.access_token) return data.access_token;
    lastError = data.error_description || data.error || response.status;
  }

  if (tokens.access_token) return tokens.access_token;
  throw new Error(`No se pudo obtener access token (${lastError}).`);
}

/**
 * Crea el usuario en Auth (o devuelve el existente) vía Identity Toolkit.
 * @param {string} email
 * @param {string} password
 * @return {Promise<string>} uid
 */
async function ensureAuthUser(email, password) {
  const signUp = await fetch(
      `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${WEB_API_KEY}`,
      {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({email, password, returnSecureToken: true}),
      },
  );
  const data = await signUp.json();
  if (signUp.ok && data.localId) {
    console.log('Usuario creado en Firebase Auth.');
    return data.localId;
  }
  if (data?.error?.message !== 'EMAIL_EXISTS') {
    throw new Error(`signUp: ${data?.error?.message || signUp.status}`);
  }
  console.log('El usuario ya existe en Firebase Auth.');
  return null;
}

/**
 * Busca el uid de un usuario por email (requiere bearer admin).
 * @param {string} accessToken
 * @param {string} email
 * @return {Promise<string>}
 */
async function lookupUidByEmail(accessToken, email) {
  const response = await fetch(
      `https://identitytoolkit.googleapis.com/v1/projects/${PROJECT_ID}/accounts:lookup`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({email: [email]}),
      },
  );
  const data = await response.json();
  if (!response.ok || !data.users || !data.users[0]) {
    throw new Error(
        `lookup: ${data?.error?.message || response.status}`,
    );
  }
  return data.users[0].localId;
}

/**
 * Asigna custom claims, contraseña y estado activo al usuario.
 * @param {string} accessToken
 * @param {string} uid
 * @param {Object} claims
 * @param {string} displayName
 * @param {string} password
 */
async function updateAuthAccount(accessToken, uid, claims, displayName, password) {
  const body = {
    localId: uid,
    displayName,
    disableUser: false,
    customAttributes: JSON.stringify(claims),
  };
  if (password) body.password = password;

  const response = await fetch(
      `https://identitytoolkit.googleapis.com/v1/projects/${PROJECT_ID}/accounts:update`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(body),
      },
  );
  const data = await response.json();
  if (!response.ok) {
    throw new Error(`accounts:update: ${data?.error?.message || response.status}`);
  }
}

/**
 * Escribe el perfil del usuario en Firestore vía REST (respeta IAM del
 * proyecto y evita las reglas de cliente que bloquean la creación).
 * @param {string} accessToken
 * @param {string} uid
 * @param {Object} profile
 */
async function writeProfileViaRest(accessToken, uid, profile) {
  const now = new Date().toISOString();
  const fields = {
    uid: {stringValue: uid},
    username: {stringValue: profile.username},
    internalEmail: {nullValue: null},
    realEmail: {stringValue: profile.realEmail},
    displayName: {stringValue: profile.displayName},
    role: {stringValue: 'super_admin'},
    isActive: {booleanValue: true},
    isSuperAdmin: {booleanValue: true},
    createdBy: {stringValue: 'create_super_admin_script'},
    createdAt: {timestampValue: now},
    updatedAt: {timestampValue: now},
    deletedAt: {nullValue: null},
  };

  const path =
    `projects/${PROJECT_ID}/databases/(default)/documents/` +
    `workspaces/${WORKSPACE_ID}/users/${uid}`;

  const response = await fetch(`https://firestore.googleapis.com/v1/${path}`, {
    method: 'PATCH',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({fields}),
  });

  if (!response.ok) {
    const detail = await response.text();
    throw new Error(`Firestore REST ${response.status}: ${detail}`);
  }
}

async function main() {
  const {
    email,
    password,
    username: usernameArg,
    displayName = 'Super Administrador',
  } = parseArgs(process.argv);

  if (!email || !password) {
    console.error(
        'Uso: node scripts/create_super_admin.js --email correo@empresa.com ' +
        '--password Secreta123 [--username miusuario] [--displayName "Nombre"]',
    );
    process.exit(1);
  }
  if (password.length < 6) {
    throw new Error('La contraseña debe tener al menos 6 caracteres.');
  }

  const username = (usernameArg || deriveUsername(email)).toLowerCase();
  if (!USERNAME_PATTERN.test(username)) {
    throw new Error(`Username inválido: ${username}`);
  }

  const emailNorm = email.trim().toLowerCase();
  const accessToken = await getAccessToken();

  let uid = await ensureAuthUser(emailNorm, password);
  if (!uid) uid = await lookupUidByEmail(accessToken, emailNorm);

  const claims = {
    role: 'super_admin',
    workspaceId: WORKSPACE_ID,
    username,
    isSuperAdmin: true,
    superAdmin: true,
  };

  await updateAuthAccount(accessToken, uid, claims, displayName, password);
  await writeProfileViaRest(accessToken, uid, {
    username,
    realEmail: emailNorm,
    displayName,
  });

  console.log('\nSuper admin configurado correctamente:');
  console.log(`  UID: ${uid}`);
  console.log(`  Username: ${username}`);
  console.log(`  Email real: ${emailNorm}`);
  console.log('  Claims:', claims);
  console.log(
      '\nEl usuario debe iniciar sesión con su correo y, si ya tenía sesión,' +
      ' cerrarla y volver a entrar para refrescar el token.',
  );
}

main().catch((error) => {
  console.error('Error:', error.message || error);
  process.exit(1);
});
