"use strict";
const { spawn } = require("node:child_process");
const path = require("node:path");
// Remain group leader through cleanup, even after CLI exit/reparenting.
process.on("SIGTERM", () => {});
process.on("SIGINT", () => {});
process.on("disconnect", () => process.kill(-process.pid, "SIGKILL"));
process.once("message", ({ command, args, options }) => {
  const child = spawn(command, ["--require", path.join(__dirname, "contain-children.js"), ...args],
    { ...options, detached: false, stdio: ["ignore", "inherit", "inherit"] });
  child.once("error", (error) => process.send({ error: error.message, code: error.code }));
  child.once("exit", (status) => process.send({ status }));
});
