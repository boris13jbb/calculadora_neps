/**
 * Asigna claims y perfiles Firestore a usuarios por rol.
 */
const {initializeApp, getApps, refreshToken} = require('firebase-admin/app');
const {loadFirebaseCliTokens} = require('./load_firebase_cli_tokens');
const {getAuth} = require('firebase-admin/auth');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');

const WORKSPACE_ID = 'vicunha';

const USERS = [
  {
    uid: 'OXhg4O1uALfVqyFVITPQh0EmkxD2',
    email: 'administrador@vicunha-neps.com',
    displayName: 'Administrador',
    role: 'admin',
  },
  {
    uid: 'i7raVFsGIagGznUW3wTm9rwwogk2',
    email: 'supervisor@vicunha-neps.com',
    displayName: 'Supervisor',
    role: 'supervisor',
  },
  {
    uid: 'kJvEFwqv5yO3DOlfBSk9JmftbAD2',
    email: 'operario@vicunha-neps.com',
    displayName: 'Operario',
    role: 'operario',
  },
  {
    uid: 'IX7q8SIpudUE4IDXXi3BqfXQwhn1',
    email: 'gerencia@vicunha-neps.com',
    displayName: 'Gerencia',
    role: 'gerencia',
  },
];

function initAdmin() {
  if (getApps().length > 0) return;

  const tokens = loadFirebaseCliTokens();

  initializeApp({
    projectId: 'vicunha-calculadora-neps',
    credential: refreshToken({
      type: 'authorized_user',
      client_id: tokens.client_id || '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
      client_secret: tokens.client_secret || 'j9pDscCJS3REPKoNEzuo1P9m8RvDdC3QT3sSRpD9',
      refresh_token: tokens.refresh_token,
    }),
  });
}

async function main() {
  initAdmin();
  const auth = getAuth();
  const db = getFirestore();

  for (const user of USERS) {
    await auth.setCustomUserClaims(user.uid, {
      role: user.role,
      workspaceId: WORKSPACE_ID,
    });

    await db.doc(`workspaces/${WORKSPACE_ID}/users/${user.uid}`).set({
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      role: user.role,
      isActive: true,
      createdBy: 'provision_role_users',
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});

    console.log(`OK ${user.role}: ${user.email}`);
  }
}

main().catch((error) => {
  console.error('Error:', error.message || error);
  process.exit(1);
});
