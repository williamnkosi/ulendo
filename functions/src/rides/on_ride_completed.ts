import { getApps, initializeApp, AppOptions } from "firebase-admin/app";
import { getDatabase } from "firebase-admin/database";
import { getFirestore } from "firebase-admin/firestore";
import * as functions from "firebase-functions/v1";
import * as logger from "firebase-functions/logger";
import { RideData, RideStatusEnum } from "../types";

const appOptions: AppOptions = {
  databaseURL: "https://ulendo-dev-default-rtdb.firebaseio.com",
};

if (getApps().length === 0) {
  initializeApp(appOptions);
}

/**
 * Listen to active_rides in Realtime Database
 * When a ride's status changes to "completed",
 * store it in Firestore under the "rides" collection
 */
export const onRideCompletedFunction = functions.database
  .ref("/active_rides/{rideId}")
  .onUpdate(async (change, context) => {
    try {
      const rideId = context.params.rideId;
      const beforeData = change.before.val() as RideData | null;
      const afterData = change.after.val() as RideData | null;

      if (!afterData) {
        logger.warn("No ride data after update", { rideId });
        return;
      }

      // Check if status changed to COMPLETED
      if (afterData.status !== RideStatusEnum.COMPLETED) {
        logger.debug("Ride status not completed, skipping", {
          rideId,
          status: afterData.status,
        });
        return;
      }

      // Check if this is the transition to completed
      if (beforeData?.status === RideStatusEnum.COMPLETED) {
        logger.debug("Ride already marked as completed", { rideId });
        return;
      }

      logger.info("Ride completed, storing in Firestore", {
        rideId,
        previousStatus: beforeData?.status,
        currentStatus: afterData.status,
      });

      const db = getFirestore();
      const rtdb = getDatabase();
      const completedRideData = {
        ...afterData,
        rideId,
        completedAt: new Date(),
      };

      // Store the completed ride in Firestore
      await db.collection("rides").doc(rideId).set(completedRideData, {
        merge: true,
      });

      logger.info("Ride successfully stored in Firestore", {
        rideId,
        userId: afterData.userId,
      });

      // Delete the ride from active_rides in Realtime Database
      await rtdb.ref(`/active_rides/${rideId}`).remove();

      logger.info("Ride successfully removed from active_rides", {
        rideId,
      });
    } catch (error) {
      logger.error("Error processing completed ride", {
        error: error instanceof Error ? error.message : String(error),
        rideId: context.params.rideId,
      });
      throw error;
    }
  });
