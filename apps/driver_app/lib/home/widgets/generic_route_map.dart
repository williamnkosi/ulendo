import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ulendo_models/models/location_data.dart';

/// Generic reusable map widget for route navigation
/// Works for both pickup and destination navigation
class GenericRouteMap extends StatefulWidget {
  final String destinationAddress;
  final double destinationLat;
  final double destinationLng;
  final LocationData currentLocation;
  final Set<Polyline>? polylines;
  final String buttonLabel;
  final VoidCallback onArrived;
  final String mapTitle;
  final double arrivalThresholdKm;

  const GenericRouteMap({
    required this.destinationAddress,
    required this.destinationLat,
    required this.destinationLng,
    required this.currentLocation,
    required this.polylines,
    required this.buttonLabel,
    required this.onArrived,
    required this.mapTitle,
    this.arrivalThresholdKm = 0.1, // 100 meters by default
    super.key,
  });

  @override
  State<GenericRouteMap> createState() => _GenericRouteMapState();
}

class _GenericRouteMapState extends State<GenericRouteMap> {
  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();

  Set<Marker> _markers = {};
  CameraPosition? _currentCameraPosition;

  final Logger _logger = Logger(
    printer: PrefixPrinter(
      PrettyPrinter(methodCount: 0),
      info: '[GenericRouteMap]',
      error: '[GenericRouteMap]',
      warning: '[GenericRouteMap]',
      debug: '[GenericRouteMap]',
    ),
  );

  @override
  void initState() {
    super.initState();
    _logger.i('Initializing GenericRouteMap for: ${widget.mapTitle}');
    _updateMap();
  }

  @override
  void didUpdateWidget(GenericRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentLocation != widget.currentLocation ||
        oldWidget.polylines != widget.polylines) {
      _updateMap();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _currentCameraPosition == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Loading route to ${widget.mapTitle}...'),
                ],
              ),
            )
          : Stack(
              children: [
                GoogleMap(
                  mapType: MapType.normal,
                  initialCameraPosition: _currentCameraPosition!,
                  markers: _markers,
                  polylines: widget.polylines ?? {},
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
    );
  }

  Widget _buildRouteInfoPanel() {
    final distance = _calculateDistance(
      widget.currentLocation.latitude,
      widget.currentLocation.longitude,
      widget.destinationLat,
      widget.destinationLng,
    );

    final isArrived = distance <= widget.arrivalThresholdKm;

    _logger.i(
      'Distance to destination: ${distance.toStringAsFixed(2)} km, '
      'Arrived: $isArrived, Threshold: ${widget.arrivalThresholdKm} km',
    );

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.mapTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: isArrived ? Colors.red : Colors.green,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArrived ? 'Destination' : 'Route To',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        widget.destinationAddress,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Distance: ${distance.toStringAsFixed(2)} km',
                  style: TextStyle(
                    fontSize: 12,
                    color: isArrived ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Routes: ${widget.polylines?.length ?? 0}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isArrived ? widget.onArrived : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isArrived
                      ? Colors.green
                      : Colors.grey.shade300,
                  disabledBackgroundColor: Colors.grey.shade300,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  isArrived
                      ? widget.buttonLabel
                      : '${distance.toStringAsFixed(2)} km away',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isArrived
                        ? Colors.white
                        : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Calculate distance between two points in kilometers using Haversine formula
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const p = 0.017453292519943295; // π/180
    return 12742 *
        asin(
          sqrt(
            sin((lat2 - lat1) * p / 2) * sin((lat2 - lat1) * p / 2) +
                cos(lat1 * p) *
                    cos(lat2 * p) *
                    sin((lon2 - lon1) * p / 2) *
                    sin((lon2 - lon1) * p / 2),
          ),
        );
  }

  void _updateMap() {
    _logger.i(
      'Updating map for ${widget.mapTitle}: '
      'current=(${widget.currentLocation.latitude.toStringAsFixed(4)}, '
      '${widget.currentLocation.longitude.toStringAsFixed(4)})',
    );

    // Create markers
    final newMarkers = <Marker>{
      // Driver marker (blue)
      Marker(
        markerId: const MarkerId('driver'),
        position: LatLng(
          widget.currentLocation.latitude,
          widget.currentLocation.longitude,
        ),
        infoWindow: const InfoWindow(title: 'Your Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
      // Destination marker (red)
      Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(widget.destinationLat, widget.destinationLng),
        infoWindow: const InfoWindow(title: 'Destination'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };

    setState(() {
      _markers = newMarkers;
      _currentCameraPosition = CameraPosition(
        target: LatLng(
          widget.currentLocation.latitude,
          widget.currentLocation.longitude,
        ),
        zoom: 17.0,
      );
      _logger.i(
        'setState: Updated markers (${_markers.length}), '
        'camera at (${widget.currentLocation.latitude}, ${widget.currentLocation.longitude})',
      );
    });
  }
}
