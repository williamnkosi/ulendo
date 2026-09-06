import 'package:freezed_annotation/freezed_annotation.dart';

part 'location_data.freezed.dart';
part 'location_data.g.dart';

/// Location data model for driver real-time location streaming
@freezed
class LocationData with _$LocationData {
  const factory LocationData({
    /// Unique identifier for the driver
    required String driverId,

    /// Latitude coordinate
    required double latitude,

    /// Longitude coordinate
    required double longitude,
  }) = _LocationData;

  factory LocationData.fromJson(Map<String, dynamic> json) =>
      _$LocationDataFromJson(json);
}
