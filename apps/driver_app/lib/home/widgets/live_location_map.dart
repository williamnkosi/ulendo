import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
  Set<Polyline> _polylines = {};
  CameraPosition? _currentCameraPosition;

  @override
  void initState() {
    super.initState();
    // Initialize with current state if it has location
    final bloc = context.read<RideManagementBloc>();
    print('LiveLocationMap initState - Current bloc state: ${bloc.state}');
    _updateMapForState(bloc.state);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RideManagementBloc, RideManagementState>(
      listener: (context, state) {
        print('LiveLocationMap BlocListener - State: ${state.runtimeType}');
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
                polylines: _polylines,
                onMapCreated: (GoogleMapController controller) {
                  _controller.complete(controller);
                },
              ),
      ),
    );
  }

  void _updateMapForState(RideManagementState state) {
    final location = _getCurrentLocationFromState(state);
    print(
      '_updateMapForState - State: ${state.runtimeType}, Location: $location',
    );

    // Handle polylines for EnRouteToPickup state
    if (state is EnRouteToPickup && state.polylines != null) {
      print(
        'EnRouteToPickup state - Found ${state.polylines!.length} polylines',
      );
      setState(() {
        _polylines = state.polylines!;
      });
    } else {
      // Clear polylines for other states
      if (_polylines.isNotEmpty) {
        setState(() {
          _polylines = {};
        });
      }
    }

    if (location != null) {
      print('Location update: ${location.latitude}, ${location.longitude}');

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
            controller.animateCamera(
              CameraUpdate.newCameraPosition(_currentCameraPosition!),
            );
          })
          .catchError((error) {
            print('Error animating camera: $error');
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
