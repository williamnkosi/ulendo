import 'package:equatable/equatable.dart';
import 'package:ulendo_models/models/location.dart';

/// Base class for all TripManagement events
abstract class TripManagementEvent extends Equatable {
  const TripManagementEvent();

  @override
  List<Object?> get props => [];
}

/// Request a new trip (ride)
class RequestTripEvent extends TripManagementEvent {
  final Location pickup;
  final Location dropoff;

  const RequestTripEvent({
    required this.pickup,
    required this.dropoff,
  });

  @override
  List<Object?> get props => [pickup, dropoff];
}

/// A driver has accepted the trip
class TripAcceptedEvent extends TripManagementEvent {
  const TripAcceptedEvent();
}

/// Driver is arriving at pickup location
class DriverArrivingAtPickupEvent extends TripManagementEvent {
  const DriverArrivingAtPickupEvent();
}

/// Driver has arrived at pickup location
class DriverArrivedAtPickupEvent extends TripManagementEvent {
  const DriverArrivedAtPickupEvent();
}

/// Passenger has been picked up
class PassengerPickedUpEvent extends TripManagementEvent {
  const PassengerPickedUpEvent();
}

/// Driver is arriving at destination
class DriverArrivingAtDestinationEvent extends TripManagementEvent {
  const DriverArrivingAtDestinationEvent();
}

/// Driver has arrived at destination
class DriverArrivedAtDestinationEvent extends TripManagementEvent {
  const DriverArrivedAtDestinationEvent();
}

/// Complete the trip
class CompleteTripEvent extends TripManagementEvent {
  const CompleteTripEvent();
}

/// Cancel the trip
class CancelTripEvent extends TripManagementEvent {
  const CancelTripEvent();
}

/// Update driver location in real-time
class UpdateDriverLocationEvent extends TripManagementEvent {
  const UpdateDriverLocationEvent();
}

/// Update estimated arrival time
class UpdateEstimatedTimeEvent extends TripManagementEvent {
  const UpdateEstimatedTimeEvent();
}

/// Rate the trip and driver
class RateTripEvent extends TripManagementEvent {
  const RateTripEvent();
}
