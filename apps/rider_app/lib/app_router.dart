import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'login_page.dart';
import 'navigation/rider_shell.dart';

class RiderAppRouter {
  RiderAppRouter() {
    _refreshListenable = _StreamRefreshListenable(
      FirebaseAuth.instance.authStateChanges(),
    );
  }

  late final _StreamRefreshListenable _refreshListenable;

  late final GoRouter router = GoRouter(
    initialLocation: '/home',
    refreshListenable: _refreshListenable,
    redirect: (_, state) {
      final isSignedIn = FirebaseAuth.instance.currentUser != null;
      final isOnSignIn = state.matchedLocation == '/sign-in';

      if (!isSignedIn && !isOnSignIn) {
        return '/sign-in';
      }

      if (isSignedIn && isOnSignIn) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/sign-in', builder: (_, __) => const RiderLoginPage()),
      GoRoute(path: '/home', builder: (_, __) => const RiderShell()),
    ],
  );

  void dispose() {
    _refreshListenable.dispose();
  }
}

class _StreamRefreshListenable extends ChangeNotifier {
  _StreamRefreshListenable(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
