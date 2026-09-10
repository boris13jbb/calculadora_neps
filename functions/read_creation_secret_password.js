/**
 * Lee la contraseña temporal de user_creation_secrets con reintentos acotados.
 *
 * Clientes antiguos pueden escribir request y secret en commits separados; el
 * trigger no debe interpretar "secreto aún no existe" como "contraseña corta".
 *
 * Riesgo de secreto huérfano (solo clientes pre-batch): si el trigger falla y
 * elimina el secret antes de que el cliente lo escriba, el secret puede quedar
 * sin request asociado. Identificar: listar user_creation_secrets y, para cada
 * id, comprobar user_creation_requests/{id}; si falta o status es
 * failed/completed, es candidato. Nunca registrar el campo password en logs.
 * No limpiar producción sin autorización explícita.
 *
 * @param {{get: () => Promise<{exists: boolean, data: () => Object|undefined}>}} secretRef
 * @param {{attempts?: number, delayMs?: number}=} options
 * @return {Promise<string>}
 */
async function readCreationSecretPassword(secretRef, options = {}) {
  const attempts = Math.max(1, Number(options.attempts) || 6);
  const delayMs = Math.max(0, Number(options.delayMs) || 250);

  for (let attempt = 1; attempt <= attempts; attempt++) {
    const secretSnap = await secretRef.get();
    if (secretSnap.exists) {
      const password = String(secretSnap.data()?.password || "");
      if (password.length < 8) {
        throw new Error("La contraseña debe tener al menos 8 caracteres.");
      }
      return password;
    }
    if (attempt < attempts) {
      await new Promise((resolve) => setTimeout(resolve, delayMs));
    }
  }

  throw new Error(
      "No se recibió la contraseña temporal para crear el usuario.",
  );
}

module.exports = {readCreationSecretPassword};
