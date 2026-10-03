import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

/// Service to handle polyline generation for routes on Google Maps
class PolylineService {
  final String _googleMapsApiKey;
  final Logger _logger = Logger(
    printer: PrefixPrinter(
      PrettyPrinter(methodCount: 0),
      info: '[PolylineService]',
      debug: '[PolylineService]',
      warning: '[PolylineService]',
      error: '[PolylineService]',
    ),
  );

  PolylineService({required String googleMapsApiKey})
      : _googleMapsApiKey = googleMapsApiKey;

  /// Get polylines between two locations using Google Directions API
  /// Returns a Set of Polyline objects that can be drawn on the map
  Future<Set<Polyline>> getPolylines({
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    String polylineId = 'route',
    int polylineWidth = 5,
    Color polylineColor = const Color(0xFF4285F4),
  }) async {
    try {
      _logger.i(
        'Getting polylines from ($pickupLat, $pickupLng) to ($dropoffLat, $dropoffLng)',
      );

      final String url =
          'https://maps.googleapis.com/maps/api/directions/json?'
          'origin=$pickupLat,$pickupLng'
          '&destination=$dropoffLat,$dropoffLng'
          '&key=$_googleMapsApiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        _logger.d('Directions API response: $json');

        if (json['routes'].isEmpty) {
          _logger.w('No routes found');
          return {};
        }

        final route = json['routes'][0];
        final polylinePoints = route['overview_polyline']['points'];

        _logger.i('Polyline points: $polylinePoints');

        // Decode polyline points
        final List<LatLng> decodedPoints =
            _decodePolyline(polylinePoints);

        _logger.i('Decoded ${decodedPoints.length} points from polyline');

        // Create polyline object
        final polyline = Polyline(
          polylineId: PolylineId(polylineId),
          points: decodedPoints,
          color: polylineColor,
          width: polylineWidth,
          geodesic: true,
        );

        return {polyline};
      } else {
        _logger.e(
          'Failed to get directions: ${response.statusCode} - ${response.body}',
        );
        throw PolylineServiceException(
          'Failed to fetch directions: ${response.statusCode}',
        );
      }
    } catch (e) {
      _logger.e('Error getting polylines: $e');
      throw PolylineServiceException('Failed to get polylines: $e');
    }
  }

  /// Decode polyline string into LatLng points
  /// Uses the Google polyline encoding algorithm
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int result = 0;
      int shift = 0;

      int byte;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);

      int dLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dLat;

      result = 0;
      shift = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);

      int dLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dLng;

      points.add(
        LatLng(
          lat / 1e5,
          lng / 1e5,
        ),
      );
    }

    return points;
  }

  /// Calculate distance between two points in kilometers
  double calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const p = 0.017453292519943295;
    return 12742 *
        asin(
          sqrt(
            sin((lat2 - lat1) * p / 2) * sin((lat2 - lat1) * p / 2) +
                cos(lat1 * p) *
                    cos(lat2 * p) *
                    sin((lng2 - lng1) * p / 2) *
                    sin((lng2 - lng1) * p / 2),
          ),
        );
  }
}

/// Exception for polyline service errors
class PolylineServiceException implements Exception {
  final String message;

  PolylineServiceException(this.message);

  @override
  String toString() => 'PolylineServiceException: $message';
}
