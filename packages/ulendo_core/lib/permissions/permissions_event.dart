part of 'permissions_bloc.dart';

/// Base class for permission events
abstract class PermissionsEvent extends Equatable {
  const PermissionsEvent();

  @override
  List<Object?> get props => [];
}

/// Event to request driver-specific permissions
class RequestDriverPermissionsEvent extends PermissionsEvent {
  const RequestDriverPermissionsEvent();
}

/// Event to request rider-specific permissions
class RequestRiderPermissionsEvent extends PermissionsEvent {
  const RequestRiderPermissionsEvent();
}

/// Event to check current permission status
class CheckPermissionStatusEvent extends PermissionsEvent {
  final RideSharingPermission permission;

  const CheckPermissionStatusEvent(this.permission);

  @override
  List<Object?> get props => [permission];
}

/// Event to check if all driver permissions are granted
class CheckDriverPermissionsEvent extends PermissionsEvent {
  const CheckDriverPermissionsEvent();
}

/// Event to check if all rider permissions are granted
class CheckRiderPermissionsEvent extends PermissionsEvent {
  const CheckRiderPermissionsEvent();
}

/// Event to open app settings
class OpenAppSettingsEvent extends PermissionsEvent {
  const OpenAppSettingsEvent();
}
