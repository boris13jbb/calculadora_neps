const {existsSync, readFileSync} = require('fs');
const {join} = require('path');
const {homedir} = require('os');

function loadFirebaseCliTokens() {
  const candidates = [
    join(process.env.APPDATA || '', 'configstore', 'firebase-tools.json'),
    join(homedir(), '.config', 'configstore', 'firebase-tools.json'),
  ];

  for (const path of candidates) {
    if (!existsSync(path)) continue;
    const tokens = JSON.parse(readFileSync(path, 'utf8'))?.tokens;
    if (tokens?.refresh_token) return tokens;
  }

  throw new Error('Ejecute firebase login primero.');
}

module.exports = {loadFirebaseCliTokens};
