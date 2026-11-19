"use strict";
const assert = require("node:assert/strict");
async function denied(operation) {
  await assert.rejects(operation, (error) =>
    /^(permission-denied|PERMISSION_DENIED|database\/permission-denied)$/.test(error.code),
  "Expected actual permission-denied, not timeout/missing emulator/network error");
}
module.exports = { denied };
