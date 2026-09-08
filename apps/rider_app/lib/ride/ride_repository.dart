import 'package:equatable/equatable.dart';
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
  @override
  List<Object?> get props => [];

  @override
  Future<RideRequest> requestRide({
    required Location pickup,
    required Location dropoff,
  }) async {
    // TODO: Implement requestRide
    throw UnimplementedError();
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
