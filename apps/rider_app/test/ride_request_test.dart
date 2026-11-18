import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_places_autocomplete_text_field/google_places_autocomplete_text_field.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rider_app/home/ride_request.dart';
import 'package:rider_app/trip_management_bloc/index.dart';
import 'package:ulendo_models/ulendo_models.dart' as models;

class _MockTripBloc extends MockBloc<TripManagementEvent, TripManagementState>
    implements TripManagementBloc {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const RequestTripEvent(
        pickup: models.Location(lat: 0, lng: 0, address: 'Pickup'),
        dropoff: models.Location(lat: 0, lng: 0, address: 'Dropoff'),
      ),
    );
  });

  for (final fieldIndex in [0, 1]) {
    testWidgets(
      'field $fieldIndex edits require reselection and send only new location',
      (tester) async {
        dotenv.loadFromString(envString: 'GOOGLE_PLACES_API_KEY=test');
        final bloc = _MockTripBloc();
        when(() => bloc.state).thenReturn(const TripInitial());
        addTearDown(bloc.close);
        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<TripManagementBloc>.value(
              value: bloc,
              child: const RideRequestPage(),
            ),
          ),
        );
        final fields = tester
            .widgetList<GooglePlacesAutoCompleteTextFormField>(
              find.byType(GooglePlacesAutoCompleteTextFormField),
            )
            .toList();
        final predictions = [
          Prediction(
            description: 'Pickup',
            placeId: 'pickup',
            lat: '-15',
            lng: '28',
          ),
          Prediction(
            description: 'Dropoff',
            placeId: 'dropoff',
            lat: '-16',
            lng: '29',
          ),
        ];
        for (var index = 0; index < 2; index++) {
          fields[index].onSuggestionClicked!(predictions[index]);
          fields[index].onPredictionWithCoordinatesReceived!(
            predictions[index],
          );
        }
        await tester.pump();
        ElevatedButton button() => tester.widget(find.byType(ElevatedButton));
        final staleButtonCallback = button().onPressed!;

        fields[fieldIndex].textEditingController!.text = 'Edited address';
        // Simulate tapping the still-rendered button before Flutter rebuilds.
        staleButtonCallback();
        verifyNever(() => bloc.add(any()));
        await tester.pump();
        expect(button().onPressed, isNull);

        fields[fieldIndex].textEditingController!.text =
            predictions[fieldIndex].description!;
        fields[fieldIndex].onPredictionWithCoordinatesReceived!(
          predictions[fieldIndex],
        );
        await tester.pump();
        expect(button().onPressed, isNull);
        verifyNever(() => bloc.add(any()));

        final replacement = Prediction(
          description: 'New selected address',
          placeId: 'new',
          lat: '-17',
          lng: '30',
        );
        fields[fieldIndex].onSuggestionClicked!(replacement);
        await tester.pump();
        expect(button().onPressed, isNull);
        fields[fieldIndex].onPredictionWithCoordinatesReceived!(replacement);
        await tester.pump();
        expect(button().onPressed, isNotNull);
        button().onPressed!();
        final event =
            verify(() => bloc.add(captureAny())).captured.single
                as RequestTripEvent;
        final changed = fieldIndex == 0 ? event.pickup : event.dropoff;
        final unchanged = fieldIndex == 0 ? event.dropoff : event.pickup;
        expect(
          changed,
          const models.Location(
            lat: -17,
            lng: 30,
            address: 'New selected address',
          ),
        );
        expect(unchanged.address, predictions[1 - fieldIndex].description);
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      },
    );
  }

  testWidgets(
    'quick submit disabled until coordinates resolve; edits revoke readiness',
    (tester) async {
      dotenv.loadFromString(envString: 'GOOGLE_PLACES_API_KEY=test');
      final bloc = _MockTripBloc();
      when(() => bloc.state).thenReturn(const TripInitial());
      addTearDown(bloc.close);
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<TripManagementBloc>.value(
            value: bloc,
            child: const RideRequestPage(),
          ),
        ),
      );

      ElevatedButton button() => tester.widget(find.byType(ElevatedButton));
      final fields = tester
          .widgetList<GooglePlacesAutoCompleteTextFormField>(
            find.byType(GooglePlacesAutoCompleteTextFormField),
          )
          .toList();
      final pickup = Prediction(description: 'Pickup', placeId: 'pickup');
      final dropoff = Prediction(description: 'Dropoff', placeId: 'dropoff');
      fields[0].onSuggestionClicked!(pickup);
      fields[1].onSuggestionClicked!(dropoff);
      await tester.pump();
      expect(button().onPressed, isNull);
      pickup.lat = '-15';
      pickup.lng = '28';
      fields[0].onPredictionWithCoordinatesReceived!(pickup);
      await tester.pump();
      expect(button().onPressed, isNull);
      dropoff.lat = '-16';
      dropoff.lng = '29';
      fields[1].onPredictionWithCoordinatesReceived!(dropoff);
      await tester.pump();
      expect(button().onPressed, isNotNull);

      fields[0].textEditingController!.text = 'Edited pickup';
      await tester.pump();
      expect(button().onPressed, isNull);
      fields[0].onPredictionWithCoordinatesReceived!(pickup);
      await tester.pump();
      expect(button().onPressed, isNull);

      fields[0].onError?.call(Exception('private service error'));
      await tester.pump();
      expect(
        find.text('Location lookup failed. Please select the location again.'),
        findsOneWidget,
      );

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      fields[0].onPredictionWithCoordinatesReceived!(pickup);
      fields[1].onPredictionWithCoordinatesReceived!(dropoff);
      expect(tester.takeException(), isNull);
    },
  );
}
