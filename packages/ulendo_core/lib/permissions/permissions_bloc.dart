import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/permissions_service.dart';

part 'permissions_event.dart';
part 'permissions_state.dart';

/// PermissionsBloc handles permission requests and status tracking for ride-sharing
class PermissionsBloc extends Bloc<PermissionsEvent, PermissionsState> {
  final PermissionsService _permissionsService;

  PermissionsBloc({PermissionsService? permissionsService})
    : _permissionsService = permissionsService ?? PermissionsService(),
      super(const PermissionsInitial()) {
    on<RequestDriverPermissionsEvent>(_onRequestDriverPermissions);
    on<RequestRiderPermissionsEvent>(_onRequestRiderPermissions);
    on<CheckPermissionStatusEvent>(_onCheckPermissionStatus);
    on<CheckDriverPermissionsEvent>(_onCheckDriverPermissions);
    on<CheckRiderPermissionsEvent>(_onCheckRiderPermissions);
    on<OpenAppSettingsEvent>(_onOpenAppSettings);
  }

  /// Handle driver permissions request
  Future<void> _onRequestDriverPermissions(
    RequestDriverPermissionsEvent event,
    Emitter<PermissionsState> emit,
  ) async {
    try {
      emit(const PermissionsLoading());

      final results = await _permissionsService.requestPermissions(
        PermissionsService.driverPermissions,
      );

      final granted = results.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();
      final denied = results.entries
          .where((e) => !e.value)
          .map((e) => e.key)
          .toList();

      emit(
        PermissionsSuccess(
          grantedPermissions: granted,
          deniedPermissions: denied,
        ),
      );

      if (denied.isEmpty) {
        emit(const PermissionsDriverGranted());
      }
    } catch (e) {
      emit(PermissionsError(message: 'Failed to request permissions: $e'));
    }
  }

  /// Handle rider permissions request
  Future<void> _onRequestRiderPermissions(
    RequestRiderPermissionsEvent event,
    Emitter<PermissionsState> emit,
  ) async {
    try {
      emit(const PermissionsLoading());

      final results = await _permissionsService.requestPermissions(
        PermissionsService.riderPermissions,
      );

      final granted = results.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();
      final denied = results.entries
          .where((e) => !e.value)
          .map((e) => e.key)
          .toList();

      emit(
        PermissionsSuccess(
          grantedPermissions: granted,
          deniedPermissions: denied,
        ),
      );

      if (denied.isEmpty) {
        emit(const PermissionsRiderGranted());
      }
    } catch (e) {
      emit(PermissionsError(message: 'Failed to request permissions: $e'));
    }
  }

  /// Handle checking single permission status
  Future<void> _onCheckPermissionStatus(
    CheckPermissionStatusEvent event,
    Emitter<PermissionsState> emit,
  ) async {
    try {
      final status = await _permissionsService.getPermissionStatus(
        event.permission,
      );
      emit(PermissionsChecked(permission: event.permission, status: status));
    } catch (e) {
      emit(PermissionsError(message: 'Failed to check permission: $e'));
    }
  }

  /// Handle checking all driver permissions
  Future<void> _onCheckDriverPermissions(
    CheckDriverPermissionsEvent event,
    Emitter<PermissionsState> emit,
  ) async {
    try {
      final granted = await _permissionsService.areDriverPermissionsGranted();

      if (granted) {
        emit(const PermissionsDriverGranted());
      } else {
        emit(
          PermissionsSuccess(
            grantedPermissions: const [],
            deniedPermissions: PermissionsService.driverPermissions,
          ),
        );
      }
    } catch (e) {
      emit(PermissionsError(message: 'Failed to check permissions: $e'));
    }
  }

  /// Handle checking all rider permissions
  Future<void> _onCheckRiderPermissions(
    CheckRiderPermissionsEvent event,
    Emitter<PermissionsState> emit,
  ) async {
    try {
      final granted = await _permissionsService.areRiderPermissionsGranted();

      if (granted) {
        emit(const PermissionsRiderGranted());
      } else {
        emit(
          PermissionsSuccess(
            grantedPermissions: const [],
            deniedPermissions: PermissionsService.riderPermissions,
          ),
        );
      }
    } catch (e) {
      emit(PermissionsError(message: 'Failed to check permissions: $e'));
    }
  }

  /// Handle opening app settings
  Future<void> _onOpenAppSettings(
    OpenAppSettingsEvent event,
    Emitter<PermissionsState> emit,
  ) async {
    try {
      await _permissionsService.openAppSettings();
    } catch (e) {
      emit(PermissionsError(message: 'Failed to open app settings: $e'));
    }
  }
}
