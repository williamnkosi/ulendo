import { calculateGeohash } from "./calculate-geohash";

interface LocationData {
  lat: number;
  lng: number;
  address: string;
}

interface RideRecord {
  rideId: string;
  userId: string;
  status: string;
  pickup: {
    location: [number, number];
    geohash: string;
    address: string;
  };
  dropoff: {
    location: [number, number];
    address: string;
  };
  timestamp: string;
}

/**
 * Create a ride record with pickup and dropoff data
 * @param {number}pickupLat - Pickup latitude
 * @param {number} pickupLng - Pickup longitude
 * @param {string} pickupAddress - Pickup address
 * @param {number} dropoffLat - Dropoff latitude
 * @param {number} dropoffLng - Dropoff longitude
 * @param {string} dropoffAddress - Dropoff address
 * @param {string} userId - User ID of the rider
 * @param {string} rideId - Unique ride ID
 * @return {RideRecord} Structured ride record object
 */
export function createRideRecord(
  pickupLat: number,
  pickupLng: number,
  pickupAddress: string,
  dropoffLat: number,
  dropoffLng: number,
  dropoffAddress: string,
  userId: string,
  rideId: string,
): RideRecord {
  const geohash = calculateGeohash(pickupLat, pickupLng);

  return {
    rideId,
    userId,
    status: "pending",
    pickup: {
      location: [pickupLat, pickupLng],
      geohash,
      address: pickupAddress,
    },
    dropoff: {
      location: [dropoffLat, dropoffLng],
      address: dropoffAddress,
    },
    timestamp: new Date().toISOString(),
  };
}

/**
 * Alternative: Create ride record from location objects
 * @param {LocationData} pickup - Pickup location data
 * @param {LocationData} dropoff - Dropoff location data
 * @param {string} userId - User ID of the rider
 * @param {string} rideId - Unique ride ID
 * @return {RideRecord} Structured ride record object
 */
export function createRideRecordFromLocations(
  pickup: LocationData,
  dropoff: LocationData,
  userId: string,
  rideId: string,
): RideRecord {
  return createRideRecord(
    pickup.lat,
    pickup.lng,
    pickup.address,
    dropoff.lat,
    dropoff.lng,
    dropoff.address,
    userId,
    rideId,
  );
}
