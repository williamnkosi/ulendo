import { getApps, initializeApp, AppOptions } from "firebase-admin/app";
import { getDatabase } from "firebase-admin/database";
import * as functions from "firebase-functions/v1";
import * as logger from "firebase-functions/logger";
import { createRideRecord } from "../utils/create-ride-record";

const appOptions: AppOptions = {
  databaseURL: "https://ulendo-dev-default-rtdb.firebaseio.com",
};

if (getApps().length === 0) {
  initializeApp(appOptions);
}

interface Location {
  lat: number;
  lng: number;
  address: string;
}

interface RideRequestData {
  pickup: Location;
  dropoff: Location;
}

interface RideRequestResponse {
  success: boolean;
  message: string;
  rideId: string;
  pickup?: {
    lat: number;
    lng: number;
    address: string;
  };
  dropoff?: {
    lat: number;
    lng: number;
    address: string;
  };
}

/**
 * Validate ride request data
 * Checks that pickup and dropoff locations have valid
 * lat, lng (numbers), and address (string)
 * @param {unknown} data  - The ride request data to validate
 * @throws HttpsError if validation fails
 */
function validateRideRequestData(
  data: unknown,
): asserts data is RideRequestData {
  if (!data || typeof data !== "object") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Request data must be an object",
    );
  }

  const obj = data as Record<string, unknown>;

  // Validate pickup location
  if (!obj.pickup || typeof obj.pickup !== "object") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Pickup location is required and must be an object",
    );
  }

  const pickup = obj.pickup as Record<string, unknown>;

  if (typeof pickup.lat !== "number" || !Number.isFinite(pickup.lat)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Pickup latitude must be a valid number",
    );
  }

  if (typeof pickup.lng !== "number" || !Number.isFinite(pickup.lng)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Pickup longitude must be a valid number",
    );
  }

  if (typeof pickup.address !== "string" || pickup.address.trim() === "") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Pickup address is required and must be a non-empty string",
    );
  }

  // Validate dropoff location
  if (!obj.dropoff || typeof obj.dropoff !== "object") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Dropoff location is required and must be an object",
    );
  }

  const dropoff = obj.dropoff as Record<string, unknown>;

  if (typeof dropoff.lat !== "number" || !Number.isFinite(dropoff.lat)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Dropoff latitude must be a valid number",
    );
  }

  if (typeof dropoff.lng !== "number" || !Number.isFinite(dropoff.lng)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Dropoff longitude must be a valid number",
    );
  }

  if (typeof dropoff.address !== "string" || dropoff.address.trim() === "") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Dropoff address is required and must be a non-empty string",
    );
  }
}

/**
 * Cloud Function to handle ride requests from authenticated riders.
 *
 * @param data - The ride request data containing pickup and dropoff locations
 * @param context - Firebase context containing authentication info
 *
 * @returns Promise<RideRequestResponse> -
 * Object with success status and message
 *
 * @throws HttpsError - "unauthenticated" if user is not authenticated
 * @throws HttpsError - "invalid-argument" if data validation fails
 */
export const requestRideFunction = functions.https.onCall(
  async (data: unknown, context) => {
    logger.info("requestRideFunction called", { data });

    // Check if user is authenticated
    if (!context.auth) {
      logger.error("User not authenticated");
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated to request a ride.",
      );
    }

    const userId: string = context.auth.uid;
    logger.info("User authenticated", { userId });

    try {
      const rtdb = getDatabase();

      // Check if user already has an active ride
      const activeRideSnapshot = await rtdb.ref(`active_rides/${userId}`).get();
      if (activeRideSnapshot.exists()) {
        logger.warn("User already has an active ride", { userId });
        throw new functions.https.HttpsError(
          "failed-precondition",
          "You already have an active ride. Please complete or cancel " +
            "it before requesting a new one.",
        );
      }
      logger.info("No active ride found for user", { userId });

      // Validate request data
      validateRideRequestData(data);
      logger.info("Ride request data validated", {
        userId,
        pickup: data.pickup.address,
        dropoff: data.dropoff.address,
      });

      // Generate unique ride ID
      const rideIdRef = rtdb.ref("rides").push();
      const rideId = rideIdRef.key;
      if (!rideId) {
        logger.error("Failed to generate ride ID");
        throw new functions.https.HttpsError(
          "internal",
          "Failed to generate ride ID",
        );
      }
      logger.info("Generated rideId", { rideId });

      // Create ride record with pickup and dropoff data
      const rideRecord = createRideRecord(
        data.pickup.lat,
        data.pickup.lng,
        data.pickup.address,
        data.dropoff.lat,
        data.dropoff.lng,
        data.dropoff.address,
        userId,
        rideId,
      );
      logger.info("Ride record created", { rideRecord });

      // Save ride record to database under active_rides/{userId}
      await rtdb.ref(`active_rides/${userId}`).set(rideRecord);
      logger.info("Ride record saved to active_rides", { userId, rideId });

      // Ensure response is plain JSON-serializable object with all data
      const response: RideRequestResponse = {
        success: true,
        message: "Ride request received successfully",
        rideId: String(rideId),
        pickup: {
          lat: Number(data.pickup.lat),
          lng: Number(data.pickup.lng),
          address: String(data.pickup.address),
        },
        dropoff: {
          lat: Number(data.dropoff.lat),
          lng: Number(data.dropoff.lng),
          address: String(data.dropoff.address),
        },
      };

      logger.info("Returning success response", response);
      return response;
    } catch (error) {
      logger.error("Caught error in try block", { error });

      if (error instanceof functions.https.HttpsError) {
        logger.error("Rethrowing HttpsError", {
          code: error.code,
          message: error.message,
        });
        throw error;
      }

      const msg = error instanceof Error ? error.message : String(error);
      logger.error("Error processing ride request", { userId, error: msg });

      throw new functions.https.HttpsError(
        "internal",
        msg || "Failed to process ride request",
      );
    }
  },
);
