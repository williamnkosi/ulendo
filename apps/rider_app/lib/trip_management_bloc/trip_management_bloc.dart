import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';

import 'trip_management_repository.dart';
import 'trip_management_event.dart';
import 'trip_management_state.dart';

/// BLoC for managing the entire rider trip lifecycle
/// Handles rider state transitions from initial → searching → accepted → in progress → completed
class TripManagementBloc extends Bloc<TripManagementEvent, TripManagementState> {
  final TripManagementRepository _repository;
  final Logger _logger = Logger(
    printer: PrefixPrinter(
      PrettyPrinter(methodCount: 0),
      info: '[TripManagementBloc]',
      error: '[TripManagementBloc]',
      warning: '[TripManagementBloc]',
      debug: '[TripManagementBloc]',
    ),
  );

  TripManagementBloc({required TripManagementRepository repository})
      : _repository = repository,
        super(const TripInitial()) {
    on<RequestTripEvent>(_onRequestTrip);
    on<TripAcceptedEvent>(_onTripAccepted);
    on<DriverArrivingAtPickupEvent>(_onDriverArrivingAtPickup);
    on<DriverArrivedAtPickupEvent>(_onDriverArrivedAtPickup);
    on<PassengerPickedUpEvent>(_onPassengerPickedUp);
    on<DriverArrivingAtDestinationEvent>(_onDriverArrivingAtDestination);
    on<DriverArrivedAtDestinationEvent>(_onDriverArrivedAtDestination);
    on<CompleteTripEvent>(_onCompleteTrip);
    on<CancelTripEvent>(_onCancelTrip);
    on<UpdateDriverLocationEvent>(_onUpdateDriverLocation);
    on<UpdateEstimatedTimeEvent>(_onUpdateEstimatedTime);
    on<RateTripEvent>(_onRateTrip);
  }

  /// Handle trip request
  Future<void> _onRequestTrip(
    RequestTripEvent event,
    Emitter<TripManagementState> emit,
  ) async {
    emit(const TripSearching());
    try {
      _logger.i('Requesting trip from ${event.pickup.address} to ${event.dropoff.address}');
      await _repository.requestTrip(
        pickup: event.pickup,
        dropoff: event.dropoff,
      );
      _logger.i('Trip requested successfully');
      // Stay in searching state while waiting for driver acceptance
    } catch (e) {
      _logger.e('Error requesting trip', error: e);
      emit(TripError(message: e.toString()));
    }
  }

  /// Handle trip acceptance from driver
  Future<void> _onTripAccepted(
    TripAcceptedEvent event,
    Emitter<TripManagementState> emit,
  ) async {
    try {
      _logger.i('Trip accepted by driver');
      emit(const TripAccepted());
    } catch (e) {
      _logger.e('Error handling trip acceptance', error: e);
      emit(TripError(message: e.toString()));
    }
  }

  /// Handle driver arriving at pickup
  Future<void> _onDriverArrivingAtPickup(
    DriverArrivingAtPickupEvent event,
    Emitter<TripManagementState> emit,
  ) async {
    try {
      _logger.i('Driver arriving at pickup');
      emit(const DriverEnRouteToPickup());
    } catch (e) {
      _logger.e('Error handling driver arriving at pickup', error: e);
      emit(TripError(message: e.toString()));
    }
  }

  /// Handle driver arrived at pickup
  Future<void> _onDriverArrivedAtPickup(
    DriverArrivedAtPickupEvent event,
    Emitter<TripManagementState> emit,
  ) async {
    try {
      _logger.i('Driver has arrived at pickup location');
      emit(const WaitingForPickup());
    } catch (e) {
      _logger.e('Error handling driver arrived at pickup', error: e);
      emit(TripError(message: e.toString()));
    }
  }

  /// Handle passenger picked up
  Future<void> _onPassengerPickedUp(
    PassengerPickedUpEvent event,
    Emitter<TripManagementState> emit,
  ) async {
    try {
      _logger.i('Passenger picked up');
      emit(const TripInProgress());
    } catch (e) {
      _logger.e('Error handling passenger picked up', error: e);
      emit(TripError(message: e.toString()));
    }
  }

  /// Handle driver arriving at destination
  Future<void> _onDriverArrivingAtDestination(
    DriverArrivingAtDestinationEvent event,
    Emitter<TripManagementState> emit,
  ) async {
    try {
      _logger.i('Driver arriving at destination');
      emit(const DriverArrivingAtDestination());
    } catch (e) {
      _logger.e('Error handling driver arriving at destination', error: e);
      emit(TripError(message: e.toString()));
    }
  }

  /// Handle driver arrived at destination
  Future<void> _onDriverArrivedAtDestination(
    DriverArrivedAtDestinationEvent event,
    Emitter<TripManagementState> emit,
  ) async {
    try {
      _logger.i('Driver has arrived at destination');
      emit(const ArrivedAtDestination());
    } catch (e) {
      _logger.e('Error handling driver arrived at destination', error: e);
      emit(TripError(message: e.toString()));
    }
  }

  /// Handle trip completion
  Future<void> _onCompleteTrip(
    CompleteTripEvent event,
    Emitter<TripManagementState> emit,
  ) async {
    try {
      _logger.i('Trip completed, waiting for rating');
      emit(const RatingTrip());
    } catch (e) {
      _logger.e('Error completing trip', error: e);
      emit(TripError(message: e.toString()));
    }
  }

  /// Handle trip cancellation
  Future<void> _onCancelTrip(
    CancelTripEvent event,
    Emitter<TripManagementState> emit,
  ) async {
    try {
      _logger.i('Trip cancelled');
      emit(const TripCancelled());
    } catch (e) {
      _logger.e('Error cancelling trip', error: e);
      emit(TripError(message: e.toString()));
    }
  }

  /// Update driver location in real-time
  Future<void> _onUpdateDriverLocation(
    UpdateDriverLocationEvent event,
    Emitter<TripManagementState> emit,
  ) async {
    try {
      _logger.d('Driver location updated');
      // State remains the same, just logging the update
    } catch (e) {
      _logger.e('Error updating driver location', error: e);
    }
  }

  /// Update estimated arrival time
  Future<void> _onUpdateEstimatedTime(
    UpdateEstimatedTimeEvent event,
    Emitter<TripManagementState> emit,
  ) async {
    try {
      _logger.d('Estimated time updated');
      // State remains the same, just logging the update
    } catch (e) {
      _logger.e('Error updating estimated time', error: e);
    }
  }

  /// Handle trip rating submission
  Future<void> _onRateTrip(
    RateTripEvent event,
    Emitter<TripManagementState> emit,
  ) async {
    try {
      _logger.i('Trip rated');
      emit(const TripCompleted());
    } catch (e) {
      _logger.e('Error rating trip', error: e);
      emit(TripError(message: e.toString()));
    }
  }
}
