import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_places_autocomplete_text_field/google_places_autocomplete_text_field.dart'
    as google_places;
import 'package:logging/logging.dart';
import 'package:ulendo_models/ulendo_models.dart';

import '../ride/ride_bloc.dart';
import '../ride/ride_event.dart';
import '../ride/ride_state.dart';

class RideRequestPage extends StatefulWidget {
  const RideRequestPage({super.key});

  @override
  State<RideRequestPage> createState() => _RideRequestPageState();
}

class _RideRequestPageState extends State<RideRequestPage> {
  final logger = Logger('RiderHomeRequestForm');

  final _config = google_places.GoogleApiConfig(
    apiKey: dotenv.env['GOOGLE_PLACES_API_KEY'] ?? '',
    fetchPlaceDetailsWithCoordinates: true,
  );

  final _pickupController = TextEditingController();
  final _dropoffController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  google_places.Prediction? _pickUpPrediction;
  google_places.Prediction? _dropOffPrediction;

  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void dispose() {
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
        key: _formKey,
        autovalidateMode: _autovalidateMode,
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
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Please enter a pickup location';
                  }
                  return null;
                },
                maxLines: 1,
                overlayContainerBuilder: (child) => Material(
                  elevation: 1.0,
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  child: child,
                ),
                onPredictionWithCoordinatesReceived: (prediction) {
                  _pickUpPrediction = prediction;
                  logger.info(
                    'Pickup place selected: ${prediction.description}, '
                    'Lat: ${prediction.lat}, Lng: ${prediction.lng}',
                  );
                },
                onSuggestionClicked: (google_places.Prediction prediction) {
                  _pickupController.text = prediction.description ?? '';
                  _pickUpPrediction = prediction;
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
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Please enter a drop-off location';
                  }
                  return null;
                },
                maxLines: 1,
                overlayContainerBuilder: (child) => Material(
                  elevation: 1.0,
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  child: child,
                ),
                onPredictionWithCoordinatesReceived: (prediction) {
                  _dropOffPrediction = prediction;
                  logger.info(
                    'Dropoff place selected: ${prediction.description}, '
                    'Lat: ${prediction.lat}, Lng: ${prediction.lng}',
                  );
                },
                onSuggestionClicked: (google_places.Prediction prediction) {
                  _dropoffController.text = prediction.description ?? '';
                  _dropOffPrediction = prediction;
                },
                minInputLength: 3,
              ),
              const SizedBox(height: 24),

              // Search/Start Button
              BlocListener<RideBloc, RideState>(
                listener: (context, state) {
                  if (state is RideError) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: ${state.message}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  } else if (state is RideRequested) {
                    logger.info('Ride requested successfully');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ride request submitted!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                child: BlocBuilder<RideBloc, RideState>(
                  builder: (context, state) {
                    final isLoading = state is RideLoading;

                    return ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () {
                              logger.info('Search Rides button pressed');

                              // Check if predictions are set
                              if (_pickUpPrediction == null ||
                                  _dropOffPrediction == null) {
                                logger.warning(
                                  'Please select both pickup and drop-off locations',
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please select both pickup and drop-off locations',
                                    ),
                                  ),
                                );
                                return;
                              }

                              if (_formKey.currentState!.validate()) {
                                logger.info(
                                  'Form is valid, dispatching RequestRideEvent',
                                );

                                final pickupLocation = Location(
                                  lat: double.parse(_pickUpPrediction!.lat!),
                                  lng: double.parse(_pickUpPrediction!.lng!),
                                  address: _pickUpPrediction!.description!,
                                );

                                final dropoffLocation = Location(
                                  lat: double.parse(_dropOffPrediction!.lat!),
                                  lng: double.parse(_dropOffPrediction!.lng!),
                                  address: _dropOffPrediction!.description!,
                                );

                                context.read<RideBloc>().add(
                                  RequestRideEvent(
                                    pickup: pickupLocation,
                                    dropoff: dropoffLocation,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
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
