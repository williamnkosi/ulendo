part of 'ride_management_bloc.dart';

/// Base class for all RideManagement events
abstract class RideManagementEvent extends Equatable {
  const RideManagementEvent();

  @override
  List<Object?> get props => [];
}

/// Toggle driver status to online
class GoOnlineEvent extends RideManagementEvent {
  const GoOnlineEvent();
}

/// Toggle driver status to offline
class GoOfflineEvent extends RideManagementEvent {
  const GoOfflineEvent();
}

/// A new ride has been offered to the driver
class RideOfferReceivedEvent extends RideManagementEvent {
  final RideRequest rideRequest;
  final String rideId;

  const RideOfferReceivedEvent({
    required this.rideRequest,
    required this.rideId,
  });

  @override
  List<Object?> get props => [rideRequest, rideId];
}

/// Driver accepts the ride offer
class AcceptRideEvent extends RideManagementEvent {
  const AcceptRideEvent();
}

/// Driver has arrived at the pickup location
class ArrivedAtPickupEvent extends RideManagementEvent {
  const ArrivedAtPickupEvent();
}

/// Passenger has been picked up
class PassengerPickedUpEvent extends RideManagementEvent {
  const PassengerPickedUpEvent();
}

/// Driver has arrived at the destination
class ArrivedAtDestinationEvent extends RideManagementEvent {
  const ArrivedAtDestinationEvent();
}

/// Ride has been completed
class CompleteRideEvent extends RideManagementEvent {
  const CompleteRideEvent();
}

/// Update driver's current location
class UpdateLocationEvent extends RideManagementEvent {
  final LocationData currentLocation;

  const UpdateLocationEvent(this.currentLocation);

  @override
  List<Object?> get props => [currentLocation];
}

/// Update estimated time to destination
class UpdateEstimatedTimeEvent extends RideManagementEvent {
  final double estimatedTime;

  const UpdateEstimatedTimeEvent(this.estimatedTime);

  @override
  List<Object?> get props => [estimatedTime];
}
