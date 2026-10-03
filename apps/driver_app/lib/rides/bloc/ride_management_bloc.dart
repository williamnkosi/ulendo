import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:driver_app/services/location_service.dart';
import 'package:driver_app/services/polyline_service.dart';
import 'package:driver_app/notifications/bloc/notification_hub_bloc.dart';
import 'package:ulendo_models/models/location_data.dart';
import 'package:ulendo_models/models/location.dart';
import 'package:ulendo_models/models/ride_request.dart';
import 'package:ulendo_models/models/ride_notification_message.dart';
import 'package:logger/logger.dart';

part 'ride_management_event.dart';
part 'ride_management_state.dart';

/// BLoC for managing the entire ride share experience
/// Handles driver state transitions from offline → online → ride offered → pickup → en route → completion
class RideManagementBloc
    extends Bloc<RideManagementEvent, RideManagementState> {
  final LocationService _locationService;
  final NotificationHubBloc _notificationHubBloc;
  final PolylineService _polylineService;

  final Logger _logger = Logger(
    printer: PrefixPrinter(
      PrettyPrinter(methodCount: 0),
      info: '[RideManagementBloc]',
      error: '[RideManagementBloc]',
      warning: '[RideManagementBloc]',
      debug: '[RideManagementBloc]',
    ),
  );

  // Store ride and location data
  RideRequest? _currentRide;
  String? _currentRideId;
  LocationData? _currentLocation;
  RideNotificationMessage? _currentNotification;

  RideManagementBloc({
    required LocationService locationService,
    required NotificationHubBloc notificationHubBloc,
    required PolylineService polylineService,
  }) : _locationService = locationService,
       _notificationHubBloc = notificationHubBloc,
       _polylineService = polylineService,
       super(const Offline()) {
    on<GoOnlineEvent>(_onGoOnline);
    on<GoOfflineEvent>(_onGoOffline);
    on<RideOfferReceivedEvent>(_onRideOfferReceived);
    on<AcceptRideEvent>(_onAcceptRide);
    on<ArrivedAtPickupEvent>(_onArrivedAtPickup);
    on<PassengerPickedUpEvent>(_onPassengerPickedUp);
    on<ArrivedAtDestinationEvent>(_onArrivedAtDestination);
    on<CompleteRideEvent>(_onCompleteRide);
    on<UpdateLocationEvent>(_onUpdateLocation);
    on<UpdateEstimatedTimeEvent>(_onUpdateEstimatedTime);

    // Listen to notification hub for ride offers
    _listenToNotifications();
  }

  /// Getter to access the polyline service
  PolylineService get polylineService => _polylineService;

  /// Listen to notifications from NotificationHubBloc
  void _listenToNotifications() {
    _notificationHubBloc.stream.listen((state) {
      if (state is NotificationReceivedState) {
        _logger.d('Received notification in RideManagementBloc');

        try {
          // Parse notification data using freezed model
          final rideNotification = RideNotificationMessage.fromJson(
            state.message.data.cast<String, dynamic>(),
          );

          _logger.i(
            'Processing ride offer from notification: ${rideNotification.rideId}',
          );

          // Log ride details
          _logger.i('Ride notification details:');
          _logger.i('  Ride ID: ${rideNotification.rideId}');
          _logger.i('  Driver ID: ${rideNotification.driverId}');
          _logger.i('  Pickup: ${rideNotification.pickupAddress}');
          _logger.i('  Dropoff: ${rideNotification.dropoffAddress}');
          _logger.i('  Distance: ${rideNotification.distanceToPickup}km');
          _logger.i('  Status: ${rideNotification.status}');

          // Dispatch event to handle ride offer
          add(RideOfferReceivedEvent(notification: rideNotification));
        } catch (e) {
          _logger.e('Error processing ride offer from notification', error: e);
        }
      }
    });
  }

  /// Handle going online
  Future<void> _onGoOnline(
    GoOnlineEvent event,
    Emitter<RideManagementState> emit,
  ) async {
    try {
      // Start location tracking
      const interval = Duration(seconds: 10);
      await _locationService.startLocationStreaming(updateInterval: interval);

      // Listen to location updates and emit Online state with each update
      _locationService.listenToLocationUpdates().listen(
        (locationData) {
          _currentLocation = locationData;
          add(UpdateLocationEvent(locationData));
        },
        onError: (error) {
          emit(
            RideManagementError('Location stream error: ${error.toString()}'),
          );
        },
      );

      // Emit initial Online state
      emit(Online(currentLocation: _currentLocation));
    } catch (e) {
      emit(RideManagementError('Failed to go online: ${e.toString()}'));
    }
  }

  /// Handle going offline
  Future<void> _onGoOffline(
    GoOfflineEvent event,
    Emitter<RideManagementState> emit,
  ) async {
    try {
      // Stop location tracking
      await _locationService.stopLocationStreaming();

      // Clear ride data
      _currentRide = null;
      _currentRideId = null;

      emit(const Offline());
    } catch (e) {
      emit(RideManagementError('Failed to go offline: ${e.toString()}'));
    }
  }

  /// Handle new ride offer
  Future<void> _onRideOfferReceived(
    RideOfferReceivedEvent event,
    Emitter<RideManagementState> emit,
  ) async {
    try {
      _currentRideId = event.notification.rideId;
      _currentNotification = event.notification;

      // Convert notification to RideRequest for compatibility with other states
      _currentRide = RideRequest(
        pickup: Location(
          address: event.notification.pickupAddress ?? '',
          lat: event.notification.pickupLat ?? 0.0,
          lng: event.notification.pickupLng ?? 0.0,
        ),
        dropoff: Location(
          address: event.notification.dropoffAddress ?? '',
          lat: 0.0,
          lng: 0.0,
        ),
      );

      _logger.i(
        'Emitting RideOffered state for ride: ${event.notification.rideId}',
      );

      emit(
        RideOffered(
          notification: event.notification,
          currentLocation:
              _currentLocation ??
              const LocationData(driverId: '', latitude: 0, longitude: 0),
        ),
      );
    } catch (e) {
      emit(
        RideManagementError('Failed to receive ride offer: ${e.toString()}'),
      );
    }
  }

  /// Handle accepting ride
  Future<void> _onAcceptRide(
    AcceptRideEvent event,
    Emitter<RideManagementState> emit,
  ) async {
    try {
      if (_currentRide == null || _currentRideId == null) {
        emit(const RideManagementError('No ride to accept'));
        return;
      }

      _logger.i('Driver accepted ride: $_currentRideId');

      // First emit RideAccepted state
      emit(
        RideAccepted(
          notification:
              _currentNotification ??
              RideNotificationMessage(
                rideId: _currentRideId!,
                driverId: '',
                pickupAddress: _currentRide!.pickup.address,
                dropoffAddress: _currentRide!.dropoff.address,
                pickupLat: _currentRide!.pickup.lat,
                pickupLng: _currentRide!.pickup.lng,
                status: 'driver_accepted',
              ),
          currentLocation:
              _currentLocation ??
              const LocationData(driverId: '', latitude: 0, longitude: 0),
        ),
      );

      // Then transition to EnRouteToPickup
      emit(
        EnRouteToPickup(
          rideRequest: _currentRide!,
          currentLocation:
              _currentLocation ??
              const LocationData(driverId: '', latitude: 0, longitude: 0),
          rideId: _currentRideId!,
        ),
      );
    } catch (e) {
      emit(RideManagementError('Failed to accept ride: ${e.toString()}'));
    }
  }

  /// Handle arriving at pickup
  Future<void> _onArrivedAtPickup(
    ArrivedAtPickupEvent event,
    Emitter<RideManagementState> emit,
  ) async {
    try {
      if (_currentRide == null || _currentRideId == null) {
        emit(const RideManagementError('No active ride'));
        return;
      }

      emit(
        Waiting(
          rideRequest: _currentRide!,
          currentLocation:
              _currentLocation ??
              const LocationData(driverId: '', latitude: 0, longitude: 0),
          rideId: _currentRideId!,
        ),
      );
    } catch (e) {
      emit(RideManagementError('Failed to arrive at pickup: ${e.toString()}'));
    }
  }

  /// Handle passenger picked up
  Future<void> _onPassengerPickedUp(
    PassengerPickedUpEvent event,
    Emitter<RideManagementState> emit,
  ) async {
    try {
      if (_currentRide == null || _currentRideId == null) {
        emit(const RideManagementError('No active ride'));
        return;
      }

      emit(
        EnRouteToDestination(
          rideRequest: _currentRide!,
          currentLocation:
              _currentLocation ??
              const LocationData(driverId: '', latitude: 0, longitude: 0),
          rideId: _currentRideId!,
        ),
      );
    } catch (e) {
      emit(RideManagementError('Failed to pick up passenger: ${e.toString()}'));
    }
  }

  /// Handle arriving at destination
  Future<void> _onArrivedAtDestination(
    ArrivedAtDestinationEvent event,
    Emitter<RideManagementState> emit,
  ) async {
    try {
      if (_currentRide == null || _currentRideId == null) {
        emit(const RideManagementError('No active ride'));
        return;
      }

      // Stay in EnRouteToDestination until ride is completed
      // This allows driver to adjust if needed
      emit(
        EnRouteToDestination(
          rideRequest: _currentRide!,
          currentLocation:
              _currentLocation ??
              const LocationData(driverId: '', latitude: 0, longitude: 0),
          rideId: _currentRideId!,
        ),
      );
    } catch (e) {
      emit(
        RideManagementError('Failed to arrive at destination: ${e.toString()}'),
      );
    }
  }

  /// Handle ride completion
  Future<void> _onCompleteRide(
    CompleteRideEvent event,
    Emitter<RideManagementState> emit,
  ) async {
    try {
      if (_currentRide == null || _currentRideId == null) {
        emit(const RideManagementError('No active ride to complete'));
        return;
      }

      final completedRide = _currentRide!;
      final completedRideId = _currentRideId!;

      // Clear current ride data
      _currentRide = null;
      _currentRideId = null;

      emit(
        RideCompleted(
          rideRequest: completedRide,
          currentLocation: _currentLocation,
          rideId: completedRideId,
        ),
      );

      // Transition back to online after completion
      emit(Online(currentLocation: _currentLocation));
    } catch (e) {
      emit(RideManagementError('Failed to complete ride: ${e.toString()}'));
    }
  }

  /// Handle location updates
  Future<void> _onUpdateLocation(
    UpdateLocationEvent event,
    Emitter<RideManagementState> emit,
  ) async {
    _currentLocation = event.currentLocation;

    // Re-emit current state with updated location
    if (state is Online) {
      emit(Online(currentLocation: event.currentLocation));
    } else if (state is RideOffered) {
      final s = state as RideOffered;
      emit(
        RideOffered(
          notification: s.notification,
          currentLocation: event.currentLocation,
        ),
      );
    } else if (state is EnRouteToPickup) {
      final s = state as EnRouteToPickup;
      emit(
        EnRouteToPickup(
          rideRequest: s.rideRequest,
          currentLocation: event.currentLocation,
          rideId: s.rideId,
          estimatedTimeToPickup: s.estimatedTimeToPickup,
        ),
      );
    } else if (state is Waiting) {
      final s = state as Waiting;
      emit(
        Waiting(
          rideRequest: s.rideRequest,
          currentLocation: event.currentLocation,
          rideId: s.rideId,
        ),
      );
    } else if (state is EnRouteToDestination) {
      final s = state as EnRouteToDestination;
      emit(
        EnRouteToDestination(
          rideRequest: s.rideRequest,
          currentLocation: event.currentLocation,
          rideId: s.rideId,
          estimatedTimeToDestination: s.estimatedTimeToDestination,
        ),
      );
    } else if (state is RideCompleted) {
      final s = state as RideCompleted;
      emit(
        RideCompleted(
          rideRequest: s.rideRequest,
          currentLocation: event.currentLocation,
          rideId: s.rideId,
        ),
      );
    }
  }

  /// Handle estimated time updates
  Future<void> _onUpdateEstimatedTime(
    UpdateEstimatedTimeEvent event,
    Emitter<RideManagementState> emit,
  ) async {
    if (state is EnRouteToPickup) {
      final s = state as EnRouteToPickup;
      emit(
        EnRouteToPickup(
          rideRequest: s.rideRequest,
          currentLocation: s.currentLocation,
          rideId: s.rideId,
          estimatedTimeToPickup: event.estimatedTime,
        ),
      );
    } else if (state is EnRouteToDestination) {
      final s = state as EnRouteToDestination;
      emit(
        EnRouteToDestination(
          rideRequest: s.rideRequest,
          currentLocation: s.currentLocation,
          rideId: s.rideId,
          estimatedTimeToDestination: event.estimatedTime,
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
