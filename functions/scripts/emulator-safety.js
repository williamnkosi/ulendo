"use strict";
const path = require("node:path");
const fs = require("node:fs");
const ROOT = path.resolve(__dirname, "../..");
const PROJECT = "demo-ulendo-rules";
const HOSTS = {
  FIREBASE_AUTH_EMULATOR_HOST: "127.0.0.1:19099",
  FIREBASE_DATABASE_EMULATOR_HOST: "127.0.0.1:19000",
  FIRESTORE_EMULATOR_HOST: "127.0.0.1:18080",
};
function assertEmulatorTarget(env) {
  if (env.GCLOUD_PROJECT !== PROJECT || !env.GCLOUD_PROJECT.startsWith("demo-")) {
    throw new Error("Refusing non-test project; expected " + PROJECT);
  }
  for (const [name, value] of Object.entries(HOSTS)) {
    if (env[name] !== value) throw new Error("Refusing missing/unsafe " + name);
  }
  if (env.GOOGLE_CLOUD_PROJECT && env.GOOGLE_CLOUD_PROJECT !== PROJECT) {
    throw new Error("Conflicting project identity");
  }
}
function shellQuote(value) {
  return "'" + value.replace(/'/g, "'\\''") + "'";
}
function assertNoConflictingTarget(incoming) {
  for (const [name, value] of Object.entries({ ...HOSTS, GCLOUD_PROJECT: PROJECT, GOOGLE_CLOUD_PROJECT: PROJECT })) {
    if (incoming[name] !== undefined && incoming[name] !== value) {
      throw new Error("Refusing conflicting environment " + name);
    }
  }
}
function localEnvironment() {
  assertNoConflictingTarget(process.env);
  const cache = path.join(ROOT, ".cache/backend-tests");
  // PATH selects Node and Java. No other ambient runtime settings are needed.
  const env = { PATH: process.env.PATH, LANG: "en_US.UTF-8", ...HOSTS, GCLOUD_PROJECT: PROJECT,
    GOOGLE_CLOUD_PROJECT: PROJECT, CI: "true",
    FIREBASE_CLI_DISABLE_USAGE_REPORTING: "true", NO_UPDATE_NOTIFIER: "1",
    npm_config_cache: path.join(cache, "npm"),
    FIREBASE_EMULATORS_PATH: path.join(cache, "emulators"),
    XDG_CONFIG_HOME: path.join(cache, "config"),
    XDG_CACHE_HOME: path.join(cache, "xdg"),
    XDG_DATA_HOME: path.join(cache, "data"),
    TMPDIR: path.join(cache, "tmp"), TMP: path.join(cache, "tmp"),
    TEMP: path.join(cache, "tmp"),
  };
  for (const key of ["npm_config_cache", "FIREBASE_EMULATORS_PATH",
    "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "XDG_DATA_HOME", "TMPDIR"]) {
    fs.mkdirSync(env[key], { recursive: true });
  }
  env.JAVA_TOOL_OPTIONS = [
    "-Djava.io.tmpdir=" + env.TMPDIR,
    "-Duser.home=" + path.join(cache, "java"),
    "-Djava.util.prefs.userRoot=" + path.join(cache, "java/prefs"),
    "-Djava.util.prefs.systemRoot=" + path.join(cache, "java/system-prefs"),
    "-XX:-UsePerfData",
  ].join(" ");
  fs.mkdirSync(path.join(cache, "java"), { recursive: true });
  return env;
}
module.exports = { ROOT, PROJECT, HOSTS, assertEmulatorTarget, assertNoConflictingTarget, shellQuote, localEnvironment };
