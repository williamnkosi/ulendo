# Ulendo Architecture

Ulendo uses Flutter and Dart for the Rider and Driver mobile apps. A Melos
workspace contains both apps and their shared Dart packages. Firebase provides
authentication, live ride state, push notifications, and backend functions.

## Flutter application layers

The apps use a layered BLoC architecture with a separation similar to MVC.
Widgets act as the view. BLoCs handle events and emit state. Repositories and
services provide access to data, device capabilities, and external APIs.

```text
User interaction → Widget → BLoC event → Repository or service → External system
UI update        ← Widget ← BLoC state ← Result or stream     ← External system
```

| Layer | Responsibility |
| --- | --- |
| Presentation | Screens and widgets render state and dispatch events. `BlocBuilder` rebuilds UI and `BlocListener` handles UI reactions such as navigation or feedback. |
| Business logic | BLoCs manage feature workflows and state transitions, including authentication, permissions, ride requests, and driver ride progress. |
| Repositories and services | Repositories expose data operations to BLoCs. Services interact with platform plugins, Firebase, or HTTP APIs. |
| Models | Dart types carry data across layers, including locations, ride requests, and notification payloads. |

Each app initializes Firebase and provides its authentication BLoC in
`lib/main.dart`. Each `lib/app_router.dart` defines navigation with GoRouter.
The rider and driver shells construct feature BLoCs and pass in their
dependencies through constructors.

## Flutter state management boundaries

For new or changed workflows, follow
`UI → BLoC/Cubit → Repository → DataSource/service`. Services are the existing
platform/API adapters; do not add pass-through classes solely to satisfy the
layer names. Inject dependencies through constructors. BLoCs/Cubits must not
depend on Flutter UI types, `BuildContext`, or other BLoCs/Cubits. Coordinate
features through shared repository streams or presentation-layer listeners.

Use Freezed unions with sealed roots for all new or changed BLoC/Cubit states
and BLoC events. Use immutable data, Freezed-generated value equality, and
exhaustive state rendering; do not add Equatable or handwritten equality/props.
Add the required Freezed/build_runner dependencies to the owning module when
needed and regenerate code following its generated-file conventions.
Represent mutually exclusive workflow phases as distinct
states, rather than competing loading/error/success flags. States describe
status and data, never navigation or snackbar commands.

Widgets render state and forward input. Keep business validation, coordinate
conversion, request readiness, and asynchronous workflows in the business/data
layers. Local controllers, focus, animations, and pure display formatting remain
presentation concerns. Existing Places/Maps SDK widgets may render and forward
callbacks; this integration does not authorize business logic or repository/API
calls in widgets.

Use `BlocBuilder` for rendering, `BlocListener` for one-time UI reactions, and
`BlocConsumer` when both are needed for the same transition. Prefer `BlocSelector`
for a widget depending on a single field of a complex state. Scope providers to
the nearest feature subtree and dispose owned instances and subscriptions.

Prefer Cubit for simple mutations and Bloc for event traceability or event
transformations; preserve existing feature conventions within unrelated changes.
Choose debounce and concurrency behavior deliberately, prevent duplicate requests
and stale results, handle async/stream failures with user-safe failure states,
and guard emissions after cancellation or closure. Every new BLoC/Cubit needs
`bloc_test` tests with mocked repositories for initial, success, and failure
behavior; changed workflows need relevant regression and concurrency coverage.

## Rider app

The pickup and drop-off form in `apps/rider_app/lib/home/` uses a Google Places
autocomplete widget. When the rider submits the form, `RideBloc` calls
`RideRepository` in `apps/rider_app/lib/ride/`. The repository invokes the
Firebase callable `requestRideFunction`, and the BLoC emits state that the
form uses to show the result. The repository exposes cancellation and ride
lookup methods that remain unimplemented.

## Driver app

`RideManagementBloc` in `apps/driver_app/lib/rides/bloc/` coordinates driver
availability and ride transitions. Its dependencies in
`apps/driver_app/lib/services/` include:

- `LocationService` reads device location through Geolocator and publishes
  driver presence and location to Firebase Realtime Database.
- `RideManagementService` reads and updates live ride and driver records in
  Realtime Database.
- `PolylineService` fetches route geometry from Google Directions.

`NotificationHubBloc` handles ride notification events. Driver screens display
location and route data with Google Maps widgets.

## Shared packages

- `ulendo_core` provides shared authentication, profile, permissions, and messaging code.
- `ulendo_models` provides shared Dart data models.
- `ulendo_ui` provides themes and design tokens.

## Firebase ride flow

The ride request callable writes a pending record to Realtime Database under
`active_rides/{riderUid}`. The record also carries a separately generated ride
ID. A database trigger searches for an available driver and sends a Firebase
Cloud Messaging offer. The driver app updates live ride state. When the ride
reaches `completed`, a backend trigger archives it in Firestore and removes
the live record. Firestore also stores user profiles.

## Where to put new code

Keep rendering, navigation reactions, and form interaction in widgets. Put
feature decisions and state transitions in the owning BLoC. Put API calls,
database access, and device interactions in repositories or services, then pass
those dependencies into the BLoC. Existing Google Places and Google Maps
widgets integrate directly with their SDKs at the presentation layer.

When planning or reviewing a change, check for similar code in both the Rider
and Driver apps. If both apps use the same behavior or data contract, suggest
moving the common code to the appropriate package under `packages/`. Use
`ulendo_core` for shared services and business logic, `ulendo_models` for data
types, and `ulendo_ui` for reusable widgets and styling. Keep each app's
feature-specific behavior in that app.
