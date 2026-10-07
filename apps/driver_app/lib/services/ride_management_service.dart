import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:logger/logger.dart';

/// Exception for ride management service errors
class RideManagementException implements Exception {
  final String message;
  RideManagementException(this.message);

  @override
  String toString() => message;
}

/// Service to manage ride operations in Firebase Realtime Database
class RideManagementService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Logger _logger = Logger(
    printer: PrefixPrinter(
      PrettyPrinter(methodCount: 0),
      info: '[RideManagementService]',
      error: '[RideManagementService]',
      warning: '[RideManagementService]',
      debug: '[RideManagementService]',
    ),
  );

  late final String _driverId;

  RideManagementService() {
    _driverId = _auth.currentUser?.uid ?? '';
    if (_driverId.isEmpty) {
      throw RideManagementException('Driver not authenticated');
    }
  }

  /// Accept a ride by updating its status in the database
  /// Updates the ride status in active_rides/{rideId} to "driver_accepted"
  /// Also updates the driver status to "on_ride"
  Future<void> acceptRide(String rideId) async {
    try {
      _logger.i('Attempting to accept ride: $rideId');

      // Update the ride status to "driver_accepted" using rideId as the key
      await _database.ref('active_rides/$rideId').update({
        'status': 'driver_accepted',
        'acceptedAt': DateTime.now().toIso8601String(),
        'acceptedDriver': _driverId,
      });

      _logger.i('Ride status updated to driver_accepted: $rideId');

      // Update driver status to "on_ride"
      await _database.ref('drivers/$_driverId').update({
        'status': 'on_ride',
        'updatedAt': DateTime.now().toIso8601String(),
      });

      _logger.i('Driver status updated to on_ride');
    } catch (e) {
      if (e is RideManagementException) {
        rethrow;
      }
      throw RideManagementException('Failed to accept ride: ${e.toString()}');
    }
  }

  /// Reject a ride by updating its status to "driver_rejected"
  Future<void> rejectRide(String rideId) async {
    try {
      _logger.i('Rejecting ride: $rideId');

      // Update ride status to "driver_rejected"
      await _database.ref('active_rides/$rideId').update({
        'status': 'driver_rejected',
        'rejectedAt': DateTime.now().toIso8601String(),
        'rejectedDriver': _driverId,
      });

      _logger.i('Ride rejected: $rideId');

      // Update driver status back to "available"
      await _database.ref('drivers/$_driverId').update({
        'status': 'available',
        'updatedAt': DateTime.now().toIso8601String(),
      });

      _logger.i('Driver status updated to available');
    } catch (e) {
      if (e is RideManagementException) {
        rethrow;
      }
      throw RideManagementException('Failed to reject ride: ${e.toString()}');
    }
  }

  /// Get ride details by rideId from the database
  /// Queries active_rides/{rideId} and returns the ride data
  Future<Map<String, dynamic>?> getRideDetails(String rideId) async {
    try {
      _logger.i('Fetching ride details for rideId: $rideId');

      final snapshot = await _database.ref('active_rides/$rideId').get();

      if (snapshot.exists) {
        final rideData = Map<String, dynamic>.from(
          snapshot.value as Map<dynamic, dynamic>,
        );

        _logger.i('Ride details fetched successfully for rideId: $rideId');
        _logger.d('Ride data: $rideData');

        return rideData;
      }

      _logger.w('Ride not found for rideId: $rideId');
      return null;
    } catch (e) {
      _logger.e('Error fetching ride details: $e');
      throw RideManagementException(
        'Failed to get ride details: ${e.toString()}',
      );
    }
  }

  /// Cancel a ride (for driver who has accepted)
  Future<void> cancelRide(String rideId, String reason) async {
    try {
      _logger.i('Cancelling ride: $rideId, reason: $reason');

      // Update ride status to "cancelled"
      await _database.ref('active_rides/$rideId').update({
        'status': 'cancelled',
        'cancelledAt': DateTime.now().toIso8601String(),
        'cancelledBy': _driverId,
        'cancelReason': reason,
      });

      _logger.i('Ride cancelled: $rideId');

      // Update driver status back to "available"
      await _database.ref('drivers/$_driverId').update({
        'status': 'available',
        'updatedAt': DateTime.now().toIso8601String(),
      });

      _logger.i('Driver status updated to available');
    } catch (e) {
      if (e is RideManagementException) {
        rethrow;
      }
      throw RideManagementException('Failed to cancel ride: ${e.toString()}');
    }
  }

  /// Complete a ride by updating its status to "completed"
  /// Also updates the driver status back to "available"
  Future<void> completeRide(String rideId) async {
    try {
      _logger.i('Completing ride: $rideId');

      // Update ride status to "completed"
      await _database.ref('active_rides/$rideId').update({
        'status': 'completed',
        'completedAt': DateTime.now().toIso8601String(),
        'completedBy': _driverId,
      });

      _logger.i('Ride completed: $rideId');
    } catch (e) {
      if (e is RideManagementException) {
        rethrow;
      }
      throw RideManagementException('Failed to complete ride: ${e.toString()}');
    }
  }
}
