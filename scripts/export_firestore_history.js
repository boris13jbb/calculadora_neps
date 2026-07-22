/**
 * Exporta datos históricos de Firestore (workspace vicunha) a un JSON
 * consumible por RegNeps.Net (migración a SQL).
 *
 * Autenticación (en orden):
 *   1) --credentials ruta/serviceAccount.json  (recomendado)
 *   2) GOOGLE_APPLICATION_CREDENTIALS
 *   3) firebase login (token CLI)
 *
 * Uso:
 *   node scripts/export_firestore_history.js
 *   node scripts/export_firestore_history.js --out FTS/firestore_export.json
 *   node scripts/export_firestore_history.js --credentials secrets/serviceAccountKey.json
 *
 * No incluye contraseñas de Auth (Firebase no las exporta).
 */
const {writeFileSync, mkdirSync, existsSync} = require('fs');
const {dirname, resolve} = require('path');

const PROJECT_ID = 'vicunha-calculadora-neps';
const WORKSPACE_ID = 'vicunha';
const BASE =
  `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

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

async function getAccessTokenFromServiceAccount(credentialsPath) {
  const {GoogleAuth} = require('google-auth-library');
  const auth = new GoogleAuth({
    keyFile: credentialsPath,
    scopes: [
      'https://www.googleapis.com/auth/datastore',
      'https://www.googleapis.com/auth/cloud-platform',
    ],
  });
  const client = await auth.getClient();
  const token = await client.getAccessToken();
  if (!token?.token) {
    throw new Error('No se obtuvo access token desde service account.');
  }
  return token.token;
}

async function getAccessTokenFromCli() {
  const {loadFirebaseCliTokens} = require('./load_firebase_cli_tokens');
  const tokens = loadFirebaseCliTokens();
  if (tokens.access_token && tokens.expires_at && Date.now() < tokens.expires_at - 60_000) {
    return tokens.access_token;
  }
  let lastError;
  for (const client of OAUTH_CLIENTS) {
    try {
      const body = new URLSearchParams({
        client_id: client.client_id,
        client_secret: client.client_secret,
        refresh_token: tokens.refresh_token,
        grant_type: 'refresh_token',
      });
      const res = await fetch('https://oauth2.googleapis.com/token', {
        method: 'POST',
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body,
      });
      const data = await res.json();
      if (!res.ok) {
        lastError = data?.error_description || data?.error || res.status;
        continue;
      }
      return data.access_token;
    } catch (e) {
      lastError = e.message;
    }
  }
  throw new Error(
      `Token CLI inválido/vencido (${lastError}). Ejecute "firebase login" ` +
      'o use --credentials secrets/serviceAccountKey.json',
  );
}

async function resolveAccessToken(args) {
  const credPath = args.credentials || process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (credPath) {
    const abs = resolve(process.cwd(), credPath);
    if (!existsSync(abs)) {
      throw new Error(`No existe el archivo de credenciales: ${abs}`);
    }
    console.log(`Auth: service account (${abs})`);
    return getAccessTokenFromServiceAccount(abs);
  }

  console.log('Auth: Firebase CLI (firebase login)');
  return getAccessTokenFromCli();
}

function decodeValue(v) {
  if (v == null) return null;
  if (Object.prototype.hasOwnProperty.call(v, 'nullValue')) return null;
  if (Object.prototype.hasOwnProperty.call(v, 'stringValue')) return v.stringValue;
  if (Object.prototype.hasOwnProperty.call(v, 'integerValue')) return Number(v.integerValue);
  if (Object.prototype.hasOwnProperty.call(v, 'doubleValue')) return v.doubleValue;
  if (Object.prototype.hasOwnProperty.call(v, 'booleanValue')) return v.booleanValue;
  if (Object.prototype.hasOwnProperty.call(v, 'timestampValue')) return v.timestampValue;
  if (Object.prototype.hasOwnProperty.call(v, 'mapValue')) {
    return decodeFields(v.mapValue.fields || {});
  }
  if (Object.prototype.hasOwnProperty.call(v, 'arrayValue')) {
    return (v.arrayValue.values || []).map(decodeValue);
  }
  return null;
}

function decodeFields(fields) {
  const out = {};
  for (const [k, v] of Object.entries(fields || {})) {
    out[k] = decodeValue(v);
  }
  return out;
}

function docIdFromName(name) {
  const parts = String(name || '').split('/');
  return parts[parts.length - 1] || '';
}

async function listDocuments(accessToken, relativePath) {
  const docs = [];
  let pageToken;
  do {
    const url = new URL(`${BASE}/${relativePath}`);
    url.searchParams.set('pageSize', '300');
    if (pageToken) url.searchParams.set('pageToken', pageToken);
    const res = await fetch(url, {
      headers: {Authorization: `Bearer ${accessToken}`},
    });
    const data = await res.json();
    if (!res.ok) {
      throw new Error(
          `List ${relativePath}: ${data?.error?.message || res.status} ${JSON.stringify(data?.error || {})}`,
      );
    }
    for (const doc of data.documents || []) {
      const plain = decodeFields(doc.fields);
      plain.id = plain.id || docIdFromName(doc.name);
      plain.__path = doc.name;
      docs.push(plain);
    }
    pageToken = data.nextPageToken;
  } while (pageToken);
  return docs;
}

async function getDocument(accessToken, relativePath) {
  const res = await fetch(`${BASE}/${relativePath}`, {
    headers: {Authorization: `Bearer ${accessToken}`},
  });
  if (res.status === 404) return null;
  const data = await res.json();
  if (!res.ok) {
    throw new Error(`Get ${relativePath}: ${data?.error?.message || res.status}`);
  }
  return decodeFields(data.fields || {});
}

async function main() {
  const args = parseArgs(process.argv);
  const out = args.out || 'FTS/firestore_export.json';
  const outPath = resolve(process.cwd(), out);
  const accessToken = await resolveAccessToken(args);

  console.log('Exportando registros...');
  const records = await listDocuments(
      accessToken,
      `workspaces/${WORKSPACE_ID}/records`,
  );

  console.log('Exportando usuarios...');
  const users = await listDocuments(
      accessToken,
      `workspaces/${WORKSPACE_ID}/users`,
  );

  console.log('Exportando informes...');
  let reports = [];
  try {
    reports = await listDocuments(
        accessToken,
        `workspaces/${WORKSPACE_ID}/reports`,
    );
  } catch (e) {
    console.warn('Informes no disponibles:', e.message);
  }

  console.log('Exportando meta/fabrics y meta/config...');
  const fabricsDoc = await getDocument(
      accessToken,
      `workspaces/${WORKSPACE_ID}/meta/fabrics`,
  );
  const configDoc = await getDocument(
      accessToken,
      `workspaces/${WORKSPACE_ID}/meta/config`,
  );

  const payload = {
    exportedAt: new Date().toISOString(),
    projectId: PROJECT_ID,
    workspaceId: WORKSPACE_ID,
    records,
    users,
    reports,
    fabrics: fabricsDoc?.items || [],
    alertConfig: configDoc || {},
  };

  mkdirSync(dirname(outPath), {recursive: true});
  writeFileSync(outPath, JSON.stringify(payload, null, 2), 'utf8');
  console.log(`OK → ${outPath}`);
  console.log(
      `Resumen: ${records.length} registros, ${users.length} usuarios, ` +
      `${reports.length} informes, ${(payload.fabrics || []).length} telas`,
  );
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
