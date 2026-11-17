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

## Rider app

The rider presentation layer collects pickup and drop-off locations and
displays trip progress and feedback. Business logic owns the rider workflow,
including requesting a ride and reacting to live trip updates. Repositories
provide access to backend operations and trip data streams.

Trip lifecycle changes should preserve the active trip's identity and keep
displayed progress consistent with backend state. The developer agent chooses
the BLoC names, events, states, and internal structure needed for the feature.
Feature specifications define required behavior and acceptance criteria;
unfinished implementation work belongs in feature handoffs and issue tracking.

## Driver app

Driver business logic coordinates availability, ride offers, and trip
transitions. Repositories and services provide:

- Device location and publication of driver presence and location.
- Access to live ride and driver records.
- Route geometry for map presentation.

Notification handling delivers ride offers and updates to the relevant
workflow. Driver screens display location and route data. The developer agent
chooses component names and internal structure within these layer boundaries.

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
