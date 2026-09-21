import { Message } from "firebase-admin/messaging";

/**
 * Driver status and location data sent from the driver app to Firestore
 */
export interface DriverStatus {
  latitude: number;
  longitude: number;
  status: string;
  fcmToken?: string;
  timestamp: string | number; // Server timestamp or ISO string
  g?: string; // Geohash (set as priority on Firebase)
  l?: [number, number]; // Location array in geofire format [lat, lng]
}

/**
 * Ride data stored in the active_rides collection
 */
export interface RideData {
  pickup: {
    location: [number, number];
    geohash: string;
    address: string;
  };
  dropoff: {
    location: [number, number];
    address: string;
  };
  userId: string;
  status: string;
}

/**
 * Driver information with required fields for matching
 */
export interface Driver {
  driverId: string;
  latitude: number;
  longitude: number;
  geohash: string;
}

/**
 * FCM Message type for sending notifications to drivers
 */
export type DriverNotification = Message;
