import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

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
      print('RideManagementService: Attempting to accept ride: $rideId');

      // Update the ride status to "driver_accepted" using rideId as the key
      await _database.ref('active_rides/$rideId').update({
        'status': 'driver_accepted',
        'acceptedAt': DateTime.now().toIso8601String(),
        'acceptedDriver': _driverId,
      });

      print('RideManagementService: Ride status updated to driver_accepted');

      // Update driver status to "on_ride"
      await _database.ref('drivers/$_driverId').update({
        'status': 'on_ride',
        'updatedAt': DateTime.now().toIso8601String(),
      });

      print('RideManagementService: Driver status updated to on_ride');
    } catch (e) {
      if (e is RideManagementException) {
        rethrow;
      }
      throw RideManagementException(
        'Failed to accept ride: ${e.toString()}',
      );
    }
  }

  /// Reject a ride by updating its status to "driver_rejected"
  Future<void> rejectRide(String rideId) async {
    try {
      print('RideManagementService: Rejecting ride: $rideId');

      // Update ride status to "driver_rejected"
      await _database.ref('active_rides/$rideId').update({
        'status': 'driver_rejected',
        'rejectedAt': DateTime.now().toIso8601String(),
        'rejectedDriver': _driverId,
      });

      print('RideManagementService: Ride rejected');

      // Update driver status back to "available"
      await _database.ref('drivers/$_driverId').update({
        'status': 'available',
        'updatedAt': DateTime.now().toIso8601String(),
      });

      print('RideManagementService: Driver status updated to available');
    } catch (e) {
      if (e is RideManagementException) {
        rethrow;
      }
      throw RideManagementException(
        'Failed to reject ride: ${e.toString()}',
      );
    }
  }

  /// Get ride details by rideId
  Future<Map<String, dynamic>?> getRideDetails(String rideId) async {
    try {
      final snapshot = await _database.ref('active_rides/$rideId').get();

      if (snapshot.exists) {
        return Map<String, dynamic>.from(
          snapshot.value as Map<dynamic, dynamic>,
        );
      }

      return null;
    } catch (e) {
      throw RideManagementException(
        'Failed to get ride details: ${e.toString()}',
      );
    }
  }

  /// Cancel a ride (for driver who has accepted)
  Future<void> cancelRide(String rideId, String reason) async {
    try {
      print('RideManagementService: Cancelling ride: $rideId');

      // Update ride status to "cancelled"
      await _database.ref('active_rides/$rideId').update({
        'status': 'cancelled',
        'cancelledAt': DateTime.now().toIso8601String(),
        'cancelledBy': _driverId,
        'cancelReason': reason,
      });

      print('RideManagementService: Ride cancelled');

      // Update driver status back to "available"
      await _database.ref('drivers/$_driverId').update({
        'status': 'available',
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      if (e is RideManagementException) {
        rethrow;
      }
      throw RideManagementException(
        'Failed to cancel ride: ${e.toString()}',
      );
    }
  }
}
