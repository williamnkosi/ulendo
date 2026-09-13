import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rider_app/account/account_page.dart';
import 'package:rider_app/activity/activity_page.dart';
import 'package:rider_app/home/home_page.dart';
import 'package:rider_app/user_data_form/user_data_form.dart';
import 'package:rider_app/ride/ride_bloc.dart';
import 'package:rider_app/ride/ride_repository.dart';
import 'package:ulendo_core/user_data/user_data_bloc.dart';
import 'package:ulendo_core/user_data/user_data_event.dart';
import 'package:ulendo_core/user_data/user_data_repository.dart';
import 'package:ulendo_core/user_data/user_data_state.dart';
import 'package:ulendo_core/permissions/permissions_bloc.dart';
import 'package:ulendo_core/ulendo_core.dart';

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
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return MultiBlocProvider(
      providers: [
        BlocProvider<UserDataBloc>(
          create: (context) {
            final bloc = UserDataBloc(userDataRepository: UserDataRepository());
            if (uid != null) {
              bloc.add(UserDataLoaded(uid));
            }
            return bloc;
          },
        ),
        BlocProvider<PermissionsBloc>(
          create: (context) =>
              PermissionsBloc()..add(const RequestRiderPermissionsEvent()),
        ),
        BlocProvider<RideBloc>(
          create: (context) => RideBloc(rideRepository: RideRepositoryImpl()),
        ),
      ],
      child: BlocBuilder<UserDataBloc, UserDataState>(
        builder: (context, state) {
          if (state.status == UserDataStatus.loading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (state.status == UserDataStatus.incomplete) {
            return UserDataForm(userProfile: state.userProfile);
          }

          return Scaffold(
            body: _generatePage(),
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
          );
        },
      ),
    );
  }
}
