"use strict";
const { test, before, after, beforeEach } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { ROOT, PROJECT, assertEmulatorTarget } = require("../../scripts/emulator-safety");
// Guard BEFORE importing SDKs or creating bypass/clear contexts.
assertEmulatorTarget(process.env);
const { initializeTestEnvironment, assertSucceeds } = require("@firebase/rules-unit-testing");
const { doc, getDoc, setDoc, deleteDoc, collection, getDocs } = require("firebase/firestore");
const { ref, get, set, remove } = require("firebase/database");
let env;
const owner = "driver-owner";
const actors = [{ name: "unauthenticated", uid: null }, { name: "unrelated", uid: "unrelated" }];
const ctx = (uid) => uid ? env.authenticatedContext(uid) : env.unauthenticatedContext();
async function denied(operation) {
  await assert.rejects(operation, (error) =>
    /^(permission-denied|PERMISSION_DENIED|database\/permission-denied)$/.test(error.code),
  "Expected actual permission-denied, not timeout/missing emulator/network error");
}
before(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT,
    database: { host: "127.0.0.1", port: 19000,
      rules: fs.readFileSync(path.join(ROOT, "database.rules.json"), "utf8") },
    firestore: { host: "127.0.0.1", port: 18080,
      rules: fs.readFileSync(path.join(ROOT, "firestore.rules"), "utf8") },
  });
});
beforeEach(async () => {
  assertEmulatorTarget(process.env);
  await env.clearDatabase();
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (admin) => {
    await set(ref(admin.database(), "drivers/" + owner), {
      status: "offline", location: { driverId: owner, latitude: 0, longitude: 0 },
    });
    await setDoc(doc(admin.firestore(), "users/" + owner), { name: "Synthetic owner" });
    await set(ref(admin.database(), "active_rides/legacy-synthetic"), {
      rideId: "legacy-synthetic", userId: "rider-owner", status: "pending",
      pickup: { lat: 0, lng: 0 }, dropoff: { lat: 1, lng: 1 },
    });
    for (const key of ["trip_state/rides/ride-one", "trip_state/riderActive/rider-owner",
      "trip_state/offers/offer-one", "trip_state/commandReceipts/rider-owner/cmd-one",
      "trip_state/work/work-one", "driver_presence/" + owner, "trip_locations/ride-one"]) {
      await set(ref(admin.database(), key), { synthetic: true });
    }
    await setDoc(doc(admin.firestore(), "rides/ride-one"), { synthetic: true });
    await setDoc(doc(admin.firestore(), "_rideHistoryCursors/cursor-one"), { synthetic: true });
  });
});
after(async () => {
  if (env) {
    try {
      assertEmulatorTarget(process.env);
      await env.clearDatabase();
      await env.clearFirestore();
    } finally {
      await env.cleanup();
    }
  }
});
test("Firestore owner positive read/write/delete control", async () => {
  const own = doc(ctx(owner).firestore(), "users/" + owner);
  await assertSucceeds(getDoc(own));
  await assertSucceeds(setDoc(own, { name: "Changed synthetic owner" }));
  await assertSucceeds(deleteDoc(own));
});
test("RTDB owner positive non-location read/write/delete control", async () => {
  const own = ref(ctx(owner).database(), "drivers/" + owner + "/status");
  await assertSucceeds(get(own));
  await assertSucceeds(set(own, "available"));
  await assertSucceeds(remove(own));
});
for (const actor of actors) {
  test("Firestore profile denies " + actor.name + " read/create-update/delete/list", async () => {
    const db = ctx(actor.uid).firestore();
    const profile = doc(db, "users/" + owner);
    await denied(getDoc(profile));
    await denied(setDoc(profile, { name: "Forbidden" }));
    await denied(deleteDoc(profile));
    await denied(getDocs(collection(db, "users")));
  });
  test("RTDB owner record denies " + actor.name + " read/write/delete/parent", async () => {
    const db = ctx(actor.uid).database();
    await denied(get(ref(db, "drivers/" + owner)));
    await denied(set(ref(db, "drivers/" + owner + "/status"), "forbidden"));
    await denied(remove(ref(db, "drivers/" + owner)));
    await denied(get(ref(db, "drivers")));
  });
  test("reserved v1 RTDB defaults deny " + actor.name + " individual and parent operations", async () => {
    const db = ctx(actor.uid).database();
    for (const key of ["trip_state/rides/ride-one", "trip_state/riderActive/rider-owner",
      "trip_state/offers/offer-one", "trip_state/commandReceipts/rider-owner/cmd-one",
      "trip_state/work/work-one", "driver_presence/" + owner, "trip_locations/ride-one"]) {
      await denied(get(ref(db, key)));
      await denied(set(ref(db, key), { synthetic: "forbidden" }));
      await denied(remove(ref(db, key)));
    }
    for (const key of ["trip_state", "driver_presence", "trip_locations"]) {
      await denied(get(ref(db, key)));
      await denied(set(ref(db, key), { forbidden: true }));
    }
  });
  test("reserved v1 Firestore defaults deny " + actor.name + " read/write/delete/list", async () => {
    const db = ctx(actor.uid).firestore();
    for (const name of ["rides", "_rideHistoryCursors"]) {
      const record = doc(db, name + "/" + (name === "rides" ? "ride-one" : "cursor-one"));
      await denied(getDoc(record));
      await denied(setDoc(record, { forbidden: true }));
      await denied(deleteDoc(record));
      await denied(getDocs(collection(db, name)));
    }
  });
}
test("KNOWN LEGACY LIMITATION: unrelated authenticated ride read/write and location child read are allowed", async () => {
  const db = ctx("unrelated").database();
  const ride = ref(db, "active_rides/legacy-synthetic");
  await assertSucceeds(get(ride));
  await assertSucceeds(set(ride, { rideId: "legacy-synthetic", userId: "rider-owner",
    status: "pending", pickup: { lat: 0, lng: 0 }, dropoff: { lat: 1, lng: 1 } }));
  await assertSucceeds(get(ref(db, "drivers/" + owner + "/location")));
});
