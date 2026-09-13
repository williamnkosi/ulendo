import { geohashForLocation } from "geofire-common";

/**
 * Calculate geohash for a given latitude and longitude
 * @param {number} latitude - The latitude coordinate
 * @param {number} longitude - The longitude coordinate
 * @param {number} precision - The precision level (1-32, default: 10)
 * @return {string} The geohash string
 */
export function calculateGeohash(
  latitude: number,
  longitude: number,
  precision: number = 10,
): string {
  return geohashForLocation([latitude, longitude], precision);
}
