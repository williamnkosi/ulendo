import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:driver_app/rides/bloc/ride_management_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Dedicated map widget for displaying routes during EnRouteToPickup state
/// Shows polylines from driver's current location to pickup location
class RouteMap extends StatefulWidget {
  const RouteMap({super.key});

  @override
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap> {
  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  CameraPosition? _currentCameraPosition;

  final Logger _logger = Logger(
    printer: PrefixPrinter(
      PrettyPrinter(methodCount: 0),
      info: '[RouteMap]',
      error: '[RouteMap]',
      warning: '[RouteMap]',
      debug: '[RouteMap]',
    ),
  );

  @override
  void initState() {
    super.initState();
    final bloc = context.read<RideManagementBloc>();
    _logger.i('Initializing RouteMap - Current bloc state: ${bloc.state.runtimeType}');
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
                      'Loading route...\nCurrent position: $_currentCameraPosition',
                    ),
                  ],
                ),
              )
            : Stack(
                children: [
                  GoogleMap(
                    mapType: MapType.normal,
                    initialCameraPosition: _currentCameraPosition!,
                    markers: _markers,
                    polylines: _polylines,
                    onMapCreated: (GoogleMapController controller) {
                      _controller.complete(controller);
                    },
                  ),
                  // Route info panel
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: _buildRouteInfoPanel(),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildRouteInfoPanel() {
    return BlocBuilder<RideManagementBloc, RideManagementState>(
      builder: (context, state) {
        if (state is EnRouteToPickup) {
          return Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'En Route to Pickup',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pickup Location',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            Text(
                              state.rideRequest.pickup.address,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Polylines: ${_polylines.length} | Points: ${_polylines.isNotEmpty ? _polylines.first.points.length : 0}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  void _updateMapForState(RideManagementState state) {
    if (state is! EnRouteToPickup) {
      _logger.d('State is not EnRouteToPickup (${state.runtimeType}), clearing map');
      return;
    }

    _logger.d('Updating RouteMap for EnRouteToPickup state');

    // Update polylines
    if (state.polylines != null && state.polylines!.isNotEmpty) {
      _logger.i('Setting polylines: ${state.polylines!.length} polylines');
      for (var polyline in state.polylines!) {
        _logger.i(
          'Polyline: id=${polyline.polylineId.value}, points=${polyline.points.length}',
        );
      }
      _polylines = state.polylines!;
    } else {
      _logger.w('No polylines available in EnRouteToPickup state');
      _polylines = {};
    }

    // Update markers: driver location (blue) and pickup location (green)
    final driverLocation = state.currentLocation;
    final pickupLocation = state.rideRequest.pickup;

    Set<Marker> newMarkers = {};

    // Driver marker (blue)
    newMarkers.add(
      Marker(
        markerId: const MarkerId('driver_location'),
        position: LatLng(driverLocation.latitude, driverLocation.longitude),
        infoWindow: const InfoWindow(
          title: 'Your Location',
          snippet: 'Current position',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
    );

    // Pickup marker (green)
    newMarkers.add(
      Marker(
        markerId: const MarkerId('pickup_location'),
        position: LatLng(pickupLocation.lat, pickupLocation.lng),
        infoWindow: InfoWindow(
          title: 'Pickup Location',
          snippet: pickupLocation.address,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
    );

    setState(() {
      _markers = newMarkers;
      _currentCameraPosition = CameraPosition(
        target: LatLng(driverLocation.latitude, driverLocation.longitude),
        zoom: 14.0,
      );
      _logger.i(
        'setState: Updated markers (${_markers.length}), polylines (${_polylines.length}), camera at (${driverLocation.latitude}, ${driverLocation.longitude})',
      );
    });

    // Animate camera
    _controller.future
        .then((controller) {
          _logger.d(
            'Animating camera to driver location: (${driverLocation.latitude}, ${driverLocation.longitude})',
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
