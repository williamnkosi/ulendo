import 'package:freezed_annotation/freezed_annotation.dart';
import 'location.dart';

part 'ride_request.freezed.dart';
part 'ride_request.g.dart';

/// Ride request model
@freezed
abstract class RideRequest with _$RideRequest {
  const factory RideRequest({
    /// Pickup location
    required Location pickup,

    /// Dropoff location
    required Location dropoff,
  }) = _RideRequest;

  factory RideRequest.fromJson(Map<String, dynamic> json) =>
      _$RideRequestFromJson(json);
}
