/**
 * Migración metadata-only: crea reportSummaries/{id} desde reports/{id}.
 * NO modifica reports/{id} ni records[].
 *
 * Pensado para invocación controlada (super_admin + dryRun por defecto).
 */

/**
 * @param {unknown} value
 * @return {string|null}
 */
function toIsoDate(value) {
  if (value == null) return null;
  if (typeof value === "string") {
    const parsed = Date.parse(value);
    return Number.isNaN(parsed) ? null : new Date(parsed).toISOString();
  }
  if (typeof value.toDate === "function") {
    try {
      return value.toDate().toISOString();
    } catch (_) {
      return null;
    }
  }
  if (value instanceof Date) return value.toISOString();
  return null;
}

/**
 * Construye el payload de summary sin tocar el documento full.
 * @param {string} reportId
 * @param {Object} reportData
 * @return {Object}
 */
function buildSummaryPayload(reportId, reportData) {
  const data = reportData || {};
  const records = Array.isArray(data.records) ? data.records : [];
  let minIso = null;
  let maxIso = null;

  for (const record of records) {
    if (!record || typeof record !== "object") continue;
    const iso = toIsoDate(record.createdAt);
    if (!iso) continue;
    if (minIso == null || iso < minIso) minIso = iso;
    if (maxIso == null || iso > maxIso) maxIso = iso;
  }

  const createdAt = toIsoDate(data.createdAt) || new Date().toISOString();
  const createdByUid =
    typeof data.createdByUid === "string" && data.createdByUid.trim()
      ? data.createdByUid.trim()
      : null;

  const payload = {
    id: reportId,
    name:
      typeof data.name === "string" && data.name.trim()
        ? data.name.trim()
        : "Informe",
    createdAt,
    recordCount: records.length,
  };

  if (createdByUid) payload.createdByUid = createdByUid;
  if (records.length > 0 && minIso) payload.recordsCreatedAtMin = minIso;
  if (records.length > 0 && maxIso) payload.recordsCreatedAtMax = maxIso;

  return payload;
}

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} workspaceId
 * @param {{dryRun?: boolean, batchSize?: number, maxDocs?: number}} [options]
 * @return {Promise<{
 *   scanned: number,
 *   missing: number,
 *   written: number,
 *   skippedExisting: number,
 *   dryRun: boolean,
 *   sampleMissingIds: string[],
 * }>}
 */
async function runReportSummaryBackfill(db, workspaceId, options = {}) {
  const {FieldValue} = require("firebase-admin/firestore");
  const {logger} = require("firebase-functions");

  const dryRun = options.dryRun !== false;
  const batchSize = Math.min(Math.max(options.batchSize || 100, 1), 400);
  const maxDocs = Math.min(Math.max(options.maxDocs || 500, 1), 5000);

  const reportsRef = db
      .collection("workspaces")
      .doc(workspaceId)
      .collection("reports");
  const summariesRef = db
      .collection("workspaces")
      .doc(workspaceId)
      .collection("reportSummaries");

  let scanned = 0;
  let missing = 0;
  let written = 0;
  let skippedExisting = 0;
  const sampleMissingIds = [];
  /** @type {FirebaseFirestore.QueryDocumentSnapshot|null} */
  let cursor = null;

  while (scanned < maxDocs) {
    const pageSize = Math.min(batchSize, maxDocs - scanned);
    let query = reportsRef.orderBy("__name__").limit(pageSize);
    if (cursor) query = query.startAfter(cursor);

    const snap = await query.get();
    if (snap.empty) break;

    const pendingWrites = [];

    for (const doc of snap.docs) {
      scanned++;
      const summarySnap = await summariesRef.doc(doc.id).get();
      if (summarySnap.exists) {
        skippedExisting++;
        continue;
      }

      missing++;
      if (sampleMissingIds.length < 20) sampleMissingIds.push(doc.id);

      const payload = buildSummaryPayload(doc.id, doc.data() || {});
      if (!dryRun) {
        pendingWrites.push({
          ref: summariesRef.doc(doc.id),
          data: {
            ...payload,
            updatedAt: FieldValue.serverTimestamp(),
            backfilledAt: FieldValue.serverTimestamp(),
          },
        });
      }
    }

    if (!dryRun && pendingWrites.length > 0) {
      // Firestore batch max 500; pendingWrites ya acotado por pageSize.
      const batch = db.batch();
      for (const item of pendingWrites) {
        batch.set(item.ref, item.data, {merge: true});
      }
      await batch.commit();
      written += pendingWrites.length;
    }

    cursor = snap.docs[snap.docs.length - 1];
    if (snap.size < pageSize) break;
  }

  const result = {
    scanned,
    missing,
    written: dryRun ? 0 : written,
    skippedExisting,
    dryRun,
    sampleMissingIds,
  };
  logger.info("reportSummaryBackfill finished", result);
  return result;
}

module.exports = {
  buildSummaryPayload,
  runReportSummaryBackfill,
  toIsoDate,
};
