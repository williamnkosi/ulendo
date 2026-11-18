import 'package:flutter_test/flutter_test.dart';
import 'package:google_places_autocomplete_text_field/google_places_autocomplete_text_field.dart'
    show Prediction;
import 'package:rider_app/home/ride_location_repository.dart';
import 'package:ulendo_models/ulendo_models.dart';

void main() {
  final repository = RideLocationRepository();

  for (final coordinates in <(String?, String?)>[
    (null, '28'),
    ('-15', null),
    ('invalid', '28'),
    ('NaN', '28'),
    ('-15', 'Infinity'),
    ('90.1', '28'),
    ('-90.1', '28'),
    ('-15', '180.1'),
    ('-15', '-180.1'),
  ]) {
    test('rejects invalid coordinates $coordinates', () {
      expect(
        () => repository.resolve(
          Prediction(
            description: 'Pickup',
            lat: coordinates.$1,
            lng: coordinates.$2,
          ),
        ),
        throwsFormatException,
      );
    });
  }

  test('accepts geographic boundaries', () {
    expect(
      repository.resolve(
        Prediction(description: 'Pickup', lat: '-90', lng: '180'),
      ),
      const Location(lat: -90, lng: 180, address: 'Pickup'),
    );
    expect(
      repository.resolve(
        Prediction(description: 'Pickup', lat: '90', lng: '-180'),
      ),
      const Location(lat: 90, lng: -180, address: 'Pickup'),
    );
  });

  for (final address in <String?>[null, '', '   ']) {
    test('rejects empty address $address', () {
      expect(
        () => repository.resolve(
          Prediction(description: address, lat: '-15', lng: '28'),
        ),
        throwsFormatException,
      );
    });
  }
}
