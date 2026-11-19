# Backend fixture and emulator tests

F01 adds a test harness, not v1 command/worker/participant-read implementation. It loads the **actual root** database.rules.json and firestore.rules. Production rules, firebase.json, .firebaserc and functions/src are unchanged. No deployment, login, Functions/Hosting emulator, FCM, production imports or production project is used.

## Prerequisites and local setup

Use Node **20.19+ within major 20** (not Node 23), npm 10+ compatible with that runtime, and Java 21+ on PATH. Keep any downloaded runtimes inside this repository, for example .cache/backend-tests/node/bin; do not install globally. The runner fails before emulator/SDK activity for an unsupported runtime. A missing prerequisite is a failure/blocker, not a skipped passing test.

Run from repository root in a shell with the selected Node 20 and Java already on PATH. Set local writable paths **before npm**, including installation:

```sh
export npm_config_cache="$PWD/.cache/backend-tests/npm"
export TMPDIR="$PWD/.cache/backend-tests/tmp"
mkdir -p "$npm_config_cache" "$TMPDIR"
npm --prefix functions ci --ignore-scripts --no-audit --no-fund
npm --prefix functions run test:fixtures
npm --prefix functions run test:guards
npm --prefix functions run lint
npm --prefix functions run build
npm --prefix functions run test:emulators
npm --prefix functions run test:emulators
```

The committed lock pins firebase-tools 15.28.2, @firebase/rules-unit-testing 5.0.1 and Firebase client SDK 12.14.0. CLI-scoped overrides pin cloud-sql-connector 1.10.0 and universal-analytics 0.5.3 because their otherwise-compatible broad ranges now resolve Node 22-only packages. Optional native re2 is pinned to 1.24.0 (its declared engine is unrestricted), and lifecycle install scripts are disabled as shown. Do not omit all optional packages: firebase-admin uses its optional Firestore SDK during TypeScript compilation. These emulator services do not use re2 native matching. Production dependencies are unchanged. Metadata/engine compatibility is not a substitute for executing under Node 20.

The pinned CLI's lib/emulator/downloadableEmulatorInfo.json specifies:

| Binary | Version | SHA-256 |
| --- | --- | --- |
| cloud-firestore-emulator-v1.22.0.jar | 1.22.0 | 9b6498b7f62714d67f48f59b3818883cd682dbcd46b9f59511de81c97bb5166c |
| firebase-database-emulator-v4.11.2.jar | 4.11.2 | b70d99344caf17c98b6f910fa8f6edf32a7c016cb1035e8915f70d38901eb97f |

Prepopulate .cache/backend-tests/emulators/ with these two exact JAR files, either copying readable existing binaries **into** the project or downloading the remoteUrl entries in that pinned metadata to this directory. The runner verifies SHA-256 and refuses missing/corrupt files; it does not silently download an unpinned binary. The Auth emulator is bundled with the CLI. Offline operation works after npm ci has populated dependencies and the verified JARs exist; an offline clean install additionally needs the complete local npm cache. Do not point writable caches at a shared/personal directory.

Version/override behavior was checked against installed package sources: CLI package.json engines, lib/emulator/downloadableEmulators.js (FIREBASE_EMULATORS_PATH), lib/emulator/commandUtils.js (Java 21), configstore/index.js and xdg-basedir/index.js (XDG_CONFIG_HOME). Preserve these checks when upgrading the CLI. Do not assume only XDG_CACHE_HOME redirects every CLI cache.

## Isolation and fail-closed behavior

The single emulator command uses locked local node_modules, explicit project demo-ulendo-rules, and firebase.test.json. It ignores the real .firebaserc default. Dedicated loopback ports: Auth 19099, RTDB 19000, Firestore 18080, hub 14400 and logging 14500. UI is disabled. Occupied ports or changed/missing endpoints fail; no fallback to a remote endpoint or production default is allowed. The runner rejects conflicting ambient project/emulator-host variables instead of silently replacing them. The test module checks the exact project and all three hosts **before importing SDKs**, seeding or clearing data.

