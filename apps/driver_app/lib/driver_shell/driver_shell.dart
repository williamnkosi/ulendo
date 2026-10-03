import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:driver_app/account/account_page.dart';
import 'package:driver_app/earnings/earnings_page.dart';
import 'package:driver_app/home/home_page.dart';
import 'package:driver_app/notifications/bloc/notification_hub_bloc.dart';
import 'package:driver_app/rides/bloc/ride_management_bloc.dart';
import 'package:driver_app/services/location_service.dart';
import 'package:ulendo_core/permissions/permissions_bloc.dart';
import 'package:ulendo_core/messaging/fcm_service.dart';

final _logger = Logger(
  printer: PrefixPrinter(
    PrettyPrinter(methodCount: 0),
    info: '[DriverShell]',
    debug: '[DriverShell]',
    warning: '[DriverShell]',
    error: '[DriverShell]',
  ),
);

/// The root navigation shell that provides bottom tab navigation.
class DriverShell extends StatefulWidget {
  const DriverShell({super.key});

  @override
  State<DriverShell> createState() {
    _logger.d('DriverShell.createState() called');
    return _DriverShellState();
  }
}

class _DriverShellState extends State<DriverShell> {
  int _selectedIndex = 0;
  late NotificationHubBloc _notificationHubBloc;

  @override
  void initState() {
    super.initState();
    _logger.d('_DriverShellState.initState() called');
    // Create the bloc ONCE in initState, not in build()
    final userId = FirebaseAuth.instance.currentUser?.uid;
    _logger.d('Creating NotificationHubBloc with userId: $userId');
    _notificationHubBloc = NotificationHubBloc(fcmService: FCMService());
    _logger.d('Adding InitializeNotificationHubEvent');
    _notificationHubBloc.add(
      InitializeNotificationHubEvent(driverId: userId ?? ''),
    );
  }

  @override
  void dispose() {
    _logger.d('Disposing NotificationHubBloc');
    _notificationHubBloc.close();
    super.dispose();
  }

  Widget _generatePage() {
    switch (_selectedIndex) {
      case 0:
        return const DriverHomePage();
      case 1:
        return const DriverEarningsPage();
      case 2:
        return const DriverAccountPage();
    }
    return const DriverHomePage();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<PermissionsBloc>(
          create: (context) {
            _logger.d('Creating PermissionsBloc');
            return PermissionsBloc()
              ..add(const RequestDriverPermissionsEvent());
          },
        ),
        BlocProvider<NotificationHubBloc>.value(value: _notificationHubBloc),
        BlocProvider<RideManagementBloc>(
          create: (context) {
            _logger.d('Creating RideManagementBloc');
            return RideManagementBloc(
              locationService: LocationService(),
              notificationHubBloc: _notificationHubBloc,
            );
          },
        ),
      ],
      child: Scaffold(
        body: _generatePage(),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (value) => setState(() => _selectedIndex = value),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(
              icon: Icon(Icons.attach_money),
              label: 'Earnings',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_circle),
              label: 'Account',
            ),
          ],
        ),
      ),
    );
  }
}
