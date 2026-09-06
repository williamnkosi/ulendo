import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ulendo_core/permissions/permissions_bloc.dart';

/// A placeholder screen for the Home feature/tab.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: BlocListener<PermissionsBloc, PermissionsState>(
        listener: (context, state) {
          if (state is PermissionsError) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(state.message)));
          }
          if (state is PermissionsSuccess &&
              state.deniedPermissions.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Some permissions were denied: ${state.deniedPermissions.map((p) => p.name).join(", ")}',
                ),
                action: SnackBarAction(
                  label: 'Settings',
                  onPressed: () {
                    // TODO: Open app settings
                  },
                ),
              ),
            );
          }
        },
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Home Screen',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    BlocBuilder<PermissionsBloc, PermissionsState>(
                      builder: (context, state) {
                        if (state is PermissionsLoading) {
                          return const CircularProgressIndicator();
                        }
                        if (state is PermissionsRiderGranted) {
                          return const Text('Permissions Granted ✓');
                        }
                        return const Text('Checking permissions...');
                      },
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    // TODO: Handle request a ride
                  },
                  child: const Text('Request a Ride'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
