"use strict";
const fs = require("node:fs");
const path = require("node:path");
const net = require("node:net");
const crypto = require("node:crypto");
const { spawnSync } = require("node:child_process");
const { ROOT, PROJECT, localEnvironment, assertEmulatorTarget, shellQuote } = require("./emulator-safety");
const { supervise } = require("./supervise");
async function main() {
  const env = localEnvironment();
  assertEmulatorTarget(env);
  if (process.versions.node.split(".")[0] !== "20" || Number(process.versions.node.split(".")[1]) < 19) {
    throw new Error("Node 20.19+ is required; select a Node 20 executable on PATH (found " + process.version + ")");
  }
  const cli = path.join(ROOT, "functions/node_modules/firebase-tools");
  const pkg = JSON.parse(fs.readFileSync(path.join(cli, "package.json")));
  if (pkg.version !== "15.28.2") throw new Error("Run npm ci: expected locked firebase-tools 15.28.2");
  for (const [name, version] of [["@firebase/rules-unit-testing", "5.0.1"], ["firebase", "12.14.0"]]) {
    const metadata = JSON.parse(fs.readFileSync(path.join(ROOT, "functions/node_modules", name, "package.json")));
    if (metadata.version !== version) throw new Error("Run npm ci: incompatible " + name);
  }
  const java = spawnSync("java", ["-version"], { env, encoding: "utf8" });
  const version = (java.stderr + java.stdout).match(/version "(\d+)/);
  if (java.status !== 0 || !version || Number(version[1]) < 21) {
    throw new Error("Java 21+ is required on PATH; see docs/backend-testing.md");
  }
  const info = JSON.parse(fs.readFileSync(path.join(cli, "lib/emulator/downloadableEmulatorInfo.json")));
  for (const name of ["firestore", "database"]) {
    const binary = path.join(env.FIREBASE_EMULATORS_PATH, info[name].downloadPathRelativeToCacheDir);
    const digest = crypto.createHash("sha256").update(fs.readFileSync(binary)).digest("hex");
    if (digest !== info[name].expectedChecksumSHA256) throw new Error("Missing/corrupt emulator binary: " + binary);
  }
  const config = JSON.parse(fs.readFileSync(path.join(ROOT, "firebase.test.json")));
  if (config.functions || config.hosting || config.database.rules !== "database.rules.json" ||
      config.firestore.rules !== "firestore.rules") throw new Error("Unsafe test config");
  for (const [name, port] of Object.entries({ auth: 19099, database: 19000, firestore: 18080, hub: 14400, logging: 14500 })) {
    if (config.emulators[name]?.host !== "127.0.0.1" || config.emulators[name]?.port !== port) {
      throw new Error("Unsafe emulator endpoint: " + name);
    }
  }
  for (const entry of Object.values(config.emulators)) {
    if (entry && entry.port) {
      if (entry.host !== "127.0.0.1") throw new Error("Test emulator must bind loopback");
      await new Promise((resolve, reject) => {
        const server = net.createServer();
        server.once("error", reject);
        server.listen(entry.port, "127.0.0.1", () => server.close(resolve));
      });
    }
  }
  const artifact = path.join(ROOT, ".artifacts/backend-tests", new Date().toISOString().replace(/[:.]/g, "-"));
  fs.mkdirSync(artifact, { recursive: true });
  // Run from an artifact directory so CLI/JVM logs cannot escape the project.
  const log = fs.createWriteStream(path.join(artifact, "harness.log"));
  const testCommand = shellQuote(process.execPath) + " --test --test-concurrency=1 " +
    shellQuote(path.join(ROOT, "functions/test/rules/current-rules.test.js"));
  const code = await supervise(process.execPath, [path.join(cli, "lib/bin/firebase.js"),
    "emulators:exec", "--only", "auth,database,firestore", "--project", PROJECT,
    "--config", path.join(ROOT, "firebase.test.json"), "--non-interactive", testCommand],
  { cwd: artifact, env }, { log, timeoutMs: 180000, graceMs: 5000 });
  console.log("Artifacts: " + artifact);
  process.exitCode = code;
}
main().catch((error) => {
  console.error(error.message); process.exitCode = 1;
});
