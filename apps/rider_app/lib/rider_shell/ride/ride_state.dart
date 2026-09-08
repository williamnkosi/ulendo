import 'package:equatable/equatable.dart';
import 'package:ulendo_models/ulendo_models.dart';

abstract class RideState extends Equatable {
  const RideState();

  @override
  List<Object?> get props => [];
}

class RideInitial extends RideState {
  const RideInitial();
}

class RideLoading extends RideState {
  const RideLoading();
}

class RideRequested extends RideState {
  final RideRequest rideRequest;

  const RideRequested({required this.rideRequest});

  @override
  List<Object?> get props => [rideRequest];
}

class RideAccepted extends RideState {
  final RideRequest rideRequest;
  final String driverId;

  const RideAccepted({
    required this.rideRequest,
    required this.driverId,
  });

  @override
  List<Object?> get props => [rideRequest, driverId];
}

class RideInProgress extends RideState {
  final RideRequest rideRequest;

  const RideInProgress({required this.rideRequest});

  @override
  List<Object?> get props => [rideRequest];
}

class RideCompleted extends RideState {
  final RideRequest rideRequest;

  const RideCompleted({required this.rideRequest});

  @override
  List<Object?> get props => [rideRequest];
}

class RideCancelled extends RideState {
  final RideRequest rideRequest;

  const RideCancelled({required this.rideRequest});

  @override
  List<Object?> get props => [rideRequest];
}

class RideError extends RideState {
  final String message;

  const RideError({required this.message});

  @override
  List<Object?> get props => [message];
}
