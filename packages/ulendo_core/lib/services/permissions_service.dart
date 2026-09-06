import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

/// Enum for ride-sharing specific permissions
enum RideSharingPermission {
  /// Fine location (precise GPS) - required for both drivers and riders
  fineLocation,

  /// Coarse location (approximate) - fallback for location
  coarseLocation,

  /// Background location - required for tracking drivers
  backgroundLocation,

  /// Notifications - for ride updates and alerts
  notifications,

  /// Camera - optional, for driver/rider verification
  camera,
}

/// Extension to map RideSharingPermission to platform Permission
extension _PermissionMapping on RideSharingPermission {
  Permission get platformPermission {
    switch (this) {
      case RideSharingPermission.fineLocation:
        return Permission.location;
      case RideSharingPermission.coarseLocation:
        return Permission.locationWhenInUse;
      case RideSharingPermission.backgroundLocation:
        return Permission.locationAlways;
      case RideSharingPermission.notifications:
        return Permission.notification;
      case RideSharingPermission.camera:
        return Permission.camera;
    }
  }

  String get displayName {
    switch (this) {
      case RideSharingPermission.fineLocation:
        return 'Precise Location';
      case RideSharingPermission.coarseLocation:
        return 'Approximate Location';
      case RideSharingPermission.backgroundLocation:
        return 'Background Location';
      case RideSharingPermission.notifications:
        return 'Notifications';
      case RideSharingPermission.camera:
        return 'Camera';
    }
  }

  String get purpose {
    switch (this) {
      case RideSharingPermission.fineLocation:
        return 'We need precise location to show nearby drivers/riders and calculate routes.';
      case RideSharingPermission.coarseLocation:
        return 'We use approximate location as a fallback.';
      case RideSharingPermission.backgroundLocation:
        return 'Allows us to track your location during an active ride.';
      case RideSharingPermission.notifications:
        return 'Get alerts for ride updates, driver arrival, and messages.';
      case RideSharingPermission.camera:
        return 'Used for driver/rider identity verification and profile photos.';
    }
  }
}

/// PermissionsService handles all permission requests for ride-sharing features
class PermissionsService {
  static final PermissionsService _instance = PermissionsService._internal();

  factory PermissionsService() {
    return _instance;
  }

  PermissionsService._internal();

  /// Get the status of a single permission
  Future<PermissionStatus> getPermissionStatus(
    RideSharingPermission permission,
  ) async {
    return permission.platformPermission.status;
  }

  /// Request a single permission
  /// Returns true if granted, false otherwise
  Future<bool> requestPermission(RideSharingPermission permission) async {
    final status = await permission.platformPermission.request();
    return status.isGranted;
  }

  /// Request multiple permissions at once
  /// Returns a map of permission to its granted status
  Future<Map<RideSharingPermission, bool>> requestPermissions(
    List<RideSharingPermission> permissions,
  ) async {
    final result = <RideSharingPermission, bool>{};

    for (final permission in permissions) {
      final status = await permission.platformPermission.request();
      result[permission] = status.isGranted;
    }

    return result;
  }

  /// Driver-specific permissions (fine location, background location, notifications)
  static const List<RideSharingPermission> driverPermissions = [
    RideSharingPermission.fineLocation,
    RideSharingPermission.backgroundLocation,
    RideSharingPermission.notifications,
  ];

  /// Rider-specific permissions (fine location, notifications)
  static const List<RideSharingPermission> riderPermissions = [
    RideSharingPermission.fineLocation,
    RideSharingPermission.notifications,
  ];

  /// Request driver-specific permissions
  /// Returns true if all were granted
  Future<bool> requestDriverPermissions() async {
    final results = await requestPermissions(driverPermissions);
    return results.values.every((granted) => granted);
  }

  /// Request rider-specific permissions
  /// Returns true if all were granted
  Future<bool> requestRiderPermissions() async {
    final results = await requestPermissions(riderPermissions);
    return results.values.every((granted) => granted);
  }

  /// Check if all driver permissions are granted
  Future<bool> areDriverPermissionsGranted() async {
    final statuses = <bool>[];
    for (final permission in driverPermissions) {
      final status = await getPermissionStatus(permission);
      statuses.add(status.isGranted);
    }
    return statuses.every((granted) => granted);
  }

  /// Check if all rider permissions are granted
  Future<bool> areRiderPermissionsGranted() async {
    final statuses = <bool>[];
    for (final permission in riderPermissions) {
      final status = await getPermissionStatus(permission);
      statuses.add(status.isGranted);
    }
    return statuses.every((granted) => granted);
  }

  /// Open app settings to manually grant denied permissions
  Future<bool> openAppSettings() async {
    return openAppSettings();
  }
}
