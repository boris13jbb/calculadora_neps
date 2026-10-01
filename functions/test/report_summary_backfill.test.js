const test = require("node:test");
const assert = require("node:assert/strict");
const {
  buildSummaryPayload,
  toIsoDate,
} = require("../report_summary_backfill");

test("buildSummaryPayload empty records", () => {
  const payload = buildSummaryPayload("rep-1", {
    name: "Vacío",
    createdAt: "2026-01-01T10:00:00.000Z",
    createdByUid: "uid-a",
    records: [],
  });
  assert.equal(payload.id, "rep-1");
  assert.equal(payload.recordCount, 0);
  assert.equal(payload.recordsCreatedAtMin, undefined);
  assert.equal(payload.recordsCreatedAtMax, undefined);
  assert.equal(payload.createdByUid, "uid-a");
});

test("buildSummaryPayload computes min/max from records", () => {
  const payload = buildSummaryPayload("rep-2", {
    name: "Con datos",
    createdAt: "2026-02-01T08:00:00.000Z",
    records: [
      {createdAt: "2026-02-03T12:00:00.000Z"},
      {createdAt: "2026-02-01T09:00:00.000Z"},
      {createdAt: "2026-02-02T10:00:00.000Z"},
    ],
  });
  assert.equal(payload.recordCount, 3);
  assert.equal(payload.recordsCreatedAtMin, "2026-02-01T09:00:00.000Z");
  assert.equal(payload.recordsCreatedAtMax, "2026-02-03T12:00:00.000Z");
  assert.equal(Object.prototype.hasOwnProperty.call(payload, "records"), false);
});

test("toIsoDate tolerates Timestamp-like objects", () => {
  const iso = toIsoDate({
    toDate: () => new Date("2026-03-01T00:00:00.000Z"),
  });
  assert.equal(iso, "2026-03-01T00:00:00.000Z");
});
