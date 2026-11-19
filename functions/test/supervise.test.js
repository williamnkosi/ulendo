"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const { PassThrough } = require("node:stream");
const { supervise } = require("../scripts/supervise");
const { localEnvironment } = require("../scripts/emulator-safety");
for (const mode of ["success", "failure", "spawn failure", "timeout", "SIGINT", "SIGTERM"]) {
  test("shared supervisor: " + mode, async () => {
    const log = new PassThrough();
    log.resume();
    const listeners = [process.listenerCount("SIGINT"), process.listenerCount("SIGTERM")];
    const abort = ["timeout", "SIGINT", "SIGTERM"].includes(mode);
    const script = abort ?
      "process.on('SIGTERM', () => process.exit(0)); console.log('ready'); setInterval(() => {}, 1000);" :
      "process.exit(" + (mode === "failure" ? 7 : 0) + ");";
    let pid;
    const execution = supervise(mode === "spawn failure" ? "/missing-ulendo-command" : process.execPath,
      ["-e", script], { env: localEnvironment() }, {
        log, timeoutMs: mode === "timeout" ? 500 : 5000, graceMs: 100,
        onSpawn: (child) => {
          pid = child.pid;
          if (mode.startsWith("SIG")) child.stdout.once("data", () => process.kill(process.pid, mode));
        },
      });
    if (mode === "spawn failure") await assert.rejects(execution, { code: "ENOENT" });
    else assert.equal(await execution, mode === "success" ? 0 : mode === "failure" ? 7 : 1);
    assert.deepEqual([process.listenerCount("SIGINT"), process.listenerCount("SIGTERM")], listeners);
    assert.ok(log.writableFinished);
    if (pid) assert.throws(() => process.kill(pid, 0), { code: "ESRCH" });
  });
}
