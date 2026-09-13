import { getApps, initializeApp, AppOptions } from "firebase-admin/app";

import * as functions from "firebase-functions/v1";
import * as logger from "firebase-functions/logger";

const appOptions: AppOptions = {
  databaseURL: "https://ulendo-dev-default-rtdb.firebaseio.com",
};

if (getApps().length === 0) {
  initializeApp(appOptions);
}

/**
 * Cloud Function triggered when
 *  a new active ride is created in the Realtime Database.
 * This function listens only to creation events (onCreate), not updates.
 *
 * Triggers on: /active_rides/{rideId}
 *
 * @param snapshot - The database snapshot containing the new ride data
 * @param context - Firebase context with function metadata
 *
 * @returns Promise<void>
 */
export const findAvailableDriverFunction = functions.database
  .ref("/active_rides/{rideId}")
  .onCreate((snapshot, context) => {
    const rideId = context.params.rideId;
    const rideData = snapshot.val();

    console.log(`[findAvailableDriver] New active ride created: ${rideId}`);
    logger.info(`New active ride created: ${rideId}`, {
      rideId,
      rideData,
    });

    return Promise.resolve();
  });
