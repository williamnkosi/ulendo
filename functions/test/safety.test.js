"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const { spawnSync } = require("node:child_process");
const fs = require("node:fs");
const path = require("node:path");
const { localEnvironment, ROOT } = require("../scripts/emulator-safety");
const { denied } = require("./support/denied");
test("denial classification rejects infrastructure and unknown failures", async () => {
  for (const code of ["permission-denied", "PERMISSION_DENIED", "database/permission-denied"]) {
    await denied(Promise.reject(Object.assign(new Error("denied"), { code })));
  }
  for (const code of ["ETIMEDOUT", "ECONNREFUSED", "unavailable", "unknown", undefined]) {
    await assert.rejects(denied(Promise.reject(Object.assign(new Error("Permission denied"), { code }))));
  }
  await assert.rejects(denied(Promise.resolve()));
});
test("allowlisted child environment and logs exclude synthetic credentials without mutating parent", () => {
  const keys = ["GOOGLE_APPLICATION_CREDENTIALS", "NPM_TOKEN", "GITHUB_TOKEN", "OPENAI_API_KEY",
    "AWS_SECRET_ACCESS_KEY", "UNRECOGNIZED_CREDENTIAL"];
  const saved = keys.map((key) => process.env[key]);
  try {
    keys.forEach((key, i) => {
      process.env[key] = "synthetic-secret-marker-" + i;
    });
    const env = localEnvironment();
    const result = spawnSync(process.execPath, ["-e", "console.log(JSON.stringify(process.env))"], { env, encoding: "utf8" });
    assert.equal(result.status, 0);
    const artifact = path.join(ROOT, ".artifacts/backend-tests/credential-regression");
    fs.mkdirSync(artifact, { recursive: true });
    const log = path.join(artifact, "child.log");
    fs.writeFileSync(log, result.stdout + result.stderr);
    assert.doesNotMatch(fs.readFileSync(log, "utf8"), /synthetic-secret-marker/);
    keys.forEach((key, i) => {
      assert.equal(env[key], undefined);
      assert.equal(process.env[key], "synthetic-secret-marker-" + i);
    });
    for (const key of ["TMPDIR", "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "FIREBASE_EMULATORS_PATH"]) {
      assert.ok(env[key].startsWith(ROOT + path.sep));
    }
    assert.equal(env.HOME, undefined);
    assert.equal(env.CODEX_HOME, undefined);
  } finally {
    keys.forEach((key, i) => {
      if (saved[i] === undefined) delete process.env[key];
      else process.env[key] = saved[i];
    });
  }
});
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
