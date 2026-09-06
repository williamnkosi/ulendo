part of 'permissions_bloc.dart';

/// Base class for permission states
abstract class PermissionsState extends Equatable {
  const PermissionsState();

  @override
  List<Object?> get props => [];
}

/// Initial state - permissions not yet requested
class PermissionsInitial extends PermissionsState {
  const PermissionsInitial();
}

/// Loading state - permissions are being requested
class PermissionsLoading extends PermissionsState {
  const PermissionsLoading();
}

/// Success state - permissions were requested
class PermissionsSuccess extends PermissionsState {
  final List<RideSharingPermission> grantedPermissions;
  final List<RideSharingPermission> deniedPermissions;

  const PermissionsSuccess({
    required this.grantedPermissions,
    required this.deniedPermissions,
  });

  @override
  List<Object?> get props => [grantedPermissions, deniedPermissions];
}

/// State when checking permission status
class PermissionsChecked extends PermissionsState {
  final RideSharingPermission permission;
  final PermissionStatus status;

  const PermissionsChecked({required this.permission, required this.status});

  @override
  List<Object?> get props => [permission, status];
}

/// State indicating all driver permissions are granted
class PermissionsDriverGranted extends PermissionsState {
  const PermissionsDriverGranted();
}

/// State indicating all rider permissions are granted
class PermissionsRiderGranted extends PermissionsState {
  const PermissionsRiderGranted();
}

/// Error state
class PermissionsError extends PermissionsState {
  final String message;

  const PermissionsError({required this.message});

  @override
  List<Object?> get props => [message];
}
