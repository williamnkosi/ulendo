import 'package:equatable/equatable.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:ulendo_models/ulendo_models.dart';

abstract class RideRepository extends Equatable {
  Future<RideRequest> requestRide({
    required Location pickup,
    required Location dropoff,
  });

  Future<void> cancelRide({required String rideId});

  Future<RideRequest> getRideStatus({required String rideId});

  Future<RideRequest?> getActiveRide();

  Future<void> completeRide({required String rideId});
}

class RideRepositoryImpl extends RideRepository {
  final FirebaseFunctions _functions;

  RideRepositoryImpl({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  @override
  List<Object?> get props => [_functions];

  @override
  Future<RideRequest> requestRide({
    required Location pickup,
    required Location dropoff,
  }) async {
    try {
      final callable = _functions.httpsCallable('requestRideFunction');
      final response = await callable.call({
        'pickup': pickup.toJson(),
        'dropoff': dropoff.toJson(),
      });

      // Function returns {success, message, rideId, pickup, dropoff}
      // final data = response.data as Map<String, dynamic>;

      // // Parse pickup and dropoff from response
      // final pickupData = data['pickup'] as Map<String, dynamic>;
      // final dropoffData = data['dropoff'] as Map<String, dynamic>;

      // final pickupLocation = Location(
      //   lat: pickupData['lat'] as double,
      //   lng: pickupData['lng'] as double,
      //   address: pickupData['address'] as String,
      // );

      // final dropoffLocation = Location(
      //   lat: dropoffData['lat'] as double,
      //   lng: dropoffData['lng'] as double,
      //   address: dropoffData['address'] as String,
      // );

      final rideRequest = RideRequest.fromJson(response.data);
      return rideRequest;
    } catch (e) {
      throw Exception('Failed to request ride: $e');
    }
  }

  @override
  Future<void> cancelRide({required String rideId}) async {
    // TODO: Implement cancelRide
    throw UnimplementedError();
  }

  @override
  Future<RideRequest> getRideStatus({required String rideId}) async {
    // TODO: Implement getRideStatus
    throw UnimplementedError();
  }

  @override
  Future<RideRequest?> getActiveRide() async {
    // TODO: Implement getActiveRide
    throw UnimplementedError();
  }

  @override
  Future<void> completeRide({required String rideId}) async {
    // TODO: Implement completeRide
    throw UnimplementedError();
  }
}
