import 'package:freezed_annotation/freezed_annotation.dart';

part 'ride_notification_message.freezed.dart';
part 'ride_notification_message.g.dart';

/// Custom converter for double values from JSON (handles string to double conversion)
class DoubleConverter implements JsonConverter<double, dynamic> {
  const DoubleConverter();

  @override
  double fromJson(dynamic json) {
    if (json is double) return json;
    if (json is int) return json.toDouble();
    if (json is String) return double.tryParse(json) ?? 0.0;
    return 0.0;
  }

  @override
  dynamic toJson(double object) => object;
}

/// Custom converter for DateTime from milliseconds timestamp
class DateTimeConverter implements JsonConverter<DateTime, int> {
  const DateTimeConverter();

  @override
  DateTime fromJson(int json) => DateTime.fromMillisecondsSinceEpoch(json);

  @override
  int toJson(DateTime object) => object.millisecondsSinceEpoch;
}

/// Model for ride notification messages received from FCM
@freezed
abstract class RideNotificationMessage with _$RideNotificationMessage {
  const factory RideNotificationMessage({
    String? rideId,
    String? driverId,
    String? pickupAddress,
    @DoubleConverter() double? pickupLat,
    @DoubleConverter() double? pickupLng,
    String? dropoffAddress,
    @DoubleConverter() double? dropoffLat,
    @DoubleConverter() double? dropoffLng,
    @DoubleConverter() double? distanceToPickup,
    String? status,
    String? title,
    String? body,
    DateTime? sentTime,
  }) = _RideNotificationMessage;

  factory RideNotificationMessage.fromJson(Map<String, dynamic> json) =>
      _$RideNotificationMessageFromJson(json);
}
