import { getApps, initializeApp, AppOptions } from "firebase-admin/app";
import { getDatabase } from "firebase-admin/database";
import * as functions from "firebase-functions/v1";
import * as logger from "firebase-functions/logger";

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
}

/**
 * Validate ride request data
 * Checks that pickup and dropoff locations have valid lat, lng (numbers), and address (string)
 * @param data - The ride request data to validate
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
 * @returns Promise<RideRequestResponse> - Object with success status and message
 *
 * @throws HttpsError - "unauthenticated" if user is not authenticated
 * @throws HttpsError - "invalid-argument" if data validation fails
 */
export const requestRideFunction = functions.https.onCall(
  async (data: unknown, context) => {
    // Check if user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated to request a ride.",
      );
    }

    const userId: string = context.auth.uid;

    try {
      // Validate request data
      validateRideRequestData(data);
      logger.info("Ride request data validated", {
        userId,
        pickup: data.pickup.address,
        dropoff: data.dropoff.address,
      });

      const rtdb = getDatabase();

      // Generate unique ride ID
      const rideId = rtdb.ref("rides").push().key || "";
      if (!rideId) {
        throw new functions.https.HttpsError(
          "internal",
          "Failed to generate ride ID",
        );
      }
      logger.info("Generated rideId", { rideId });

      const response: RideRequestResponse = {
        success: true,
        message: "Ride request received successfully",
      };

      return response;
    } catch (error) {
      if (error instanceof functions.https.HttpsError) {
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
