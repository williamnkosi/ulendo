"use strict";
const { spawn } = require("node:child_process");
const fs = require("node:fs");
const path = require("node:path");
const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
async function supervise(command, args, options, { log, timeoutMs, graceMs, onSpawn = () => {} }) {
  let child;
  let aborted = false;
  let timeout;
  let exit;
  let alive = false;
  let status;
  let finish;
  const completion = new Promise((resolve) => {
    finish = resolve;
  });
  const stop = (signal) => {
    if (!alive) return;
    try {
      process.kill(-child.pid, signal);
    } catch (error) {
      if (error.code !== "ESRCH") throw error;
    }
  };
  const terminate = () => {
    aborted = true; finish({ status: 1 });
  };
  const cleanup = async () => {
    if (!alive) return;
    stop("SIGTERM");
    await delay(graceMs);
    // The live anchor prevents group-ID reuse until this final signal.
    stop("SIGKILL");
    const deadline = Date.now() + 1000;
    let gone = false;
    do {
      try {
        process.kill(-child.pid, 0);
      } catch (error) {
        if (error.code === "ESRCH") {
          gone = true;
          break;
        }
        // macOS can transiently report EPERM while killed/reparented group
        // members are being reaped. It is never evidence of successful cleanup:
        // require a later ESRCH, otherwise fail within the same fixed budget.
        if (error.code !== "EPERM") throw error;
      }
      await delay(20);
    } while (Date.now() < deadline);
    if (!gone) throw new Error("Owned group survived cleanup budget");
    await exit;
  };
  try {
    // No generic executable promises: containment requires a trusted Node CLI.
    if (fs.realpathSync(command) !== fs.realpathSync(process.execPath)) {
      throw new Error("Supervision supports only the selected Node executable");
    }
    child = spawn(process.execPath, [path.join(__dirname, "supervise-anchor.js")],
      { ...options, detached: true, stdio: ["ignore", "pipe", "pipe", "ipc"] });
    exit = new Promise((resolve) => child.once("exit", () => {
      alive = false; resolve();
    }));
    child.once("error", (error) => finish({ error }));
    child.once("exit", () => finish({ status: 1 }));
    child.once("message", finish);
    for (const stream of [child.stdout, child.stderr]) {
      stream.on("data", (chunk) => {
        log.write(chunk); process.stdout.write(chunk);
      });
    }
    process.once("SIGINT", terminate);
    process.once("SIGTERM", terminate);
    timeout = setTimeout(terminate, timeoutMs);
    child.once("spawn", () => {
      alive = true;
      child.send({ command, args, options });
      onSpawn(child);
    });
    const result = await completion;
    if (result.error) throw Object.assign(new Error(result.error.message || result.error), { code: result.code });
    status = result.status;
  } finally {
    clearTimeout(timeout);
    try {
      await cleanup();
    } finally {
      process.removeListener("SIGINT", terminate);
      process.removeListener("SIGTERM", terminate);
      child?.stdout.destroy();
      child?.stderr.destroy();
      if (child?.connected) child.disconnect();
      await new Promise((resolve) => log.end(resolve));
    }
  }
  return aborted || status === null ? 1 : status;
}
module.exports = { supervise };
