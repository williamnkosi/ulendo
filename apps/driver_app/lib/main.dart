import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ulendo_core/ulendo_core.dart';
import 'package:ulendo_ui/ulendo_ui.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) =>
              AuthBloc(authRepository: AuthRepository())
                ..add(const AuthStarted()),
        ),
      ],
      child: MaterialApp(
        title: 'Ulendo Driver',
        theme: buildAppTheme(),
        home: const _PlaceholderScreen(appName: 'Driver App'),
      ),
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.appName});

  final String appName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(appName)),
      body: Center(
        child: Text(
          '$appName placeholder',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}
