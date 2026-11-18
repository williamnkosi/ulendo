import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:google_places_autocomplete_text_field/google_places_autocomplete_text_field.dart'
    show Prediction;
import 'package:ulendo_models/ulendo_models.dart';

import 'ride_location_repository.dart';

part 'ride_locations_cubit.freezed.dart';

enum RideLocationField { pickup, dropoff }

@freezed
sealed class RideLocationsState with _$RideLocationsState {
  const factory RideLocationsState.initial() = RideLocationsInitial;
  const factory RideLocationsState.pending() = RideLocationsPending;
  const factory RideLocationsState.ready({
    required Location pickup,
    required Location dropoff,
  }) = RideLocationsReady;
  const factory RideLocationsState.failure(String message) =
      RideLocationsFailure;
}

class RideLocationsCubit extends Cubit<RideLocationsState> {
  RideLocationsCubit({required this.repository})
    : super(const RideLocationsState.initial());

  final RideLocationRepository repository;
  final _selections = <RideLocationField, Prediction>{};
  final _texts = <RideLocationField, String>{};
  final _locations = <RideLocationField, Location>{};

  void textChanged(RideLocationField field, String text) {
    if (isClosed) return;
    _texts[field] = text;
    if (_selections[field]?.description != text) {
      _selections.remove(field);
      _locations.remove(field);
      emit(const RideLocationsState.pending());
    }
  }

  void selected(RideLocationField field, Prediction prediction) {
    if (isClosed) return;
    _selections[field] = prediction;
    _texts[field] = prediction.description ?? '';
    _locations.remove(field);
    emit(const RideLocationsState.pending());
  }

  void resolved(RideLocationField field, Prediction prediction) {
    if (isClosed ||
        !identical(_selections[field], prediction) ||
        _texts[field] != prediction.description) {
      return;
    }
    try {
      _locations[field] = repository.resolve(prediction);
      final pickup = _locations[RideLocationField.pickup];
      final dropoff = _locations[RideLocationField.dropoff];
      if (pickup != null && dropoff != null) {
        emit(RideLocationsState.ready(pickup: pickup, dropoff: dropoff));
      } else {
        emit(const RideLocationsState.pending());
      }
    } catch (_) {
      _locations.remove(field);
      emit(
        const RideLocationsState.failure(
          'Could not resolve this location. Please select it again.',
        ),
      );
    }
  }

  void lookupFailed(RideLocationField field) {
    if (isClosed) return;
    // The SDK error callback carries no lookup identity. Clear this field
    // conservatively, requiring a fresh selection before submission.
    _selections.remove(field);
    _locations.remove(field);
    emit(
      const RideLocationsState.failure(
        'Location lookup failed. Please select the location again.',
      ),
    );
  }
}
