part of 'location_tracking_bloc.dart';

/// Base class for location tracking states
abstract class LocationTrackingState extends Equatable {
  const LocationTrackingState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class LocationTrackingInitial extends LocationTrackingState {
  const LocationTrackingInitial();
}

/// Location tracking is active
class LocationTrackingActive extends LocationTrackingState {
  final Duration updateInterval;

  const LocationTrackingActive({required this.updateInterval});

  @override
  List<Object?> get props => [updateInterval];
}

/// Location tracking is inactive
class LocationTrackingInactive extends LocationTrackingState {
  const LocationTrackingInactive();
}

/// Loading state (starting/stopping tracking)
class LocationTrackingLoading extends LocationTrackingState {
  const LocationTrackingLoading();
}

/// Error state
class LocationTrackingError extends LocationTrackingState {
  final String message;

  const LocationTrackingError(this.message);

  @override
  List<Object?> get props => [message];
}
