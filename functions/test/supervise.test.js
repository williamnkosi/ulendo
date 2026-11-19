"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const { PassThrough } = require("node:stream");
const { supervise } = require("../scripts/supervise");
const { localEnvironment } = require("../scripts/emulator-safety");
const { spawn } = require("node:child_process");
const net = require("node:net");
const path = require("node:path");
const listener = path.join(__dirname, "support/supervise-listener.js");
const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const absent = (pid) => {
  try {
    process.kill(pid, 0); return false;
  } catch (error) {
    if (error.code !== "ESRCH") throw error;
    return true;
  }
};
async function rebind(port) {
  const server = net.createServer();
  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(port, "127.0.0.1", resolve);
  });
  await new Promise((resolve) => server.close(resolve));
}
test("historical unreferenced detached-child leak is absent", { timeout: 5000 }, async () => {
  let pid;
  let anchor;
  const log = new PassThrough();
  log.resume();
  const script = "const {spawn}=require('node:child_process');" +
    "const c=spawn(process.execPath,['-e','setInterval(()=>{},1000)']," +
    "{detached:true,stdio:'ignore'});c.unref();console.log(c.pid);" +
    "process.on('SIGTERM',()=>process.exit(0));setInterval(()=>{},1000);";
  try {
    const status = await supervise(process.execPath, ["-e", script], { env: localEnvironment() }, {
      log, timeoutMs: 600, graceMs: 100,
      onSpawn: (child) => {
        anchor = child;
        child.stdout.once("data", (chunk) => {
          pid = Number(String(chunk).trim());
        });
      },
    });
    assert.equal(status, 1);
    assert.ok(Number.isInteger(pid) && pid > 0);
    assert.ok(absent(pid), "historical leaked grandchild gone before safety finalizer");
    assert.ok(log.writableFinished);
    console.log(JSON.stringify({ historicalReproduction: true, pid, status, cleaned: true }));
  } finally {
    if (pid && !absent(pid)) process.kill(pid, "SIGKILL");
    if (anchor && !absent(anchor.pid)) anchor.kill("SIGKILL");
  }
});
test("fork and execFile propagate containment across rapid CLI exit", { timeout: 7000 }, async () => {
  const bridgePath = path.join(__dirname, "support/supervise-bridge.js");
  const records = [];
  let anchor;
  let output = "";
  const log = new PassThrough();
  log.resume();
  const script = "const {fork}=require('node:child_process');" +
    "const c=fork(" + JSON.stringify(bridgePath) + ",[]," +
    "{detached:true,execArgv:[],stdio:['ignore','inherit','inherit','ipc']});" +
    "c.once('message',()=>process.exit(0));";
  try {
    const status = await supervise(process.execPath, ["-e", script], { env: localEnvironment() }, {
      log, timeoutMs: 3000, graceMs: 200,
      onSpawn: (child) => {
        anchor = child;
        child.stdout.on("data", (chunk) => {
          output += chunk;
          let newline;
          while ((newline = output.indexOf("\n")) >= 0) {
            records.push(JSON.parse(output.slice(0, newline)));
            output = output.slice(newline + 1);
          }
        });
      },
    });
    assert.equal(status, 0);
    assert.equal(records.length, 2, "both generations reached readiness before natural CLI exit");
    for (const record of records) {
      assert.equal(record.pgid, anchor.pid, "fork and execFile detach requests contained");
      assert.ok(absent(record.bridge || record.pid), "descendant absent before finalizer");
      if (record.port) await rebind(record.port);
    }
    assert.ok(absent(anchor.pid));
    assert.ok(log.writableFinished);
    console.log(JSON.stringify({ multiGeneration: records, anchor: anchor.pid, cleaned: true }));
  } finally {
    for (const record of records) {
      const pid = record.bridge || record.pid;
      if (!absent(pid)) process.kill(pid, "SIGKILL");
    }
    if (anchor && !absent(anchor.pid)) anchor.kill("SIGKILL");
  }
});
async function responds(port) {
  return new Promise((resolve, reject) => {
    const socket = net.connect(port, "127.0.0.1");
    socket.setTimeout(1000, () => socket.destroy(new Error("Listener response timed out")));
    socket.once("error", reject);
    socket.once("data", (data) => {
      socket.destroy(); resolve(String(data));
    });
  });
}
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
test("unsupported supervision target fails closed", async () => {
  const log = new PassThrough();
  log.resume();
  await assert.rejects(supervise("/bin/sh", ["-c", "exit 0"], {},
    { log, timeoutMs: 1000, graceMs: 100 }), /selected Node executable/);
  assert.ok(log.writableFinished);
});
for (const mode of ["timeout", "SIGINT", "SIGTERM", "unexpected exit", "natural zero", "immediate exit"]) {
  test("contained listening descendants: " + mode, { timeout: 10000 }, async () => {
    const unrelated = spawn(process.execPath, [listener],
      { env: localEnvironment(), detached: true, stdio: ["ignore", "ignore", "pipe", "ipc"] });
    unrelated.stderr.on("data", (chunk) => process.stderr.write(chunk));
    let identity;
    let anchor;
    let execution;
    const log = new PassThrough();
    log.resume();
    const listeners = [process.listenerCount("SIGINT"), process.listenerCount("SIGTERM")];
    const start = Date.now();
    try {
      const outsider = await new Promise((resolve, reject) => {
        const timer = setTimeout(() => reject(new Error("Unrelated listener readiness timed out")), 1500);
        unrelated.once("message", (value) => {
          clearTimeout(timer); resolve(value);
        });
        unrelated.once("error", (error) => {
          clearTimeout(timer); reject(error);
        });
        unrelated.once("exit", (code) => {
          clearTimeout(timer);
          reject(new Error("Unrelated listener exited: " + code));
        });
      });
      // The real requested detached child inherits stdout/stderr, then ignores
      // SIGTERM while holding a real listener. Immediate exit skips readiness.
      const script = "const {spawn}=require('node:child_process');" +
        "const c=spawn(process.execPath,[" + JSON.stringify(listener) + "]," +
        "{detached:true,stdio:['ignore','inherit','inherit','ipc']});" +
        (mode === "immediate exit" ? "console.log(JSON.stringify({spawned:c.pid}));process.exit(9);" :
          "c.on('message',()=>{" +
          (mode === "unexpected exit" ? "process.exit(9);" : mode === "natural zero" ? "process.exit(0);" : "") +
          "});setInterval(()=>{},1000);");
      let output = "";
      execution = supervise(process.execPath, ["-e", script], { env: localEnvironment() }, {
        log, timeoutMs: mode === "timeout" ? 800 : 3000, graceMs: 200,
        onSpawn: (child) => {
          anchor = child;
          child.stdout.on("data", (chunk) => {
            output += chunk;
            for (const line of output.split("\n").slice(0, -1)) {
              const record = JSON.parse(line);
              identity = record.spawned ? { pid: record.spawned } : record;
            }
            if (identity?.port && mode.startsWith("SIG")) process.kill(process.pid, mode);
          });
        },
      });
      assert.equal(await execution, mode === "natural zero" ? 0 : mode.includes("exit") ? 9 : 1);
      assert.ok(identity, "child exact PID recorded before root exit");
      if (mode !== "immediate exit") {
        assert.equal(identity.pgid, anchor.pid, "detached request remained in anchored group");
        assert.notEqual(outsider.pgid, anchor.pid);
        await rebind(identity.port);
      }
      assert.ok(absent(identity.pid), "owned descendant absent before safety finalizer");
      assert.ok(absent(anchor.pid), "ownership anchor reaped");
      assert.equal(await responds(outsider.port), "alive", "unrelated listener survives and responds");
      assert.ok(Date.now() - start < 5000, "cleanup completed within five-second test budget");
      assert.deepEqual([process.listenerCount("SIGINT"), process.listenerCount("SIGTERM")], listeners);
      assert.ok(log.writableFinished);
      console.log(JSON.stringify({ mode, owned: identity, anchor: anchor.pid, unrelated: outsider, cleaned: true }));
    } finally {
      // Exact fixture handles only, after assertions; never hide supervisor leaks.
      if (anchor && !absent(anchor.pid)) process.kill(anchor.pid, "SIGKILL");
      if (identity && !absent(identity.pid)) process.kill(identity.pid, "SIGKILL");
      if (!absent(unrelated.pid)) unrelated.kill("SIGKILL");
      await Promise.race([new Promise((resolve) => unrelated.once("exit", resolve)), wait(500)]);
      if (execution) await execution.catch(() => {});
    }
  });
}
