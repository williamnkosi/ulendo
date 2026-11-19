"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const fixtures = require("./fixtures/trip-contract-v1.json");
const document = fs.readFileSync(path.resolve(__dirname, "../../docs/trip-contract-v1.md"), "utf8");
test("all 57 approved contract JSON rows match committed fixtures exactly", () => {
  const rows = [...document.matchAll(/\x60\x60\x60json\n([\s\S]*?)\x60\x60\x60/g)]
    .flatMap((block) => block[1].trim().split("\n").map((line) => JSON.parse(line)));
  assert.equal(rows.length, 57);
  assert.deepEqual(fixtures.map((fixture) => fixture.value), rows);
  assert.equal(new Set(fixtures.map((fixture) => fixture.id)).size, 57);
  for (const fixture of fixtures) assert.match(fixture.section, /^(5a|5b|5c|9b|9c)$/);
});
test("representative restoration, immutable replay and publisher-order fixtures preserve identity", () => {
  const values = fixtures.map((fixture) => fixture.value);
  const rider = values.find((value) => value.response?.activeTrip?.riderId === "u-dual");
  assert.equal(rider.response.sessionRole, "rider");
  assert.equal(rider.response.activeTrip.rideId, "r1");
  const first = values.find((value) => value.case === "online-first");
  const replay = values.find((value) => value.case === "online-replay-after-newer-offline");
  assert.deepEqual(first.response.committed, replay.response.committed);
  const sample = values.find((value) => value.case === "first-sample");
  const duplicate = values.find((value) => value.case === "same-sample-replay");
  assert.equal(sample.response.acceptedAt, duplicate.response.acceptedAt);
  assert.equal(sample.response.locationValidUntil, duplicate.response.locationValidUntil);
  const reset = values.find((value) => value.case === "client-projection-generation-reset");
  assert.equal(reset.expected.acceptIncomingOrder, true);
  assert.ok(reset.given.incoming.publisherGeneration > reset.given.current.publisherGeneration);
});
