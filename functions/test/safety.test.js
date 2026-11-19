"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const { spawnSync } = require("node:child_process");
const { PROJECT, HOSTS, assertEmulatorTarget, assertNoConflictingTarget, shellQuote } = require("../scripts/emulator-safety");
test("runner rejects conflicting ambient endpoints instead of silently replacing them", () => {
  assert.throws(() => assertNoConflictingTarget({ GCLOUD_PROJECT: "ulendo-dev" }));
  assert.throws(() => assertNoConflictingTarget({ FIRESTORE_EMULATOR_HOST: "remote.invalid:8080" }));
});
test("emulators exec shell argument quoting preserves path metacharacters literally", () => {
  const value = "path with ' quotes $(printf injected) and `printf injected` $HOME";
  const result = spawnSync("/bin/sh", ["-c", "printf '%s' " + shellQuote(value)], { encoding: "utf8" });
  assert.equal(result.status, 0);
  assert.equal(result.stdout, value);
});
test("target guard allows only the dedicated demo and exact loopback ports", () => {
  assert.doesNotThrow(() => assertEmulatorTarget({ ...HOSTS, GCLOUD_PROJECT: PROJECT }));
});
for (const [label, changed] of [
  ["real project", { GCLOUD_PROJECT: "ulendo-dev" }],
  ["remote database", { FIREBASE_DATABASE_EMULATOR_HOST: "example.com:19000" }],
  ["wrong port", { FIRESTORE_EMULATOR_HOST: "127.0.0.1:8080" }],
  ["missing auth", { FIREBASE_AUTH_EMULATOR_HOST: undefined }],
  ["project mismatch", { GOOGLE_CLOUD_PROJECT: "demo-other" }],
]) {
  test("guard rejects " + label + " before SDK/reset callback", () => {
    let dataAccesses = 0;
    assert.throws(() => {
      assertEmulatorTarget({ ...HOSTS, GCLOUD_PROJECT: PROJECT, ...changed });
      dataAccesses++;
    });
    assert.equal(dataAccesses, 0);
  });
}
