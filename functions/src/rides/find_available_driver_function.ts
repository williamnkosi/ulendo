/* eslint-disable operator-linebreak */
import { getApps, initializeApp, AppOptions } from "firebase-admin/app";
import { Database, getDatabase } from "firebase-admin/database";
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
  RideStatusEnum,
} from "../types";
import { calculateGeohash } from "../utils/calculate-geohash";

const appOptions: AppOptions = {
  databaseURL: "https://ulendo-dev-default-rtdb.firebaseio.com",
};

if (getApps().length === 0) {
  initializeApp(appOptions);
}

function calculateDistance(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number,
): number {
  return distanceBetween([lat1, lng1], [lat2, lng2]);
}

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

      const db: Database = getDatabase();
      const pickupLat = rideData.pickup.location[0];
      const pickupLng = rideData.pickup.location[1];
      const rideGeohash = rideData.pickup.geohash;

      // Fetch all available drivers
      const driversData = await fetchAvailableDrivers(db);

      if (!driversData) {
        logger.warn("No drivers available", { rideId });
        await db.ref(`active_rides/${rideId}`).update({
          status: RideStatusEnum.SEARCHING,
        });
        return Promise.resolve();
      }

      // Filter nearby drivers
      const nearbyDrivers = filterNearbyDrivers(driversData, rideGeohash);

      logger.info("Nearby drivers found", {
        rideId,
        nearbyDriverCount: nearbyDrivers.length,
      });

      if (nearbyDrivers.length === 0) {
        logger.warn("No nearby drivers available", { rideId });
        await db.ref(`active_rides/${rideId}`).update({
          status: RideStatusEnum.SEARCHING,
        });
        return Promise.resolve();
      }

      // Find closest driver
      const closestResult = findClosestDriver(
        nearbyDrivers,
        pickupLat,
        pickupLng,
      );

      if (!closestResult) {
        logger.warn("Failed to find closest driver", { rideId });
        return Promise.resolve();
      }

      const { driver: closestDriver, distance: minDistance } = closestResult;

      logger.info("Closest driver found", {
        rideId,
        driverId: closestDriver.driverId,
        distance: minDistance.toFixed(2),
      });

      // Update ride and driver status
      await updateRideAndDriverStatus(
        db,
        rideId,
        closestDriver.driverId,
        parseFloat(minDistance.toFixed(2)),
      );

      logger.info("Driver successfully assigned to ride", {
        rideId,
        driverId: closestDriver.driverId,
      });

      // Send FCM notification
      await sendRideNotification(
        db,
        rideId,
        closestDriver.driverId,
        rideData,
        minDistance,
      );

      return Promise.resolve();
    } catch (error) {
      logger.error("Error in findAvailableDriverFunction", {
        error: error instanceof Error ? error.message : String(error),
      });
      return Promise.resolve();
    }
  });

async function fetchAvailableDrivers(
  db: Database,
): Promise<Record<string, DriverStatus> | null> {
  const driversSnapshot = await db.ref("drivers").get();
  return driversSnapshot.val() as Record<string, DriverStatus>;
}

function filterNearbyDrivers(
  driversData: Record<string, DriverStatus>,
  rideGeohash: string,
): Driver[] {
  const nearbyDrivers: Driver[] = [];

  for (const driverId in driversData) {
    if (!Object.prototype.hasOwnProperty.call(driversData, driverId)) {
      continue;
    }

    const driver = driversData[driverId];

    // Skip if driver doesn't have required location fields
    if (!driver.latitude || !driver.longitude) {
      continue;
    }

    // Skip if driver is not available
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

  return nearbyDrivers;
}

function findClosestDriver(
  nearbyDrivers: Driver[],
  pickupLat: number,
  pickupLng: number,
): { driver: Driver; distance: number } | null {
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

  return closestDriver
    ? { driver: closestDriver, distance: minDistance }
    : null;
}

async function updateRideAndDriverStatus(
  db: Database,
  rideId: string,
  driverId: string,
  distanceToPickup: number,
): Promise<void> {
  // Update ride status
  await db.ref(`active_rides/${rideId}`).update({
    assignedDriver: driverId,
    status: RideStatusEnum.DRIVER_OFFERED,
    distanceToPickup,
    assignedAt: new Date().toISOString(),
  });

  // Update driver status to indicate pending offer
  await db.ref(`drivers/${driverId}`).update({
    status: DriverStatusEnum.DRIVER_OFFER_PENDING,
  });
}

async function sendRideNotification(
  db: Database,
  rideId: string,
  driverId: string,
  rideData: RideData,
  distanceToPickup: number,
): Promise<void> {
  try {
    const driverRef = db.ref(`drivers/${driverId}`);
    const driverSnapshot = await driverRef.get();
    const driverData = driverSnapshot.val() as DriverStatus;

    if (!driverData || !driverData.fcmToken) {
      logger.warn("Driver FCM token not found", {
        rideId,
        driverId,
      });
      return;
    }

    const fcmToken = driverData.fcmToken;

    // Compose notification message
    const message: DriverNotification = {
      notification: {
        title: "New Ride Request",
        body: `Pickup: ${rideData.pickup.address}`,
      },
      data: {
        rideId,
        driverId,
        pickupAddress: rideData.pickup.address,
        dropoffAddress: rideData.dropoff.address,
        distanceToPickup: distanceToPickup.toFixed(2),
        pickupLat: rideData.pickup.location[0].toString(),
        pickupLng: rideData.pickup.location[1].toString(),
      },
      token: fcmToken,
    };

    // Send the message
    const messaging = getMessaging();
    const messageId = await messaging.send(message);

    logger.info("FCM notification sent to driver", {
      rideId,
      driverId,
      messageId,
    });
  } catch (fcmError) {
    logger.error("Error sending FCM notification", {
      rideId,
      driverId,
      error: fcmError instanceof Error ? fcmError.message : String(fcmError),
    });
  }
}

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
