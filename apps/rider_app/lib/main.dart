import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ulendo_core/ulendo_core.dart';
import 'package:ulendo_ui/ulendo_ui.dart';

import 'app_router.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _validateCachedAuthSession();

  runApp(const MyApp());
}

Future<void> _validateCachedAuthSession() async {
  final auth = FirebaseAuth.instance;
  final user = auth.currentUser;

  if (user == null) {
    return;
  }

  try {
    await user.reload();
  } on FirebaseAuthException catch (e) {
    if (e.code == 'user-not-found' ||
        e.code == 'user-token-expired' ||
        e.code == 'invalid-user-token') {
      await auth.signOut();
    }
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final RiderAppRouter _appRouter;

  @override
  void initState() {
    super.initState();
    _appRouter = RiderAppRouter();
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
