import 'package:google_places_autocomplete_text_field/google_places_autocomplete_text_field.dart'
    show Prediction;
import 'package:ulendo_models/ulendo_models.dart';

/// Converts Places lookup results into validated request locations.
class RideLocationRepository {
  Location resolve(Prediction prediction) {
    final lat = double.tryParse(prediction.lat ?? '');
    final lng = double.tryParse(prediction.lng ?? '');
    final address = prediction.description;
    if (lat == null ||
        lng == null ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat < -90 ||
        lat > 90 ||
        lng < -180 ||
        lng > 180 ||
        address == null ||
        address.trim().isEmpty) {
      throw const FormatException('Invalid location');
    }
    return Location(lat: lat, lng: lng, address: address);
  }
}
