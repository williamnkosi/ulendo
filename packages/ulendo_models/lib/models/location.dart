import 'package:freezed_annotation/freezed_annotation.dart';

part 'location.freezed.dart';
part 'location.g.dart';

/// Location model with coordinates and address
@freezed
abstract class Location with _$Location {
  const factory Location({
    /// Latitude coordinate
    required double lat,

    /// Longitude coordinate
    required double lng,

    /// Address string
    required String address,
  }) = _Location;

  factory Location.fromJson(Map<String, dynamic> json) =>
      _$LocationFromJson(json);
}
