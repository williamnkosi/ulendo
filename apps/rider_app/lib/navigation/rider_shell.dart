import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rider_app/account/account_page.dart';
import 'package:rider_app/activity/activity_page.dart';
import 'package:rider_app/home/home_page.dart';
import 'package:ulendo_core/user_data/user_data_bloc.dart';
import 'package:ulendo_core/user_data/user_data_repository.dart';
import 'package:ulendo_core/user_data/user_data_state.dart';

/// The root navigation shell that provides bottom tab navigation.
class RiderShell extends StatefulWidget {
  const RiderShell({super.key});

  @override
  State<RiderShell> createState() => _RiderShellState();
}

class _RiderShellState extends State<RiderShell> {
  int _selectedIndex = 0;

  Widget _generatePage() {
    switch (_selectedIndex) {
      case 0:
        return const HomePage();
      case 1:
        return const ActivityPage();
      case 2:
        return const AccountPage();
    }
    return const HomePage();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          UserDataBloc(userDataRepository: UserDataRepository()),
      child: Scaffold(
        body: BlocBuilder<UserDataBloc, UserDataState>(
          builder: (context, state) {
            if (state.status == UserDataStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            return _generatePage();
          },
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (value) => setState(() => _selectedIndex = value),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(
              icon: Icon(Icons.local_activity_rounded),
              label: 'Activity',
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
