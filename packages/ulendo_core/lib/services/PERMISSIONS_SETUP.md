# Permissions Setup for Ride-Sharing

This guide explains how to configure and use the `PermissionsService` for ride-sharing apps (driver and rider).

## Core Permissions

All ride-sharing apps need these core permissions:

- **Fine Location** (`ACCESS_FINE_LOCATION`) - Precise GPS for map and routing
- **Notifications** (`POST_NOTIFICATIONS`) - Ride updates and alerts

## Role-Specific Permissions

### Driver App

Drivers need core permissions PLUS:

- **Background Location** (`ACCESS_BACKGROUND_LOCATION`) - Track driver location during active rides

### Rider App

Riders need only:

- Core permissions (location + notifications)

---

## Platform Setup

### Android

**File:** `apps/driver_app/android/app/src/main/AndroidManifest.xml`

Already configured with:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

**Runtime Permissions:**

- Android 6.0+ (API 23+) requires runtime permission requests
- Use `PermissionsService` to request permissions at app startup or when needed

### iOS

**File:** `apps/driver_app/ios/Runner/Info.plist`

Add these keys:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to show nearby drivers and calculate routes.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>We need access to your location to track your ride in real-time.</string>

<key>NSLocalNetworkUsageDescription</key>
<string>We use local network to optimize connectivity during rides.</string>
```

**Runtime Permissions:**

- iOS 13+ requires explicit permission requests
- Call `PermissionsService` to trigger system permission dialogs

---

## Usage

### In Your App

#### Request Core Permissions (at startup)

```dart
import 'package:ulendo_core/ulendo_core.dart';

final permissionsService = PermissionsService();

// Request permissions
final granted = await permissionsService.requestCorePermissions();
if (granted) {
  print('All core permissions granted!');
} else {
  print('Some permissions were denied.');
}
```

#### Request Driver-Specific Permissions

```dart
final driverPermissionsGranted =
  await permissionsService.requestDriverPermissions();
```

#### Check Current Status

```dart
final hasLocationAccess =
  await permissionsService.getPermissionStatus(
    RideSharingPermission.fineLocation
  );

if (hasLocationAccess.isGranted) {
  print('Location access granted');
} else if (hasLocationAccess.isDenied) {
  print('Location access denied');
} else if (hasLocationAccess.isPermanentlyDenied) {
  print('Location access permanently denied - open settings');
}
```

#### Open App Settings

If user denies permissions permanently, guide them to settings:

```dart
await PermissionsService().openAppSettings();
```

---

## Permission Request Strategy

### Driver App Flow

1. **App Startup** → Request core permissions
2. **First Ride** → Request background location (if not already granted)
3. **Before Going Online** → Verify all driver permissions are active

### Rider App Flow

1. **App Startup** → Request core permissions
2. **Before Booking** → Verify core permissions are active

---

## Important Notes

⚠️ **Manifest vs Runtime:**

- Declaring permissions in `AndroidManifest.xml` or `Info.plist` is **not enough**
- You must call `PermissionsService` to request permissions at **runtime**
- Without runtime requests, the app won't have permission to access sensitive features

⚠️ **Background Location (Drivers Only):**

- Android: Must request `ACCESS_BACKGROUND_LOCATION` separately after `ACCESS_FINE_LOCATION`
- iOS: Requires "Always" location access (most restrictive)
- Users are more likely to deny this - explain why it's needed

⚠️ **Testing:**

- Emulators/Simulators may not fully simulate permission dialogs
- Always test on real devices when possible
- Use `PermissionsService` to verify permissions are actually granted

---

## Troubleshooting

### Map Tiles Not Showing?

- Verify `INTERNET` permission is granted (though it doesn't require runtime request)
- Check API key is correctly configured
- Ensure `PermissionsService.requestCorePermissions()` was called

### Location Not Updating?

- Verify fine location permission is granted
- For drivers: verify background location permission is also granted
- Check if location services are enabled in device settings

### Notifications Not Working?

- Verify notifications permission is granted
- On Android 12+, this requires runtime request
- Check notification channel is configured correctly

---

## Files Reference

- **Service:** `packages/ulendo_core/lib/services/permissions_service.dart`
- **Config:** `pubspec.yaml` (includes `permission_handler: ^11.4.0`)
- **Android Manifest:** `apps/driver_app/android/app/src/main/AndroidManifest.xml`
- **iOS Info.plist:** `apps/driver_app/ios/Runner/Info.plist`
