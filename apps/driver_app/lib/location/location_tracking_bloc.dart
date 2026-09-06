import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:driver_app/services/location_service.dart';

part 'location_tracking_event.dart';
part 'location_tracking_state.dart';

/// BLoC for managing location tracking state and events
class LocationTrackingBloc
    extends Bloc<LocationTrackingEvent, LocationTrackingState> {
  final LocationService _locationService;

  LocationTrackingBloc({required LocationService locationService})
    : _locationService = locationService,
      super(const LocationTrackingInitial()) {
    on<StartLocationTracking>(_onStartLocationTracking);
    on<StopLocationTracking>(_onStopLocationTracking);
    on<UpdateLocationInterval>(_onUpdateLocationInterval);
  }

  /// Handle start location tracking event
  Future<void> _onStartLocationTracking(
    StartLocationTracking event,
    Emitter<LocationTrackingState> emit,
  ) async {
    emit(const LocationTrackingLoading());

    try {
      final interval = event.updateInterval ?? const Duration(seconds: 10);

      await _locationService.startLocationStreaming(updateInterval: interval);

      emit(LocationTrackingActive(updateInterval: interval));
    } catch (e) {
      emit(
        LocationTrackingError(
          'Failed to start location tracking: ${e.toString()}',
        ),
      );
    }
  }

  /// Handle stop location tracking event
  Future<void> _onStopLocationTracking(
    StopLocationTracking event,
    Emitter<LocationTrackingState> emit,
  ) async {
    emit(const LocationTrackingLoading());

    try {
      await _locationService.stopLocationStreaming();
      emit(const LocationTrackingInactive());
    } catch (e) {
      emit(
        LocationTrackingError(
          'Failed to stop location tracking: ${e.toString()}',
        ),
      );
    }
  }

  /// Handle update location interval event
  Future<void> _onUpdateLocationInterval(
    UpdateLocationInterval event,
    Emitter<LocationTrackingState> emit,
  ) async {
    try {
      await _locationService.updateStreamInterval(event.newInterval);

      // Update state with new interval
      if (state is LocationTrackingActive) {
        emit(LocationTrackingActive(updateInterval: event.newInterval));
      }
    } catch (e) {
      emit(
        LocationTrackingError(
          'Failed to update location interval: ${e.toString()}',
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    await _locationService.dispose();
    return super.close();
  }
}