All generated data, logs and caches are ignored under .cache/backend-tests/ and .artifacts/backend-tests/. The runner redirects npm cache, TMPDIR/TMP/TEMP, FIREBASE_EMULATORS_PATH, XDG config/cache/data, and Java temp/user home/preferences/performance data; HOME/CODEX_HOME are not changed. It constructs the child environment from an allowlist: the selected executable PATH, fixed locale, explicit demo endpoints and project-local cache/temp/config/JVM settings. All other inherited variables, including HOME, CODEX_HOME and unknown credential names, are absent from CLI/script children; the invoking environment is unchanged. The pinned CLI logs its script environment, so this boundary also protects debug logs. XDG_CONFIG_HOME is honored by configstore/xdg-basedir; FIREBASE_EMULATORS_PATH prevents the CLI home-directory cache fallback, and JAVA_TOOL_OPTIONS replaces JVM home/temp/preferences fallbacks. It starts the CLI from a per-run artifact directory, records harness.log, forwards natural exit status and forces nonzero after any timeout/SIGINT/SIGTERM, even if the child exits zero, and terminates its process group on completion, signals, spawn errors or a 180s timeout (5s termination grace). CLI/JVM logs belong in the artifact directory. No credentials or production dataset are required or imported.

Tests use rules-unit-testing synthetic authenticated claims for driver-owner/unrelated and an unauthenticated context. **They do not exercise Auth-emulator sign-in.** The Auth emulator is started and endpoint-guarded as part of the isolated stack; later authentication integration tests can use it. Deterministic synthetic state is cleared and seeded serially before each test, with final clear/cleanup. Security-disabled contexts are used only for arranging/clearing fixtures; every permission assertion uses a client owner/other/unauthenticated context. RTDB reads use one-shot onValue with its cancellation callback, which preserves the permission code lost by the pinned get() rejection path. Permission-denied must be the actual SDK error code: a missing emulator, connection error or timeout cannot count as denial.

## What the suites establish

- test:fixtures: two built-in Node tests compare all **57** exact JSON contract objects to committed stable section/index fixture IDs and check representative role identity, immutable online replay, duplicate sample deadlines and publisher-generation ordering. No emulator/network or v1 validator is involved.
- test:guards: executable fail-closed project/endpoint checks, synthetic credential/log isolation, strict denial classification and real subprocess supervision (natural success/failure, spawn failure, timeout and both interruption signals); shell argument escaping; the invalid-target path cannot reach its SDK/reset callback.
- test:emulators: current Firestore users ownership positive/read/write/delete controls and unauthenticated/unrelated denial; current RTDB drivers owner non-location positive controls and unauthenticated/unrelated record/field denials; reserved-v1 individual/parent/list/delete default denials in both stores.
- A clearly named **KNOWN LEGACY LIMITATION** test succeeds when unrelated authenticated clients can read/write legacy active_rides and read another driver's location child. These are existing broad grants, not authorization-denial evidence or a hardening change.

Reserved trip_state/driver_presence/trip_locations/Firestore rides/cursor paths are currently default-denied, including intended owners. F05/O01/R05/L05 must add positive participant policies and their tests with implementation. The approved 103-scenario pilot matrix remains unexecuted by F01; these baseline rule tests do not claim trip lifecycle, telemetry, history, load/capacity or device conformance.

## Evidence and blocked runs

Each completed emulator run prints its artifact directory and test counts. Run twice consecutively after clean teardown to demonstrate port/data isolation. Record failures and logs; do not treat preflight success, fixture syntax or a generic rejected promise as emulator conformance. F02 must separately measure the shared transaction/root projection contention and admission bounds; no pilot capacity is asserted here.

Historical runs used Node 23.11.0 with Java 23.0.2 and lacked supported-runtime acceptance. The current revision found Node 20.20.2 selected with Java 23.0.2, reused locked dependencies and verified project-local JAR checksums. Its emulator preflight reached the loopback bind check, which the sandbox denied (EPERM); the subsequent execution permission request was canceled. A subsequent parent-run invocation with approved loopback execution passed all 11 real rules tests under Node 20.20.2. The tester must still independently complete the required consecutive pair and verify cleanup; see run 2026-11-19-f01-harness-04 evidence. Pure fixture/guard/static checks performed on Node 23 are diagnostic evidence only. See pipeline handoffs for actual attempts; this document does not declare unexecuted checks passing.
