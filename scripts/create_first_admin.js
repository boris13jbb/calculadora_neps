/**
 * Crea el primer super_admin con email/contraseña usando credenciales del CLI.
 * Ejecutar desde carpeta functions:
 *   node ../scripts/create_first_admin.js admin@empresa.com "ContraseñaSegura123"
 */
const {initializeApp, getApps} = require('firebase-admin/app');
const {getAuth} = require('firebase-admin/auth');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');

const WORKSPACE_ID = 'vicunha';

function initAdmin() {
  if (getApps().length === 0) {
    initializeApp({
      projectId: 'vicunha-calculadora-neps',
    });
  }
}

async function main() {
  const email = process.argv[2];
  const password = process.argv[3];
  const displayName = process.argv[4] || 'Super Administrador';

  if (!email || !password || password.length < 8) {
    console.error(
        'Uso: node ../scripts/create_first_admin.js email@empresa.com "Contraseña8+" [nombre]',
    );
    process.exit(1);
  }

  initAdmin();
  const auth = getAuth();
  const db = getFirestore();

  let user;
  try {
    user = await auth.getUserByEmail(email);
    console.log('Usuario existente encontrado:', user.uid);
  } catch (error) {
    if (error.code !== 'auth/user-not-found') throw error;
    user = await auth.createUser({
      email,
      password,
      displayName,
      emailVerified: true,
    });
    console.log('Usuario creado:', user.uid);
  }

  await auth.setCustomUserClaims(user.uid, {
    role: 'super_admin',
    workspaceId: WORKSPACE_ID,
    superAdmin: true,
  });

  await auth.updateUser(user.uid, {
    displayName,
    disabled: false,
    password,
  });

  await db.doc(`workspaces/${WORKSPACE_ID}/users/${user.uid}`).set({
    uid: user.uid,
    email,
    displayName,
    role: 'super_admin',
    isActive: true,
    createdBy: 'create_first_admin_script',
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});

  await db.collection(`workspaces/${WORKSPACE_ID}/audit_logs`).add({
    action: 'user_created',
    performedByUid: 'create_first_admin_script',
    performedByEmail: 'script',
    targetUid: user.uid,
    targetEmail: email,
    newValue: {role: 'super_admin'},
    createdAt: FieldValue.serverTimestamp(),
  });

  console.log('\nSuper admin listo:');
  console.log('  Email:', email);
  console.log('  UID:', user.uid);
  console.log('Cierre sesión en la app y vuelva a entrar con este correo.');
}

main().catch((error) => {
  console.error('Error:', error.message || error);
  process.exit(1);
});
