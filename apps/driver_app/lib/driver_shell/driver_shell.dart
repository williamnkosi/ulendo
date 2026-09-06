import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:driver_app/account/account_page.dart';
import 'package:driver_app/earnings/earnings_page.dart';
import 'package:driver_app/home/home_page.dart';
import 'package:driver_app/location/location_tracking_bloc.dart';
import 'package:driver_app/services/location_service.dart';
import 'package:ulendo_core/permissions/permissions_bloc.dart';

/// The root navigation shell that provides bottom tab navigation.
class DriverShell extends StatefulWidget {
  const DriverShell({super.key});

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  int _selectedIndex = 0;

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
          create: (context) =>
              PermissionsBloc()..add(const RequestDriverPermissionsEvent()),
        ),
        BlocProvider<LocationTrackingBloc>(
          create: (context) =>
              LocationTrackingBloc(locationService: LocationService()),
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
