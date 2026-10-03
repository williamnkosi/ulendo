import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:driver_app/rides/bloc/ride_management_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Widget that displays a live map of the driver's current location
/// Updates in real-time as location data streams from the LocationTrackingBloc
class LiveLocationMap extends StatefulWidget {
  const LiveLocationMap({super.key});

  @override
  State<LiveLocationMap> createState() => _LiveLocationMapState();
}

class _LiveLocationMapState extends State<LiveLocationMap> {
  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();

  late final RideManagementBloc _rideBloc;
  
  Set<Marker> _markers = {};
  CameraPosition? _currentCameraPosition;

  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(37.42796133580664, -122.085749655962),
    zoom: 14.4746,
  );

  static const CameraPosition _kLake = CameraPosition(
    bearing: 192.8334901395799,
    target: LatLng(37.43296265331129, -122.08832357078792),
    tilt: 59.440717697143555,
    zoom: 19.151926040649414,
  );

  @override
  void initState() {
    super.initState();
    _currentCameraPosition = _kGooglePlex;
    _rideBloc = context.read<RideManagementBloc>();
    _setupLocationStream();
  }

  void _setupLocationStream() {
    _rideBloc.getLocationStream().listen(
      (locationData) {
        print(
          'Location update: ${locationData.latitude}, ${locationData.longitude}',
        );

        final newMarker = Marker(
          markerId: const MarkerId('driver_location'),
          position: LatLng(locationData.latitude, locationData.longitude),
          infoWindow: const InfoWindow(
            title: 'Driver Location',
            snippet: 'Current position',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueBlue,
          ),
        );

        setState(() {
          _markers = {newMarker};
          _currentCameraPosition = CameraPosition(
            target: LatLng(locationData.latitude, locationData.longitude),
            zoom: 16.0,
          );
        });

        // Animate camera to new position
        _controller.future.then((controller) {
          controller.animateCamera(
            CameraUpdate.newCameraPosition(_currentCameraPosition!),
          );
        });
      },
      onError: (error) {
        print('Location stream error: $error');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GoogleMap(
        mapType: MapType.normal,
        initialCameraPosition: _currentCameraPosition ?? _kGooglePlex,
        markers: _markers,
        onMapCreated: (GoogleMapController controller) {
          _controller.complete(controller);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _goToTheLake,
        label: const Text('To the lake!'),
        icon: const Icon(Icons.directions_boat),
      ),
    );
  }

  Future<void> _goToTheLake() async {
    final GoogleMapController controller = await _controller.future;
    await controller.animateCamera(CameraUpdate.newCameraPosition(_kLake));
  }
}
