"use strict";
const { spawn } = require("node:child_process");
async function supervise(command, args, options, { log, timeoutMs, graceMs, onSpawn = () => {} }) {
  let child;
  let aborted = false;
  let killTimer;
  let timeout;
  const stop = (signal) => {
    if (!child?.pid) return;
    try {
      process.kill(-child.pid, signal);
    } catch (error) {
      if (error.code !== "ESRCH") throw error;
    }
  };
  const terminate = () => {
    aborted = true;
    stop("SIGTERM");
    if (!killTimer) killTimer = setTimeout(() => stop("SIGKILL"), graceMs);
  };
  try {
    child = spawn(command, args, { ...options, detached: true, stdio: ["ignore", "pipe", "pipe"] });
    for (const stream of [child.stdout, child.stderr]) {
      stream.on("data", (chunk) => {
        log.write(chunk); process.stdout.write(chunk);
      });
    }
    process.once("SIGINT", terminate);
    process.once("SIGTERM", terminate);
    timeout = setTimeout(terminate, timeoutMs);
    const status = await new Promise((resolve, reject) => {
      child.once("error", reject);
      child.once("close", resolve);
      child.once("spawn", () => onSpawn(child));
    });
    return aborted || status === null ? 1 : status;
  } finally {
    clearTimeout(timeout);
    clearTimeout(killTimer);
    stop("SIGKILL");
    process.removeListener("SIGINT", terminate);
    process.removeListener("SIGTERM", terminate);
    await new Promise((resolve) => log.end(resolve));
  }
}
module.exports = { supervise };
