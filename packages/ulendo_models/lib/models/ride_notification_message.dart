import 'package:freezed_annotation/freezed_annotation.dart';

part 'ride_notification_message.freezed.dart';
part 'ride_notification_message.g.dart';

/// Model for ride notification messages received from FCM
@freezed
abstract class RideNotificationMessage with _$RideNotificationMessage {
  const factory RideNotificationMessage({
    required String rideId,
    required String driverId,
    required String pickupAddress,
    required double pickupLat,
    required double pickupLng,
    required String dropoffAddress,
    required double distanceToPickup,
    required String status,
    required String title,
    required String body,
    required DateTime sentTime,
  }) = _RideNotificationMessage;

  factory RideNotificationMessage.fromJson(Map<String, dynamic> json) =>
      _$RideNotificationMessageFromJson(json);
}
