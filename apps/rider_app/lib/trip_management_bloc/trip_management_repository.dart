import 'package:equatable/equatable.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:ulendo_models/models/location.dart';
import 'package:ulendo_models/models/ride_request.dart';

/// Abstract repository for managing the complete trip lifecycle
abstract class TripManagementRepository extends Equatable {
  /// Request a new trip
  Future<RideRequest> requestTrip({
    required Location pickup,
    required Location dropoff,
  });

  /// Get current active trip
  Future<RideRequest?> getActiveTrip();

  /// Get trip status
  Future<RideRequest> getTripStatus({required String tripId});

  /// Cancel an active trip
  Future<void> cancelTrip({required String tripId, String? reason});

  /// Complete a trip
  Future<void> completeTrip({required String tripId});

  /// Rate a completed trip
  Future<void> rateTrip({
    required String tripId,
    required double rating,
    String? review,
  });

  /// Listen to trip status updates (for real-time tracking)
  Stream<RideRequest> watchTrip({required String tripId});
}

/// Concrete implementation of TripManagementRepository
class TripManagementRepositoryImpl extends TripManagementRepository {
  final FirebaseFunctions _functions;

  TripManagementRepositoryImpl({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  @override
  List<Object?> get props => [_functions];

  @override
  Future<RideRequest> requestTrip({
    required Location pickup,
    required Location dropoff,
  }) async {
    try {
      final callable = _functions.httpsCallable('requestRideFunction');
      final response = await callable.call({
        'pickup': pickup.toJson(),
        'dropoff': dropoff.toJson(),
      });

      final data = response.data;
      if (data is! Map || data['success'] != true) {
        throw const FormatException('Invalid ride request response');
      }

      // The callable also returns rideId and message; RideRequest currently
      // represents only the requested locations.
      return RideRequest.fromJson({
        'pickup': Map<String, dynamic>.from(data['pickup'] as Map),
        'dropoff': Map<String, dynamic>.from(data['dropoff'] as Map),
      });
    } catch (e) {
      throw Exception('Failed to request trip: $e');
    }
  }

  @override
  Future<RideRequest?> getActiveTrip() async {
    try {
      final callable = _functions.httpsCallable('getActiveTripFunction');
      await callable.call();

      // TODO: Parse response and return RideRequest or null
      throw UnimplementedError('getActiveTrip not implemented');
    } catch (e) {
      throw Exception('Failed to get active trip: $e');
    }
  }

  @override
  Future<RideRequest> getTripStatus({required String tripId}) async {
    try {
      final callable = _functions.httpsCallable('getTripStatusFunction');
      await callable.call({'tripId': tripId});

      // TODO: Parse response and return RideRequest
      throw UnimplementedError('getTripStatus not implemented');
    } catch (e) {
      throw Exception('Failed to get trip status: $e');
    }
  }

  @override
  Future<void> cancelTrip({required String tripId, String? reason}) async {
    try {
      final callable = _functions.httpsCallable('cancelTripFunction');
      await callable.call({'tripId': tripId, 'reason': reason});
    } catch (e) {
      throw Exception('Failed to cancel trip: $e');
    }
  }

  @override
  Future<void> completeTrip({required String tripId}) async {
    try {
      final callable = _functions.httpsCallable('completeTripFunction');
      await callable.call({'tripId': tripId});
    } catch (e) {
      throw Exception('Failed to complete trip: $e');
    }
  }

  @override
  Future<void> rateTrip({
    required String tripId,
    required double rating,
    String? review,
  }) async {
    try {
      final callable = _functions.httpsCallable('rateTripFunction');
      await callable.call({
        'tripId': tripId,
        'rating': rating,
        'review': review,
      });
    } catch (e) {
      throw Exception('Failed to rate trip: $e');
    }
  }

  @override
  Stream<RideRequest> watchTrip({required String tripId}) {
    // TODO: Implement real-time trip tracking stream
    throw UnimplementedError('watchTrip not implemented');
  }
}
