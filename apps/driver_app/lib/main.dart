import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logging/logging.dart';
import 'dart:async';
import 'package:ulendo_core/ulendo_core.dart';
import 'package:ulendo_ui/ulendo_ui.dart';

import 'app_router.dart';
import 'firebase_options.dart';

/// Handle notifications when app is in background or terminated
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('Handling a background message: ${message.messageId}');
  // Background notification handling logic here
}

/// Setup logging to print to console with full stack traces
void _setupLogging() {
  // Enable hierarchical logging
  hierarchicalLoggingEnabled = true;
  
  // Set root logger level
  Logger.root.level = Level.ALL;
  
  // Configure console output with full details
  Logger.root.onRecord.listen((record) {
    final timestamp = record.time;
    final level = record.level.name;
    final loggerName = record.loggerName;
    final message = record.message;
    
    // Print main log message
    print('[$timestamp] [$level] [$loggerName] $message');
    
    // Print error and stack trace if present
    if (record.error != null) {
      print('ERROR: ${record.error}');
    }
    if (record.stackTrace != null) {
      print('STACK TRACE:\n${record.stackTrace}');
    }
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Setup logging BEFORE anything else
  _setupLogging();
  
  // Capture Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    print('=== FLUTTER ERROR ===');
    print('${details.exception}');
    print('STACK TRACE:\n${details.stack}');
  };

  // Capture async errors and uncaught exceptions
  runZonedGuarded(
    () async {
      // Load environment variables from .env file
      await dotenv.load();

      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

      // Setup background message handler before running the app
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      runApp(const MyApp());
    },
    (error, stackTrace) {
      print('=== UNCAUGHT EXCEPTION ===');
      print('$error');
      print('STACK TRACE:\n$stackTrace');
    },
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final DriverAppRouter _appRouter;

  @override
  void initState() {
    super.initState();
    _appRouter = DriverAppRouter();
  }

  @override
  void dispose() {
    _appRouter.dispose();
    super.dispose();
  }

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
      child: MaterialApp.router(
        theme: buildAppTheme(),
        routerConfig: _appRouter.router,
      ),
    );
  }
}
