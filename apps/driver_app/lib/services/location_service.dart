import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

import 'package:ulendo_models/models/location_data.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

/// Service to handle real-time location tracking and Firebase Realtime Database uploads
class LocationService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late final String _driverId;
  late final DatabaseReference _locationRef;

  // Timer for periodic location updates
  Timer? _locationUpdateTimer;

  // Configuration
  static const Duration _defaultUpdateInterval = Duration(seconds: 10);

  LocationService() {
    _driverId = _auth.currentUser?.uid ?? '';
    _locationRef = _database.ref('drivers/$_driverId/location');
  }

  /// Initialize location service and start streaming
  Future<void> initialize() async {
    try {
      // Check location permissions
      await _checkLocationPermissions();

      // Test database connection
      await _testDatabaseConnection();
    } catch (e) {
      throw LocationServiceException(
        'Failed to initialize location service: $e',
      );
    }
  }

  /// Start streaming location data to Firebase
  /// [updateInterval] defines how often location is fetched and uploaded (default: 10 seconds)
  Future<void> startLocationStreaming({
    Duration updateInterval = _defaultUpdateInterval,
  }) async {
    try {
      await initialize();

      // Cancel any existing timer
      _locationUpdateTimer?.cancel();

      // Fetch location immediately on start
      await _fetchAndUploadLocation();

      // Set up periodic updates
      _locationUpdateTimer = Timer.periodic(updateInterval, (_) async {
        await _fetchAndUploadLocation();
      });
    } catch (e) {
      throw LocationServiceException('Failed to start location streaming: $e');
    }
  }

  /// Fetch current location and upload to Firebase
  Future<void> _fetchAndUploadLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final locationData = LocationData(
        driverId: _driverId,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      await _uploadLocationToDatabase(locationData);
    } catch (e) {
      // Log error but don't throw - we want periodic updates to continue
      print('Error fetching location: $e');
    }
  }

  /// Stop location streaming
  Future<void> stopLocationStreaming() async {
    try {
      // Cancel the timer
      _locationUpdateTimer?.cancel();
      _locationUpdateTimer = null;
      // Optional: Clear location from database
      await _locationRef.remove();
    } catch (e) {
      throw LocationServiceException('Failed to stop location streaming: $e');
    }
  }

  /// Upload location data to Firebase Realtime Database
  Future<void> _uploadLocationToDatabase(LocationData locationData) async {
    try {
      await _locationRef.set({
        'driverId': locationData.driverId,
        'latitude': locationData.latitude,
        'longitude': locationData.longitude,
        'timestamp': ServerValue.timestamp,
      });
    } catch (e) {
      throw LocationServiceException('Failed to upload location: $e');
    }
  }

  /// Check if location streaming is active
  bool isStreaming() => _locationUpdateTimer?.isActive ?? false;

  /// Get current location (one-time fetch)
  Future<LocationData> getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      return LocationData(
        driverId: _driverId,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (e) {
      throw LocationServiceException('Failed to get current location: $e');
    }
  }

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return Geolocator.isLocationServiceEnabled();
  }

  /// Check if location permissions are granted
  Future<void> _checkLocationPermissions() async {
    final permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw LocationServiceException(
        'Location permissions are not granted. Please enable location permissions in app settings.',
      );
    }
  }

  /// Test Firebase database connection
  Future<void> _testDatabaseConnection() async {
    try {
      final ref = _database.ref('.info/connected');
      final event = await ref.once();

      if (event.snapshot.value != true) {
        throw LocationServiceException('Firebase database connection failed');
      }
    } catch (e) {
      throw LocationServiceException('Database connection test failed: $e');
    }
  }

  /// Get driver's location history from Firebase
  Future<List<LocationData>> getLocationHistory({int limit = 100}) async {
    try {
      final snapshot = await _locationRef.limitToLast(limit).get();

      if (!snapshot.exists) {
        return [];
      }

      // Parse location data from snapshot
      return _parseLocationSnapshot(snapshot);
    } catch (e) {
      throw LocationServiceException('Failed to fetch location history: $e');
    }
  }

  /// Listen to location updates from Firebase (real-time sync)
  Stream<LocationData> listenToLocationUpdates() {
    return _locationRef.onValue.map((event) {
      if (event.snapshot.value == null) {
        throw LocationServiceException('No location data available');
      }

      final data = event.snapshot.value as Map<dynamic, dynamic>;

      return LocationData(
        driverId: data['driverId'] ?? _driverId,
        latitude: (data['latitude'] as num).toDouble(),
        longitude: (data['longitude'] as num).toDouble(),
      );
    });
  }

  /// Parse location snapshot
  List<LocationData> _parseLocationSnapshot(DataSnapshot snapshot) {
    final locations = <LocationData>[];

    if (snapshot.value is Map) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      data.forEach((key, value) {
        if (value is Map<dynamic, dynamic>) {
          locations.add(
            LocationData(
              driverId: value['driverId'] ?? _driverId,
              latitude: (value['latitude'] as num).toDouble(),
              longitude: (value['longitude'] as num).toDouble(),
            ),
          );
        }
      });
    }

    return locations;
  }

  /// Update the location update interval while streaming
  Future<void> updateStreamInterval(Duration newInterval) async {
    if (isStreaming()) {
      await stopLocationStreaming();
      await startLocationStreaming(updateInterval: newInterval);
    }
  }

  /// Cleanup resources
  Future<void> dispose() async {
    await stopLocationStreaming();
  }
}

/// Custom exception for location service errors
class LocationServiceException implements Exception {
  final String message;

  LocationServiceException(this.message);

  @override
  String toString() => 'LocationServiceException: $message';
}
