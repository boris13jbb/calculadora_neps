const {initializeApp} = require('firebase/app');
const {getFunctions, httpsCallable} = require('firebase/functions');

const secret = process.env.BOOTSTRAP_SECRET;
const email = process.env.BOOTSTRAP_EMAIL;
const password = process.env.BOOTSTRAP_PASSWORD;
const displayName = process.env.BOOTSTRAP_DISPLAY_NAME || 'Super Administrador';
const apiKey = process.env.FIREBASE_API_KEY;
const projectId = process.env.FIREBASE_PROJECT_ID || 'vicunha-calculadora-neps';

if (!secret || !email || !password) {
  console.error(
    'Defina BOOTSTRAP_SECRET, BOOTSTRAP_EMAIL y BOOTSTRAP_PASSWORD '
      + '(por ejemplo en scripts/.env.local, no versionado).',
  );
  process.exit(1);
}

if (!apiKey) {
  console.error('Defina FIREBASE_API_KEY para el cliente web de bootstrap.');
  process.exit(1);
}

const app = initializeApp({apiKey, projectId});
const functions = getFunctions(app, 'us-central1');
const bootstrap = httpsCallable(functions, 'bootstrapFirstSuperAdmin');

bootstrap({
  secret,
  email,
  password,
  displayName,
})
  .then((result) => {
    console.log('OK:', JSON.stringify(result.data, null, 2));
  })
  .catch((error) => {
    console.error('Error:', error.code, error.message);
    if (error.details) console.error('Details:', error.details);
    process.exit(1);
  });
