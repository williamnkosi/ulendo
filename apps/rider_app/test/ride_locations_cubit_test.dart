import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_places_autocomplete_text_field/google_places_autocomplete_text_field.dart'
    show Prediction;
import 'package:mocktail/mocktail.dart';
import 'package:rider_app/home/ride_location_repository.dart';
import 'package:rider_app/home/ride_locations_cubit.dart';
import 'package:ulendo_models/ulendo_models.dart';

class _MockRepository extends Mock implements RideLocationRepository {}

void main() {
  const pickupLocation = Location(lat: -15, lng: 28, address: 'Pickup');
  const dropoffLocation = Location(lat: -16, lng: 29, address: 'Dropoff');
  late _MockRepository repository;
  late Prediction pickup;
  late Prediction dropoff;

  setUp(() {
    repository = _MockRepository();
    pickup = Prediction(description: 'Pickup', placeId: 'pickup');
    dropoff = Prediction(description: 'Dropoff', placeId: 'dropoff');
    when(() => repository.resolve(pickup)).thenReturn(pickupLocation);
    when(() => repository.resolve(dropoff)).thenReturn(dropoffLocation);
  });

  RideLocationsCubit build() => RideLocationsCubit(repository: repository);

  test('starts initial', () async {
    final cubit = build();
    expect(cubit.state, const RideLocationsState.initial());
    await cubit.close();
  });

  blocTest<RideLocationsCubit, RideLocationsState>(
    'both selections stay pending until both lookups resolve',
    build: build,
    act: (cubit) {
      cubit.selected(RideLocationField.pickup, pickup);
      cubit.selected(RideLocationField.dropoff, dropoff);
      cubit.resolved(RideLocationField.pickup, pickup);
      expect(cubit.state, const RideLocationsState.pending());
      cubit.resolved(RideLocationField.dropoff, dropoff);
    },
    expect: () => [
      const RideLocationsState.pending(),
      const RideLocationsState.ready(
        pickup: pickupLocation,
        dropoff: dropoffLocation,
      ),
    ],
  );

  blocTest<RideLocationsCubit, RideLocationsState>(
    'invalid coordinates or conversion failure produces user-safe failure',
    build: build,
    setUp: () =>
        when(() => repository.resolve(pickup))
            .thenThrow(const FormatException('secret details')),
    act: (cubit) {
      cubit.selected(RideLocationField.pickup, pickup);
      cubit.resolved(RideLocationField.pickup, pickup);
    },
    expect: () => [
      const RideLocationsState.pending(),
      const RideLocationsState.failure(
        'Could not resolve this location. Please select it again.',
      ),
    ],
  );

  blocTest<RideLocationsCubit, RideLocationsState>(
    'lookup failure invalidates pending response',
    build: build,
    act: (cubit) {
      cubit.selected(RideLocationField.pickup, pickup);
      cubit.lookupFailed(RideLocationField.pickup);
      cubit.resolved(RideLocationField.pickup, pickup);
    },
    expect: () => [
      const RideLocationsState.pending(),
      const RideLocationsState.failure(
        'Location lookup failed. Please select the location again.',
      ),
    ],
    verify: (_) => verifyNever(() => repository.resolve(pickup)),
  );

  blocTest<RideLocationsCubit, RideLocationsState>(
    'older response for same place cannot replace newer selection',
    build: build,
    act: (cubit) {
      final newer = Prediction(description: 'Pickup', placeId: 'pickup');
      when(() => repository.resolve(newer)).thenReturn(pickupLocation);
      cubit.selected(RideLocationField.pickup, pickup);
      cubit.selected(RideLocationField.pickup, newer);
      cubit.resolved(RideLocationField.pickup, pickup);
      cubit.resolved(RideLocationField.pickup, newer);
    },
    expect: () => [const RideLocationsState.pending()],
    verify: (_) => verifyNever(() => repository.resolve(pickup)),
  );

  blocTest<RideLocationsCubit, RideLocationsState>(
    'editing ready selection invalidates readiness and rejects its late callback',
    build: build,
    act: (cubit) {
      cubit.selected(RideLocationField.pickup, pickup);
      cubit.selected(RideLocationField.dropoff, dropoff);
      cubit.resolved(RideLocationField.pickup, pickup);
      cubit.resolved(RideLocationField.dropoff, dropoff);
      cubit.textChanged(RideLocationField.pickup, 'New text');
      cubit.textChanged(RideLocationField.pickup, 'Pickup');
      cubit.resolved(RideLocationField.pickup, pickup);
    },
    expect: () => [
      const RideLocationsState.pending(),
      const RideLocationsState.ready(
        pickup: pickupLocation,
        dropoff: dropoffLocation,
      ),
      const RideLocationsState.pending(),
    ],
    verify: (_) => verify(() => repository.resolve(pickup)).called(1),
  );

  test('closed cubit ignores callbacks', () async {
    final cubit = build();
    cubit.selected(RideLocationField.pickup, pickup);
    await cubit.close();
    cubit.resolved(RideLocationField.pickup, pickup);
    cubit.textChanged(RideLocationField.pickup, 'changed');
    cubit.lookupFailed(RideLocationField.pickup);
    cubit.selected(RideLocationField.dropoff, dropoff);
    verifyNever(() => repository.resolve(pickup));
  });
}
