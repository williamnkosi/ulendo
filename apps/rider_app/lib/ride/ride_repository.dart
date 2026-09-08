import 'package:equatable/equatable.dart';
import 'package:ulendo_core/ulendo_core.dart';
import 'package:ulendo_models/ulendo_models.dart';

import '../core/constants/api_constants.dart';

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
  final HttpService _httpService;

  RideRepositoryImpl({required HttpService httpService})
    : _httpService = httpService;

  @override
  List<Object?> get props => [_httpService];

  @override
  Future<RideRequest> requestRide({
    required Location pickup,
    required Location dropoff,
  }) async {
    try {
      final rideRequest = RideRequest(pickup: pickup, dropoff: dropoff);

      final response = await _httpService.post<Map<String, dynamic>>(
        '${ApiConstants.baseUrl}${ApiConstants.requestRide}',
        data: rideRequest.toJson(),
      );

      // Parse the response and return RideRequest
      return RideRequest.fromJson(response);
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
