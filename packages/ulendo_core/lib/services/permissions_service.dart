import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

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
  static final Logger _logger = Logger(
    printer: PrefixPrinter(
      PrettyPrinter(methodCount: 0),
      info: '[PermissionsService]',
      error: '[PermissionsService]',
      warning: '[PermissionsService]',
      debug: '[PermissionsService]',
    ),
  );

  factory PermissionsService() {
    return _instance;
  }

  PermissionsService._internal();

  /// Get the status of a single permission
  Future<PermissionStatus> getPermissionStatus(
    RideSharingPermission permission,
  ) async {
    _logger.d('Checking status for permission: ${permission.displayName}');
    final status = await permission.platformPermission.status;
    _logger.d('Permission ${permission.displayName} status: $status');
    return status;
  }

  /// Request a single permission
  /// Returns true if granted, false otherwise
  Future<bool> requestPermission(RideSharingPermission permission) async {
    _logger.i('Requesting permission: ${permission.displayName}');
    final status = await permission.platformPermission.request();
    if (status.isGranted) {
      _logger.i('Permission granted: ${permission.displayName}');
    } else {
      _logger.w(
        'Permission denied: ${permission.displayName} (status: $status)',
      );
    }
    return status.isGranted;
  }

  /// Request multiple permissions at once
  /// Returns a map of permission to its granted status
  Future<Map<RideSharingPermission, bool>> requestPermissions(
    List<RideSharingPermission> permissions,
  ) async {
    _logger.i('Requesting ${permissions.length} permissions');
    final result = <RideSharingPermission, bool>{};

    for (final permission in permissions) {
      _logger.d('====== START PERMISSION REQUEST: ${permission.name} ======');

      // Check status BEFORE request
      final statusBefore = await permission.platformPermission.status;
      _logger.d('Status BEFORE request: $statusBefore for ${permission.name}');

      // Make the request
      _logger.d(
        'Calling platform request for: ${permission.name} (${permission.platformPermission})',
      );
      final status = await permission.platformPermission.request();
      _logger.d('Platform returned status: $status for ${permission.name}');

      // Check status AFTER request
      final statusAfter = await permission.platformPermission.status;
      _logger.d('Status AFTER request: $statusAfter for ${permission.name}');

      result[permission] = status.isGranted;
      _logger.d(
        '${permission.name}: ${status.isGranted ? 'GRANTED' : 'DENIED'}',
      );
      _logger.d('====== END PERMISSION REQUEST: ${permission.name} ======');
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
    _logger.i('Requesting driver-specific permissions');
    final results = await requestPermissions(driverPermissions);
    final allGranted = results.values.every((granted) => granted);
    _logger.i(
      'Driver permissions request completed: ${allGranted ? 'ALL GRANTED' : 'SOME DENIED'}',
    );
    return allGranted;
  }

  /// Request rider-specific permissions
  /// Returns true if all were granted
  Future<bool> requestRiderPermissions() async {
    _logger.i('Requesting rider-specific permissions');
    final results = await requestPermissions(riderPermissions);
    final allGranted = results.values.every((granted) => granted);
    _logger.i(
      'Rider permissions request completed: ${allGranted ? 'ALL GRANTED' : 'SOME DENIED'}',
    );
    return allGranted;
  }

  /// Check if all driver permissions are granted
  Future<bool> areDriverPermissionsGranted() async {
    _logger.d('Checking if all driver permissions are granted');
    final statuses = <bool>[];
    for (final permission in driverPermissions) {
      final status = await getPermissionStatus(permission);
      statuses.add(status.isGranted);
    }
    final allGranted = statuses.every((granted) => granted);
    _logger.d('Driver permissions check result: $allGranted');
    return allGranted;
  }

  /// Check if all rider permissions are granted
  Future<bool> areRiderPermissionsGranted() async {
    _logger.d('Checking if all rider permissions are granted');
    final statuses = <bool>[];
    for (final permission in riderPermissions) {
      final status = await getPermissionStatus(permission);
      statuses.add(status.isGranted);
    }
    final allGranted = statuses.every((granted) => granted);
    _logger.d('Rider permissions check result: $allGranted');
    return allGranted;
  }

  /// Open app settings to manually grant denied permissions
  Future<bool> openAppSettings() async {
    _logger.i('Opening app settings for manual permission management');
    final opened = await openAppSettings();
    _logger.d('App settings opened: $opened');
    return opened;
  }
}
