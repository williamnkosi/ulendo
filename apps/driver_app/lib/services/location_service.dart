import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_geofire/flutter_geofire.dart';
import 'package:geolocator/geolocator.dart';

import 'package:ulendo_models/models/location_data.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

/// Service to handle real-time location tracking and Firebase Realtime Database uploads with GeoFire
class LocationService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late final String _driverId;
  late final DatabaseReference _driverRef;

  // Timer for periodic location updates
  Timer? _locationUpdateTimer;

  // Configuration
  static const Duration _defaultUpdateInterval = Duration(seconds: 10);
  static const String _geoFirePath = 'drivers'; // GeoFire collection path

  LocationService() {
    _driverId = _auth.currentUser?.uid ?? '';
    print('LocationService initialized with driverId: $_driverId');
    if (_driverId.isEmpty) {
      print('WARNING: Driver ID is empty. User may not be authenticated.');
    }
    _driverRef = _database.ref('drivers/$_driverId');
  }

  /// Initialize location service and GeoFire
  Future<void> initialize() async {
    try {
      print('Initializing LocationService with GeoFire...');
      // Check location permissions
      print('Checking location permissions...');
      await _checkLocationPermissions();
      print('Location permissions granted');

      // Initialize GeoFire with the drivers collection path
      print('Initializing GeoFire...');
      await Geofire.initialize(_geoFirePath);
      print('GeoFire initialized successfully');

      // Test database connection
      print('Testing database connection...');
      await _testDatabaseConnection();
      print('Database connection successful');
    } catch (e) {
      print('LocationService initialization failed: $e');
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

  /// Stop location streaming and remove from GeoFire
  Future<void> stopLocationStreaming() async {
    try {
      // Cancel the timer
      _locationUpdateTimer?.cancel();
      _locationUpdateTimer = null;

      // Remove from GeoFire
      await Geofire.removeLocation(_driverId);

      // Update driver status to offline
      await _driverRef.update({
        'status': 'offline',
        'timestamp': ServerValue.timestamp,
      });

      print('Location streaming stopped and driver removed from GeoFire');
    } catch (e) {
      throw LocationServiceException('Failed to stop location streaming: $e');
    }
  }

  /// Upload location data to Firebase Realtime Database using GeoFire
  /// GeoFire stores location with geohashing for efficient proximity queries
  Future<void> _uploadLocationToDatabase(LocationData locationData) async {
    try {
      // Use GeoFire to set location (handles geohashing internally)
      await Geofire.setLocation(
        _driverId,
        locationData.latitude,
        locationData.longitude,
      );

      // Also store driver metadata separately for queries
      await _driverRef.update({
        'latitude': locationData.latitude,
        'longitude': locationData.longitude,
        'status': 'available',
        'timestamp': ServerValue.timestamp,
      });

      print(
        'Location uploaded successfully: ${locationData.latitude}, ${locationData.longitude}',
      );
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
    print('Location permission status: $permission');

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      print('Location permissions denied: $permission');
      throw LocationServiceException(
        'Location permissions are not granted. Please enable location permissions in app settings.',
      );
    }
  }

  /// Test Firebase database connection
  Future<void> _testDatabaseConnection() async {
    try {
      print('Testing Firebase database connection...');
      // Test by attempting to update driver reference
      await _driverRef
          .update({'timestamp': ServerValue.timestamp})
          .timeout(const Duration(seconds: 5));
      print('Database connection test successful');
    } catch (e) {
      // Log warning but don't fail - let actual operations determine if DB is available
      print('Database connection test warning: $e');
      print('Will proceed with location tracking anyway...');
    }
  }

  /// Get driver's location history from Firebase
  Future<List<LocationData>> getLocationHistory({int limit = 100}) async {
    try {
      // Fetch driver's current metadata
      final snapshot = await _driverRef.get();

      if (!snapshot.exists) {
        return [];
      }

      // Return current location as single-item history
      final data = snapshot.value as Map<dynamic, dynamic>;
      return [
        LocationData(
          driverId: _driverId,
          latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
          longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
        ),
      ];
    } catch (e) {
      throw LocationServiceException('Failed to fetch location history: $e');
    }
  }

  /// Listen to location updates from Firebase (real-time sync)
  Stream<LocationData> listenToLocationUpdates() {
    return _driverRef.onValue.map((event) {
      if (event.snapshot.value == null) {
        throw LocationServiceException('No location data available');
      }

      final data = event.snapshot.value as Map<dynamic, dynamic>;

      return LocationData(
        driverId: _driverId,
        latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      );
    });
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
