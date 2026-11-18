import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/trip_management_bloc/trip_management_repository.dart';
import 'package:ulendo_models/ulendo_models.dart';

void main() {
  const pickup = Location(lat: -15, lng: 28, address: 'Pickup');
  const dropoff = Location(lat: -16, lng: 29, address: 'Dropoff');
  const returnedPickup = Location(lat: -15.1, lng: 28.1, address: 'Confirmed');

  Map<Object?, Object?> successfulResponse() => {
    'success': true,
    'message': 'Ride request received successfully',
    'rideId': 'ride-123',
    'pickup': Map<Object?, Object?>.from(returnedPickup.toJson()),
    'dropoff': Map<Object?, Object?>.from(dropoff.toJson()),
  };

  test('calls requestRideFunction and returns server locations', () async {
    final callable = _FakeCallable(response: successfulResponse());
    final functions = _FakeFunctions(callable);
    final repository = TripManagementRepositoryImpl(functions: functions);

    final result = await repository.requestTrip(
      pickup: pickup,
      dropoff: dropoff,
    );

    expect(functions.calledName, 'requestRideFunction');
    expect(callable.parameters, {
      'pickup': pickup.toJson(),
      'dropoff': dropoff.toJson(),
    });
    expect(result, const RideRequest(pickup: returnedPickup, dropoff: dropoff));
    expect(callable.callCount, 1);
  });

  for (final response in <Object?>[
    null,
    'invalid',
    {...successfulResponse(), 'success': false},
    {...successfulResponse()}..remove('success'),
    {...successfulResponse()}..remove('pickup'),
    {
      ...successfulResponse(),
      'dropoff': {'address': 'Missing coordinates'},
    },
  ]) {
    test('rejects malformed or unsuccessful response: $response', () async {
      final repository = TripManagementRepositoryImpl(
        functions: _FakeFunctions(_FakeCallable(response: response)),
      );

      await expectLater(
        repository.requestTrip(pickup: pickup, dropoff: dropoff),
        throwsA(isA<Exception>()),
      );
    });
  }

  test(
    'reports callable failure without returning a successful request',
    () async {
      final callable = _FakeCallable(
        error: FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'You already have an active ride.',
        ),
      );
      final repository = TripManagementRepositoryImpl(
        functions: _FakeFunctions(callable),
      );

      await expectLater(
        repository.requestTrip(pickup: pickup, dropoff: dropoff),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('You already have an active ride.'),
          ),
        ),
      );
      expect(callable.callCount, 1);
    },
  );
}

class _FakeFunctions implements FirebaseFunctions {
  _FakeFunctions(this.callable);

  final HttpsCallable callable;
  String? calledName;

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    calledName = name;
    return callable;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCallable implements HttpsCallable {
  _FakeCallable({this.response, this.error});

  final Object? response;
  final Exception? error;
  Object? parameters;
  int callCount = 0;

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    this.parameters = parameters;
    callCount++;
    if (error != null) throw error!;
    return _FakeResult<T>(response as T);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeResult<T> implements HttpsCallableResult<T> {
  _FakeResult(this.data);

  @override
  final T data;
}
