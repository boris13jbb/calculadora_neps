const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const {logger} = require("firebase-functions");
const adminUsers = require("./admin_users");

initializeApp();

Object.assign(exports, adminUsers);

const WORKSPACE_ID = "vicunha";
const DEFAULT_WARNING_MAX = 60;

/**
 * Lee el umbral de advertencia desde meta/config (misma lógica que la app).
 * Crítico = neps > limiteAdvertenciaMax.
 */
async function getWarningMaxNeps(db) {
  const snap = await db.doc(`workspaces/${WORKSPACE_ID}/meta/config`).get();
  if (!snap.exists) return DEFAULT_WARNING_MAX;

  const value = snap.data()?.limiteAdvertenciaMax;
  return typeof value === "number" && value > 0 ? value : DEFAULT_WARNING_MAX;
}

/**
 * Notifica a supervisores/administradores cuando se crea un registro crítico.
 */
exports.onCriticalRecordCreated = onDocumentCreated(
    {
      document: `workspaces/${WORKSPACE_ID}/users/{userId}/records/{recordId}`,
      region: "us-central1",
    },
    async (event) => {
      const data = event.data?.data();
      if (!data) return;

      const neps = Number(data.neps);
      if (!Number.isFinite(neps) || neps <= 0) return;

      const db = getFirestore();
      const warningMax = await getWarningMaxNeps(db);
      if (neps <= warningMax) {
        logger.info("Registro no crítico, sin notificación push", {neps, warningMax});
        return;
      }

      const supervisorsSnap = await db
          .collection(`workspaces/${WORKSPACE_ID}/users`)
          .where("role", "in", [
            "supervisor",
            "admin",
            "super_admin",
            "SUPERVISOR",
            "ADMINISTRADOR",
          ])
          .get();

      const tokens = supervisorsSnap.docs
          .map((doc) => doc.data().fcmToken)
          .filter((token) => typeof token === "string" && token.length > 0);

      if (tokens.length === 0) {
        logger.warn("Sin tokens FCM de supervisores para alerta crítica");
        return;
      }

      const telar = data.telar ?? "?";
      const tela = data.tela ?? "";
      const body = tela
        ? `${neps} neps · ${tela}`
        : `${neps} neps registrados`;

      const response = await getMessaging().sendEachForMulticast({
        tokens,
        notification: {
          title: `Alerta crítica — Telar ${telar}`,
          body,
        },
        data: {
          screen: "alerts",
          recordId: event.params.recordId,
          telar: String(telar),
          neps: String(neps),
        },
        android: {
          priority: "high",
          notification: {
            channelId: "critical_alerts",
          },
        },
      });

      logger.info("Push crítico enviado", {
        success: response.successCount,
        failure: response.failureCount,
        recordId: event.params.recordId,
      });
    },
);
