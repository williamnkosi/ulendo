"use strict";
const net = require("node:net");
const { spawnSync } = require("node:child_process");
process.on("SIGTERM", () => {});
const group = spawnSync("/bin/ps", ["-o", "pgid=", "-p", String(process.pid)], { encoding: "utf8" });
if (group.status !== 0) throw new Error("Cannot inspect fixture group: " + group.stderr);
const server = net.createServer((socket) => socket.end("alive"));
server.listen(Number(process.argv[2] || 0), "127.0.0.1", () => {
  const identity = { pid: process.pid, pgid: Number(group.stdout.trim()), port: server.address().port };
  console.log(JSON.stringify(identity));
  if (process.send) process.send(identity);
});
