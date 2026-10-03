part of 'ride_management_bloc.dart';

/// Base class for all RideManagement states
abstract class RideManagementState extends Equatable {
  const RideManagementState();

  @override
  List<Object?> get props => [];
}

/// Driver is offline - not accepting rides
class Offline extends RideManagementState {
  const Offline();
}

/// Driver is online - waiting for ride offers
class Online extends RideManagementState {
  final LocationData? currentLocation;

  const Online({this.currentLocation});

  @override
  List<Object?> get props => [currentLocation];
}

/// A ride has been offered to the driver
class RideOffered extends RideManagementState {
  final RideNotificationMessage notification;
  final LocationData currentLocation;

  const RideOffered({
    required this.notification,
    required this.currentLocation,
  });

  @override
  List<Object?> get props => [notification, currentLocation];
}

/// Driver has accepted a ride offer
class RideAccepted extends RideManagementState {
  final RideNotificationMessage notification;
  final LocationData currentLocation;

  const RideAccepted({
    required this.notification,
    required this.currentLocation,
  });

  @override
  List<Object?> get props => [notification, currentLocation];
}

/// Loading state while processing ride acceptance and fetching polylines
class RideAcceptanceLoading extends RideManagementState {
  final RideNotificationMessage notification;
  final LocationData currentLocation;

  const RideAcceptanceLoading({
    required this.notification,
    required this.currentLocation,
  });

  @override
  List<Object?> get props => [notification, currentLocation];
}

/// Driver is en route to pickup location
class EnRouteToPickup extends RideManagementState {
  final RideRequest rideRequest;
  final LocationData currentLocation;
  final String rideId;
  final double? estimatedTimeToPickup;

  const EnRouteToPickup({
    required this.rideRequest,
    required this.currentLocation,
    required this.rideId,
    this.estimatedTimeToPickup,
  });

  @override
  List<Object?> get props => [
    rideRequest,
    currentLocation,
    rideId,
    estimatedTimeToPickup,
  ];
}

/// Driver has arrived at pickup location and is waiting for passenger
class Waiting extends RideManagementState {
  final RideRequest rideRequest;
  final LocationData currentLocation;
  final String rideId;

  const Waiting({
    required this.rideRequest,
    required this.currentLocation,
    required this.rideId,
  });

  @override
  List<Object?> get props => [rideRequest, currentLocation, rideId];
}

/// Passenger is in vehicle, en route to destination
class EnRouteToDestination extends RideManagementState {
  final RideRequest rideRequest;
  final LocationData currentLocation;
  final String rideId;
  final double? estimatedTimeToDestination;

  const EnRouteToDestination({
    required this.rideRequest,
    required this.currentLocation,
    required this.rideId,
    this.estimatedTimeToDestination,
  });

  @override
  List<Object?> get props => [
    rideRequest,
    currentLocation,
    rideId,
    estimatedTimeToDestination,
  ];
}

/// Ride has been completed
class RideCompleted extends RideManagementState {
  final RideRequest rideRequest;
  final LocationData? currentLocation;
  final String rideId;

  const RideCompleted({
    required this.rideRequest,
    this.currentLocation,
    required this.rideId,
  });

  @override
  List<Object?> get props => [rideRequest, currentLocation, rideId];
}

/// Error state for ride management
class RideManagementError extends RideManagementState {
  final String message;

  const RideManagementError(this.message);

  @override
  List<Object?> get props => [message];
}
