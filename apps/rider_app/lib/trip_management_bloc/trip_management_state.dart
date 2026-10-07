import 'package:equatable/equatable.dart';

/// Base sealed class for all TripManagement states
sealed class TripManagementState extends Equatable {
  const TripManagementState();

  @override
  List<Object?> get props => [];
}

/// Initial state - no active trip
class TripInitial extends TripManagementState {
  const TripInitial();
}

/// Loading state while requesting a trip
class TripSearching extends TripManagementState {
  const TripSearching();
}

/// A driver has been found and accepted the trip
class TripAccepted extends TripManagementState {
  const TripAccepted();
}

/// Driver is en route to pickup location
class DriverEnRouteToPickup extends TripManagementState {
  const DriverEnRouteToPickup();
}

/// Driver has arrived at pickup location
class WaitingForPickup extends TripManagementState {
  const WaitingForPickup();
}

/// Passenger has been picked up and trip is in progress
class TripInProgress extends TripManagementState {
  const TripInProgress();
}

/// Driver is arriving at destination
class DriverArrivingAtDestination extends TripManagementState {
  const DriverArrivingAtDestination();
}

/// Driver has arrived at destination
class ArrivedAtDestination extends TripManagementState {
  const ArrivedAtDestination();
}

/// Trip has been completed
class TripCompleted extends TripManagementState {
  const TripCompleted();
}

/// Waiting for rider to rate the trip
class RatingTrip extends TripManagementState {
  const RatingTrip();
}

/// Trip has been cancelled
class TripCancelled extends TripManagementState {
  const TripCancelled();
}

/// Error state during trip management
class TripError extends TripManagementState {
  final String message;

  const TripError({required this.message});

  @override
  List<Object?> get props => [message];
}
