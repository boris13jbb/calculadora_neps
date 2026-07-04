/**
 * Desactiva autenticación anónima y deja solo email/contraseña.
 */
const {GoogleAuth} = require('google-auth-library');
const {loadFirebaseCliTokens} = require('./load_firebase_cli_tokens');

const PROJECT_ID = 'vicunha-calculadora-neps';

async function getAccessToken() {
  const tokens = loadFirebaseCliTokens();
  const expiresAtMs = Number(tokens.expires_at || 0);
  if (tokens.access_token && expiresAtMs > Date.now() + 60_000) {
    return tokens.access_token;
  }

  if (!tokens.client_id || !tokens.client_secret || !tokens.refresh_token) {
    throw new Error(
      'Tokens de Firebase CLI incompletos. Ejecute firebase login e intente de nuevo.',
    );
  }

  const auth = new GoogleAuth({
    credentials: {
      type: 'authorized_user',
      client_id: tokens.client_id,
      client_secret: tokens.client_secret,
      refresh_token: tokens.refresh_token,
    },
  });
  const client = await auth.getClient();
  const tokenResponse = await client.getAccessToken();
  if (!tokenResponse.token) {
    throw new Error('No se pudo obtener access token. Ejecute firebase login.');
  }
  return tokenResponse.token;
}

async function main() {
  const accessToken = await getAccessToken();
  const url =
    `https://identitytoolkit.googleapis.com/admin/v2/projects/${PROJECT_ID}/config?updateMask=signIn.anonymous.enabled,signIn.email.enabled,signIn.email.passwordRequired`;

  const response = await fetch(url, {
    method: 'PATCH',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      name: `projects/${PROJECT_ID}/config`,
      signIn: {
        anonymous: {enabled: false},
        email: {enabled: true, passwordRequired: true},
      },
    }),
  });

  const text = await response.text();
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}: ${text}`);
  }

  console.log('OK: anónimo desactivado, email/contraseña activo.');
}

main().catch((error) => {
  console.error('Error:', error.message || error);
  process.exit(1);
});
