"use strict";
const { ChildProcess } = require("node:child_process");
const originalSpawn = ChildProcess.prototype.spawn;
const preload = "--require=" + JSON.stringify(__filename);
// Trusted Node launchers only. Covers spawn/exec/fork, including explicit detach.
ChildProcess.prototype.spawn = function(options) {
  options.detached = false;
  const index = options.envPairs.findIndex((entry) => entry.startsWith("NODE_OPTIONS="));
  const previous = index < 0 ? "" : options.envPairs[index].slice("NODE_OPTIONS=".length);
  const value = "NODE_OPTIONS=" + (previous.includes(preload) ? previous : (preload + " " + previous).trim());
  if (index < 0) options.envPairs.push(value);
  else options.envPairs[index] = value;
  return originalSpawn.call(this, options);
};
