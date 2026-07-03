const {initializeApp} = require('firebase/app');
const {getFunctions, httpsCallable, connectFunctionsEmulator} = require('firebase/functions');

const app = initializeApp({
  apiKey: 'AIzaSyDXX4MxQtESuyX5UF-WHB7g6Wcln5tOp48',
  projectId: 'vicunha-calculadora-neps',
});

const functions = getFunctions(app, 'us-central1');
const bootstrap = httpsCallable(functions, 'bootstrapFirstSuperAdmin');

bootstrap({
  secret: 'VicunhaBootstrap2026SecureKey!',
  email: 'admin@vicunha-neps.com',
  password: 'Vicunha2026!Admin',
  displayName: 'Super Administrador',
})
    .then((result) => {
      console.log('OK:', JSON.stringify(result.data, null, 2));
    })
    .catch((error) => {
      console.error('Error:', error.code, error.message);
      if (error.details) console.error('Details:', error.details);
      process.exit(1);
    });
