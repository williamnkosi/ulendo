"use strict";
const { execFile, spawnSync } = require("node:child_process");
const path = require("node:path");
process.on("SIGTERM", () => {});
const group = spawnSync("/bin/ps", ["-o", "pgid=", "-p", String(process.pid)], { encoding: "utf8" });
if (group.status !== 0) throw new Error("Cannot inspect bridge group");
console.log(JSON.stringify({ bridge: process.pid, pgid: Number(group.stdout.trim()) }));
const child = execFile(process.execPath, [path.join(__dirname, "supervise-listener.js")],
  { detached: true });
child.stdout.pipe(process.stdout);
child.stderr.pipe(process.stderr);
child.stdout.once("data", () => process.send("ready"));
