import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_places_autocomplete_text_field/google_places_autocomplete_text_field.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rider_app/home/ride_request.dart';
import 'package:rider_app/trip_management_bloc/index.dart';

class _MockTripBloc extends MockBloc<TripManagementEvent, TripManagementState>
    implements TripManagementBloc {}

void main() {
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
