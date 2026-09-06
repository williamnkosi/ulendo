import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import * as functions from "firebase-functions/v1";
import * as logger from "firebase-functions/logger";

if (getApps().length === 0) {
  initializeApp();
}

const db = getFirestore();

// Type definitions for strong typing
interface Location {
  lat: number;
  lng: number;
  address: string;
}

interface RideRequestData {
  pickup: Location;
  dropoff: Location;
}

type RideStatus =
  | "requested"
  | "accepted"
  | "in_progress"
  | "completed"
  | "cancelled";

interface RideDocument {
  riderId: string;
  pickup: Location;
  dropoff: Location;
  status: RideStatus;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

interface RideRequestResponse {
  success: boolean;
  rideId: string;
  message: string;
  data: RideDocument;
}

export const requestRideFunction = functions.https.onCall(
  async (data: RideRequestData, context) => {
    // Check if user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated to request a ride.",
      );
    }

    const userId: string = context.auth.uid;

    try {
      // Validate required fields
      if (
        !data.pickup ||
        typeof data.pickup.lat !== "number" ||
        typeof data.pickup.lng !== "number" ||
        typeof data.pickup.address !== "string"
      ) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Missing or invalid pickup location data",
        );
      }

      if (
        !data.dropoff ||
        typeof data.dropoff.lat !== "number" ||
        typeof data.dropoff.lng !== "number" ||
        typeof data.dropoff.address !== "string"
      ) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Missing or invalid dropoff location data",
        );
      }

      // Create ride request object with proper typing
      const now: Timestamp = Timestamp.now();
      const rideRequest: RideDocument = {
        riderId: userId,
        pickup: {
          lat: data.pickup.lat,
          lng: data.pickup.lng,
          address: data.pickup.address,
        },
        dropoff: {
          lat: data.dropoff.lat,
          lng: data.dropoff.lng,
          address: data.dropoff.address,
        },
        status: "requested",
        createdAt: now,
        updatedAt: now,
      };

      // Save ride request to Firestore
      const rideRequestRef = await db.collection("rides").add(rideRequest);

      logger.info("Ride request created successfully", {
        rideId: rideRequestRef.id,
        riderId: userId,
        pickup: data.pickup.address,
        dropoff: data.dropoff.address,
      });

      const response: RideRequestResponse = {
        success: true,
        rideId: rideRequestRef.id,
        message: "Ride request created successfully",
        data: rideRequest,
      };

      return response;
    } catch (error) {
      logger.error("Error creating ride request", {
        error: error instanceof Error ? error.message : String(error),
        userId,
      });

      if (error instanceof functions.https.HttpsError) {
        throw error;
      }

      throw new functions.https.HttpsError(
        "internal",
        "Failed to create ride request",
      );
    }
  },
);
