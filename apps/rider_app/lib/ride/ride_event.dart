import 'package:equatable/equatable.dart';
import 'package:ulendo_models/ulendo_models.dart';

abstract class RideEvent extends Equatable {
  const RideEvent();

  @override
  List<Object?> get props => [];
}

class RequestRideEvent extends RideEvent {
  final Location pickup;
  final Location dropoff;

  const RequestRideEvent({required this.pickup, required this.dropoff});

  @override
  List<Object?> get props => [pickup, dropoff];
}

class CancelRideEvent extends RideEvent {
  final String rideId;

  const CancelRideEvent({required this.rideId});

  @override
  List<Object?> get props => [rideId];
}

class GetRideStatusEvent extends RideEvent {
  final String rideId;

  const GetRideStatusEvent({required this.rideId});

  @override
  List<Object?> get props => [rideId];
}

class GetActiveRideEvent extends RideEvent {
  const GetActiveRideEvent();
}

class CompleteRideEvent extends RideEvent {
  final String rideId;

  const CompleteRideEvent({required this.rideId});

  @override
  List<Object?> get props => [rideId];
}
