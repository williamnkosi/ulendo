import { getApps, initializeApp, AppOptions } from "firebase-admin/app";
import { getDatabase } from "firebase-admin/database";
import { getMessaging } from "firebase-admin/messaging";
import * as functions from "firebase-functions/v1";
import * as logger from "firebase-functions/logger";
import { distanceBetween } from "geofire-common";
import {
  Driver,
  RideData,
  DriverStatus,
  DriverNotification,
  DriverStatusEnum,
} from "../types";
import { calculateGeohash } from "../utils/calculate-geohash";

const appOptions: AppOptions = {
  databaseURL: "https://ulendo-dev-default-rtdb.firebaseio.com",
};

if (getApps().length === 0) {
  initializeApp(appOptions);
}

/**
 * Calculate distance between two coordinates in kilometers
 * @param {number} lat1 Latitude of point 1
 * @param {number} lng1 Longitude of point 1
 * @param {number} lat2 Latitude of point 2
 * @param {number} lng2 Longitude of point 2
 * @return {number} Distance in kilometers
 */
function calculateDistance(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number,
): number {
  return distanceBetween([lat1, lng1], [lat2, lng2]);
}

/**
 * Check if two geohashes are nearby (within search radius)
 * Uses geohash prefix matching for quick proximity checks
 * @param {string} driverGeohash Driver's geohash
 * @param {string} rideGeohash Ride pickup geohash
 * @param {number} precision Geohash precision to compare
 * (higher = smaller area)
 * @return {boolean} True if geohashes match at given precision
 */
function isNearbyGeohash(
  driverGeohash: string,
  rideGeohash: string,
  precision: number = 4,
): boolean {
  return (
    driverGeohash.substring(0, precision) ===
    rideGeohash.substring(0, precision)
  );
}

/**
 * Cloud Function triggered when a new active ride is created.
 * Finds the closest available driver and assigns them to the ride.
 *
 * Triggers on: /active_rides/{rideId} - onCreate
 *
 * @param snapshot - The database snapshot containing the new ride data
 * @param context - Firebase context with function metadata
 *
 * @returns Promise<void>
 */
export const findAvailableDriverFunction = functions.database
  .ref("/active_rides/{rideId}")
  .onCreate(async (snapshot, context) => {
    try {
      const rideId = context.params.rideId;
      const rideData = snapshot.val() as RideData;

      logger.info(`New active ride created: ${rideId}`, {
        rideId,
        pickupLocation: rideData.pickup.location,
        pickupGeohash: rideData.pickup.geohash,
      });

      const db = getDatabase();
      const pickupLat = rideData.pickup.location[0];
      const pickupLng = rideData.pickup.location[1];
      const rideGeohash = rideData.pickup.geohash;

      // Fetch all active drivers
      const driversSnapshot = await db.ref("drivers").get();

      if (!driversSnapshot.exists()) {
        logger.warn("No drivers available", { rideId });
        await db.ref(`active_rides/${rideId}`).update({
          status: "no_drivers_available",
        });
        return Promise.resolve();
      }

      const driversData = driversSnapshot.val() as Record<string, DriverStatus>;

      // Filter nearby drivers using geohash
      const nearbyDrivers: Driver[] = [];

      for (const driverId in driversData) {
        // Use Object.prototype.hasOwnProperty.call() for safer checking
        if (!Object.prototype.hasOwnProperty.call(driversData, driverId)) {
          continue;
        }

        const driver = driversData[driverId];

        // Skip if driver doesn't have required location fields
        if (!driver.latitude || !driver.longitude) {
          continue;
        }

        // Skip if driver is not available (has pending offer, offline, etc.)
        if (driver.status !== DriverStatusEnum.AVAILABLE) {
          continue;
        }

        // Use geohash from driver data, or calculate if not present
        const driverGeohash =
          driver.g || calculateGeohash(driver.latitude, driver.longitude, 4);

        // Check if driver is nearby using geohash
        if (isNearbyGeohash(driverGeohash, rideGeohash, 4)) {
          nearbyDrivers.push({
            driverId,
            latitude: driver.latitude,
            longitude: driver.longitude,
            geohash: driverGeohash,
          });
        }
      }

      logger.info("Nearby drivers found", {
        rideId,
        nearbyDriverCount: nearbyDrivers.length,
      });

      if (nearbyDrivers.length === 0) {
        logger.warn("No nearby drivers available", { rideId });
        await db.ref(`active_rides/${rideId}`).update({
          status: "searching_no_nearby_drivers",
        });
        return Promise.resolve();
      }

      // Calculate distance to each nearby driver and find closest
      let closestDriver: Driver | null = null;
      let minDistance = Infinity;

      for (const driver of nearbyDrivers) {
        const distance = calculateDistance(
          pickupLat,
          pickupLng,
          driver.latitude,
          driver.longitude,
        );

        logger.info("Driver distance calculated", {
          driverId: driver.driverId,
          distance: distance.toFixed(2),
        });

        if (distance < minDistance) {
          minDistance = distance;
          closestDriver = driver;
        }
      }

      if (!closestDriver) {
        logger.warn("Failed to find closest driver", { rideId });
        return Promise.resolve();
      }

      logger.info("Closest driver found", {
        rideId,
        driverId: closestDriver.driverId,
        distance: minDistance.toFixed(2),
      });

      // Assign the closest driver to the ride
      await db.ref(`active_rides/${rideId}`).update({
        assignedDriver: closestDriver.driverId,
        status: DriverStatusEnum.DRIVER_OFFER_PENDING,
        distanceToPickup: parseFloat(minDistance.toFixed(2)),
        assignedAt: new Date().toISOString(),
      });

      logger.info("Driver successfully assigned to ride", {
        rideId,
        driverId: closestDriver.driverId,
      });

      // Fetch the driver's FCM token to send notification
      try {
        const driverRef = db.ref(`drivers/${closestDriver.driverId}`);
        const driverSnapshot = await driverRef.get();
        const driverData = driverSnapshot.val() as DriverStatus;

        if (driverData && driverData.fcmToken) {
          const fcmToken = driverData.fcmToken;

          // Compose notification message
          const message: DriverNotification = {
            notification: {
              title: "New Ride Request",
              body: `Pickup: ${rideData.pickup.address}`,
            },
            data: {
              rideId,
              driverId: closestDriver.driverId,
              pickupAddress: rideData.pickup.address,
              dropoffAddress: rideData.dropoff.address,
              distanceToPickup: minDistance.toFixed(2),
              pickupLat: pickupLat.toString(),
              pickupLng: pickupLng.toString(),
            },
            token: fcmToken,
          };

          // Send the message
          const messaging = getMessaging();
          const messageId = await messaging.send(message);

          logger.info("FCM notification sent to driver", {
            rideId,
            driverId: closestDriver.driverId,
            messageId,
          });
        } else {
          logger.warn("Driver FCM token not found", {
            rideId,
            driverId: closestDriver.driverId,
          });
        }
      } catch (fcmError) {
        logger.error("Error sending FCM notification", {
          rideId,
          driverId: closestDriver.driverId,
          error:
            fcmError instanceof Error ? fcmError.message : String(fcmError),
        });
      }

      return Promise.resolve();
    } catch (error) {
      logger.error("Error in findAvailableDriverFunction", {
        error: error instanceof Error ? error.message : String(error),
      });
      return Promise.resolve();
    }
  });
