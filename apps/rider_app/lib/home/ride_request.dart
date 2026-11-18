import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_places_autocomplete_text_field/google_places_autocomplete_text_field.dart'
    as google_places;
import 'package:logging/logging.dart';

import '../trip_management_bloc/index.dart';
import 'ride_location_repository.dart';
import 'ride_locations_cubit.dart';

class RideRequestPage extends StatelessWidget {
  const RideRequestPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => RideLocationsCubit(repository: RideLocationRepository()),
    child: const _RideRequestForm(),
  );
}

class _RideRequestForm extends StatefulWidget {
  const _RideRequestForm();

  @override
  State<_RideRequestForm> createState() => _RideRequestPageState();
}

class _RideRequestPageState extends State<_RideRequestForm> {
  final logger = Logger('RiderHomeRequestForm');

  final _config = google_places.GoogleApiConfig(
    apiKey: dotenv.env['GOOGLE_PLACES_API_KEY'] ?? '',
    fetchPlaceDetailsWithCoordinates: true,
  );

  final _pickupController = TextEditingController();
  final _dropoffController = TextEditingController();

  late final RideLocationsCubit _locations;

  @override
  void initState() {
    super.initState();
    _locations = context.read<RideLocationsCubit>();
    _pickupController.addListener(_pickupEdited);
    _dropoffController.addListener(_dropoffEdited);
  }

  void _pickupEdited() =>
      _locations.textChanged(RideLocationField.pickup, _pickupController.text);
  void _dropoffEdited() => _locations.textChanged(
    RideLocationField.dropoff,
    _dropoffController.text,
  );

  @override
  void dispose() {
    _pickupController.removeListener(_pickupEdited);
    _dropoffController.removeListener(_dropoffEdited);
    _pickupController.dispose();
    _dropoffController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request a Ride'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Form(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Pickup Location Field
              google_places.GooglePlacesAutoCompleteTextFormField(
                config: _config,
                textEditingController: _pickupController,
                decoration: const InputDecoration(
                  hintText: 'Enter your pickup location',
                  labelText: 'Pickup Location',
                  prefixIcon: Icon(Icons.location_on),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                ),
                maxLines: 1,
                overlayContainerBuilder: (child) => Material(
                  elevation: 1.0,
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  child: child,
                ),
                onPredictionWithCoordinatesReceived: (prediction) {
                  if (!mounted) return;
                  _locations.resolved(RideLocationField.pickup, prediction);
                },
                onSuggestionClicked: (prediction) {
                  if (!mounted) return;
                  _pickupController.text = prediction.description ?? '';
                  _locations.selected(RideLocationField.pickup, prediction);
                },
                onError: (_) {
                  if (!mounted) return;
                  _locations.lookupFailed(RideLocationField.pickup);
                },
                minInputLength: 3,
              ),
              const SizedBox(height: 24),

              // Drop-off Location Field
              google_places.GooglePlacesAutoCompleteTextFormField(
                config: _config,
                textEditingController: _dropoffController,
                decoration: const InputDecoration(
                  hintText: 'Enter your drop-off location',
                  labelText: 'Drop-off Location',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                ),
                maxLines: 1,
                overlayContainerBuilder: (child) => Material(
                  elevation: 1.0,
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  child: child,
                ),
                onPredictionWithCoordinatesReceived: (prediction) {
                  if (!mounted) return;
                  _locations.resolved(RideLocationField.dropoff, prediction);
                },
                onSuggestionClicked: (prediction) {
                  if (!mounted) return;
                  _dropoffController.text = prediction.description ?? '';
                  _locations.selected(RideLocationField.dropoff, prediction);
                },
                onError: (_) {
                  if (!mounted) return;
                  _locations.lookupFailed(RideLocationField.dropoff);
                },
                minInputLength: 3,
              ),
              const SizedBox(height: 24),

              // Search/Start Button
              BlocListener<TripManagementBloc, TripManagementState>(
                listener: (context, state) {
                  if (state is TripError) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: ${state.message}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  } else if (state is TripSearching) {
                    logger.info('Trip request submitted');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Searching for drivers...'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                child: BlocBuilder<TripManagementBloc, TripManagementState>(
                  builder: (context, state) {
                    final isLoading = state is TripSearching;

                    return BlocBuilder<RideLocationsCubit, RideLocationsState>(
                      builder: (context, locations) {
                        final (request, error) = switch (locations) {
                          RideLocationsInitial() => (null, null),
                          RideLocationsPending() => (null, null),
                          RideLocationsReady() => (locations, null),
                          RideLocationsFailure(:final message) => (
                            null,
                            message,
                          ),
                        };
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (error != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  error,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                            ElevatedButton(
                              onPressed: isLoading || request == null
                                  ? null
                                  : () {
                                      logger.info(
                                        'Search Rides button pressed',
                                      );

                                      context.read<TripManagementBloc>().add(
                                        RequestTripEvent(
                                          pickup: request.pickup,
                                          dropoff: request.dropoff,
                                        ),
                                      );
                                    },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16.0,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                              ),
                              child: Text(
                                isLoading ? 'Requesting...' : 'Search Rides',
                                style: const TextStyle(
                                  fontSize: 16.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
