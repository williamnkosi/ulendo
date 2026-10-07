import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:driver_app/rides/bloc/ride_management_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Widget that displays a live map of the driver's current location
/// Updates in real-time as location data is emitted through RideManagementBloc state
class LiveLocationMap extends StatefulWidget {
  const LiveLocationMap({super.key});

  @override
  State<LiveLocationMap> createState() => _LiveLocationMapState();
}

class _LiveLocationMapState extends State<LiveLocationMap> {
  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();

  Set<Marker> _markers = {};
  CameraPosition? _currentCameraPosition;

  final Logger _logger = Logger(
    printer: PrefixPrinter(
      PrettyPrinter(methodCount: 0),
      info: '[LiveLocationMap]',
      error: '[LiveLocationMap]',
      warning: '[LiveLocationMap]',
      debug: '[LiveLocationMap]',
    ),
  );

  @override
  void initState() {
    super.initState();
    // Initialize with current state if it has location
    final bloc = context.read<RideManagementBloc>();
    _logger.i(
      'Initializing LiveLocationMap - Current bloc state: ${bloc.state.runtimeType}',
    );
    _updateMapForState(bloc.state);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RideManagementBloc, RideManagementState>(
      listener: (context, state) {
        _logger.d('State changed: ${state.runtimeType}');
        _updateMapForState(state);
      },
      child: Scaffold(
        body: _currentCameraPosition == null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Waiting for location...\nCurrent position: $_currentCameraPosition',
                    ),
                  ],
                ),
              )
            : GoogleMap(
                mapType: MapType.normal,
                initialCameraPosition: _currentCameraPosition!,
                markers: _markers,
                polylines: const {},
                onMapCreated: (GoogleMapController controller) {
                  _controller.complete(controller);
                },
              ),
      ),
    );
  }

  void _updateMapForState(RideManagementState state) {
    final location = _getCurrentLocationFromState(state);
    _logger.d(
      'Updating map for state: ${state.runtimeType}, Location: $location',
    );

    if (location != null) {
      _logger.i(
        'Updating marker location: (${location.latitude}, ${location.longitude})',
      );

      final newMarker = Marker(
        markerId: const MarkerId('driver_location'),
        position: LatLng(location.latitude, location.longitude),
        infoWindow: const InfoWindow(
          title: 'Driver Location',
          snippet: 'Current position',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      );

      setState(() {
        _markers = {newMarker};
        _currentCameraPosition = CameraPosition(
          target: LatLng(location.latitude, location.longitude),
          zoom: 16.0,
        );
      });

      // Animate camera to new position
      _controller.future
          .then((controller) {
            _logger.d(
              'Animating camera to new position: (${location.latitude}, ${location.longitude})',
            );
            controller.animateCamera(
              CameraUpdate.newCameraPosition(_currentCameraPosition!),
            );
          })
          .catchError((error) {
            _logger.e('Error animating camera: $error');
          });
    }
  }

  dynamic _getCurrentLocationFromState(RideManagementState state) {
    if (state is Online) return state.currentLocation;
    if (state is RideOffered) return state.currentLocation;
    if (state is RideAcceptanceLoading) return state.currentLocation;
    if (state is EnRouteToPickup) return state.currentLocation;
    if (state is Waiting) return state.currentLocation;
    if (state is EnRouteToDestination) return state.currentLocation;
    if (state is RideCompleted) return state.currentLocation;
    return null;
  }
}
