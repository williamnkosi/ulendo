import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:driver_app/services/location_service.dart';
import 'package:driver_app/services/polyline_service.dart';
import 'package:driver_app/services/ride_management_service.dart';
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
  final RideManagementService _rideManagementService;

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
    required RideManagementService rideManagementService,
  }) : _locationService = locationService,
       _notificationHubBloc = notificationHubBloc,
       _polylineService = polylineService,
       _rideManagementService = rideManagementService,
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

      _logger.i(
        'Received ride offer: ${event.notification.rideId} from rider: ${event.notification.driverId}',
      );

      // Query database for full ride details using the service
      final rideId = event.notification.rideId;

      if (rideId == null || rideId.isEmpty) {
        _logger.e('Invalid rideId received: $rideId');
        emit(const RideManagementError('Invalid ride ID received'));
        return;
      }

      _logger.i('Querying ride details for rideId: $rideId');

      final rideData = await _rideManagementService.getRideDetails(rideId);

      if (rideData == null) {
        _logger.e('Ride data not found in database for rideId: $rideId');
        emit(
          RideManagementError(
            'Ride data not found in database for rideId: $rideId',
          ),
        );
        return;
      }

      _logger.d('Successfully fetched ride data: $rideData');

      // Extract pickup and dropoff coordinates from database
      final pickupData = rideData['pickup'] as Map<dynamic, dynamic>?;
      final dropoffData = rideData['dropoff'] as Map<dynamic, dynamic>?;

      _logger.d('Pickup data from database: $pickupData');
      _logger.d('Dropoff data from database: $dropoffData');

      if (pickupData == null || dropoffData == null) {
        _logger.e('Pickup or dropoff data missing in ride record');
        emit(
          const RideManagementError(
            'Invalid ride data: missing pickup or dropoff information',
          ),
        );
        return;
      }

      // Extract location arrays [lat, lng]
      final pickupLocation = pickupData['location'] as List<dynamic>;
      final dropoffLocation = dropoffData['location'] as List<dynamic>;

      _logger.d('Pickup location array: $pickupLocation');
      _logger.d('Dropoff location array: $dropoffLocation');

      final pickupLat = (pickupLocation[0] as num).toDouble();
      final pickupLng = (pickupLocation[1] as num).toDouble();
      final pickupAddress = (pickupData['address'] as String?) ?? '';

      final dropoffLat = (dropoffLocation[0] as num).toDouble();
      final dropoffLng = (dropoffLocation[1] as num).toDouble();
      final dropoffAddress = (dropoffData['address'] as String?) ?? '';

      _logger.i(
        'Extracted coordinates - Pickup: ($pickupLat, $pickupLng, "$pickupAddress"), Dropoff: ($dropoffLat, $dropoffLng, "$dropoffAddress")',
      );

      // Create RideRequest with database coordinates
      _currentRide = RideRequest(
        pickup: Location(
          address: pickupAddress,
          lat: pickupLat,
          lng: pickupLng,
        ),
        dropoff: Location(
          address: dropoffAddress,
          lat: dropoffLat,
          lng: dropoffLng,
        ),
      );

      _logger.i('Emitting RideOffered state for ride: $rideId');

      // Create an updated notification with all the ride details from database
      final enrichedNotification = event.notification.copyWith(
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        pickupAddress: pickupAddress,
        dropoffLat: dropoffLat,
        dropoffLng: dropoffLng,
        dropoffAddress: dropoffAddress,
      );

      emit(
        RideOffered(
          notification: enrichedNotification,
          currentLocation:
              _currentLocation ??
              const LocationData(driverId: '', latitude: 0, longitude: 0),
        ),
      );
    } catch (e) {
      _logger.e('Error in _onRideOfferReceived: $e');
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
        _logger.e(
          'Cannot accept ride: _currentRide is ${_currentRide == null ? 'NULL' : 'SET'}, _currentRideId is ${_currentRideId == null ? 'NULL' : 'SET'}',
        );
        emit(const RideManagementError('No ride to accept'));
        return;
      }

      _logger.i('Driver accepted ride: $_currentRideId');
      _logger.d('_currentRide pickup: ${_currentRide!.pickup}');
      _logger.d('_currentRide dropoff: ${_currentRide!.dropoff}');

      // Emit loading state while processing
      emit(
        RideAcceptanceLoading(
          notification:
              _currentNotification ??
              RideNotificationMessage(
                rideId: _currentRideId!,
                driverId: '',
                pickupAddress: _currentRide!.pickup.address,
                dropoffAddress: _currentRide!.dropoff.address,
                pickupLat: _currentRide!.pickup.lat,
                pickupLng: _currentRide!.pickup.lng,
                dropoffLat: _currentRide!.dropoff.lat,
                dropoffLng: _currentRide!.dropoff.lng,
                status: 'driver_accepted',
              ),
          currentLocation:
              _currentLocation ??
              const LocationData(driverId: '', latitude: 0, longitude: 0),
        ),
      );

      // Fetch polylines from DRIVER'S CURRENT LOCATION to PICKUP
      Set<Polyline>? polylines;
      final driverLat = _currentLocation?.latitude ?? 0.0;
      final driverLng = _currentLocation?.longitude ?? 0.0;
      final pickupLat = _currentRide!.pickup.lat;
      final pickupLng = _currentRide!.pickup.lng;

      _logger.i(
        'Fetching polylines from driver (${driverLat}, ${driverLng}) to pickup ($pickupLat, $pickupLng)',
      );

      if (driverLat == 0.0 ||
          driverLng == 0.0 ||
          pickupLat == 0.0 ||
          pickupLng == 0.0) {
        _logger.e(
          'INVALID COORDINATES: Driver($driverLat, $driverLng) Pickup($pickupLat, $pickupLng)',
        );
      }

      try {
        polylines = await _polylineService.getPolylines(
          pickupLat: driverLat,
          pickupLng: driverLng,
          dropoffLat: pickupLat,
          dropoffLng: pickupLng,
        );
        _logger.i(
          'Polylines fetched successfully: ${polylines.length} polylines',
        );
        if (polylines.isNotEmpty) {
          final poly = polylines.first;
          _logger.i(
            'First polyline: id=${poly.polylineId.value}, points=${poly.points.length}, color=${poly.color}, width=${poly.width}',
          );
        }
      } catch (polylineError) {
        _logger.e('Failed to fetch polylines: $polylineError');
        polylines = {};
        // Continue even if polylines fail - non-critical feature
      }

      // Transition to EnRouteToPickup with polylines
      _logger.i(
        'Emitting EnRouteToPickup state with ${polylines.length} polylines',
      );
      if (polylines.isNotEmpty) {
        _logger.i(
          '🎯 EMITTING WITH POLYLINES - Details: ${polylines.map((p) => 'id=${p.polylineId.value}, points=${p.points.length}').join(', ')}',
        );
      } else {
        _logger.w('⚠️ EMITTING WITHOUT POLYLINES - polylines is EMPTY');
      }
      emit(
        EnRouteToPickup(
          rideRequest: _currentRide!,
          currentLocation:
              _currentLocation ??
              const LocationData(driverId: '', latitude: 0, longitude: 0),
          rideId: _currentRideId!,
          polylines: polylines,
        ),
      );
    } catch (e) {
      _logger.e('Exception in _onAcceptRide: $e');
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

      // Calculate polylines from driver's current location to dropoff
      Set<Polyline> polylines = {};
      if (_currentLocation != null) {
        final driverLat = _currentLocation!.latitude;
        final driverLng = _currentLocation!.longitude;
        final dropoffLat = _currentRide!.dropoff.lat;
        final dropoffLng = _currentRide!.dropoff.lng;

        _logger.i(
          '🎯 Calculating polylines to destination: '
          'from (${driverLat.toStringAsFixed(4)}, ${driverLng.toStringAsFixed(4)}) '
          'to (${dropoffLat.toStringAsFixed(4)}, ${dropoffLng.toStringAsFixed(4)})',
        );

        polylines = await _polylineService.getPolylines(
          pickupLat: driverLat,
          pickupLng: driverLng,
          dropoffLat: dropoffLat,
          dropoffLng: dropoffLng,
        );

        _logger.i('💡 Emitting EnRouteToDestination state with ${polylines.length} polylines');
      } else {
        _logger.w('⚠️ Current location is null, cannot calculate polylines to destination');
      }

      emit(
        EnRouteToDestination(
          rideRequest: _currentRide!,
          currentLocation:
              _currentLocation ??
              const LocationData(driverId: '', latitude: 0, longitude: 0),
          rideId: _currentRideId!,
          polylines: polylines,
        ),
      );
    } catch (e) {
      _logger.e('Error in _onPassengerPickedUp: ${e.toString()}');
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
          polylines: s.polylines,
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
          polylines: s.polylines,
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
          polylines: s.polylines,
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
          polylines: s.polylines,
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
