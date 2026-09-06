part of 'location_tracking_bloc.dart';

/// Base class for location tracking events
abstract class LocationTrackingEvent extends Equatable {
  const LocationTrackingEvent();

  @override
  List<Object?> get props => [];
}

/// Event to start location tracking
class StartLocationTracking extends LocationTrackingEvent {
  /// Duration interval for location updates (default: 10 seconds)
  final Duration? updateInterval;

  const StartLocationTracking({this.updateInterval});

  @override
  List<Object?> get props => [updateInterval];
}

/// Event to stop location tracking
class StopLocationTracking extends LocationTrackingEvent {
  const StopLocationTracking();
}

/// Event to update the location update interval
class UpdateLocationInterval extends LocationTrackingEvent {
  final Duration newInterval;

  const UpdateLocationInterval(this.newInterval);

  @override
  List<Object?> get props => [newInterval];
}
