/**
 * Crea usuarios de prueba por rol (email/password) vía Identity Toolkit API.
 * Los custom claims y perfil Firestore se asignan con Firebase Admin/MCP después.
 *
 * Uso: node scripts/provision_role_users.js
 */
const API_KEY = 'AIzaSyDXX4MxQtESuyX5UF-WHB7g6Wcln5tOp48';
const PASSWORD = 'Vicunha2026!Rol';

const USERS = [
  {email: 'administrador@vicunha-neps.com', displayName: 'Administrador', role: 'admin'},
  {email: 'supervisor@vicunha-neps.com', displayName: 'Supervisor', role: 'supervisor'},
  {email: 'operario@vicunha-neps.com', displayName: 'Operario', role: 'operario'},
  {email: 'gerencia@vicunha-neps.com', displayName: 'Gerencia', role: 'gerencia'},
];

async function signUp(email, password) {
  const response = await fetch(
      `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${API_KEY}`,
      {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({
          email,
          password,
          returnSecureToken: true,
        }),
      },
  );

  const data = await response.json();
  if (!response.ok) {
    if (data?.error?.message === 'EMAIL_EXISTS') {
      return {email, exists: true};
    }
    throw new Error(`${email}: ${data?.error?.message || response.status}`);
  }

  return {
    email,
    uid: data.localId,
    exists: false,
  };
}

async function main() {
  const created = [];
  for (const user of USERS) {
    try {
      const result = await signUp(user.email, PASSWORD);
      created.push({...user, ...result, password: PASSWORD});
      console.log(
          result.exists ?
            `Ya existe: ${user.email}` :
            `Creado: ${user.email} → ${result.uid}`,
      );
    } catch (error) {
      console.error(`Error ${user.email}:`, error.message);
    }
  }

  console.log('\n--- Resumen JSON ---');
  console.log(JSON.stringify(created, null, 2));
  console.log(`\nContraseña temporal para todos: ${PASSWORD}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
