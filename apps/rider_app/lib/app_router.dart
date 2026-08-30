import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'login_page.dart';

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
      GoRoute(
        path: '/sign-in',
        builder: (_, __) => const RiderLoginPage(),
      ),
      GoRoute(
        path: '/home',
        builder: (_, __) => const _PlaceholderPage(title: 'Rider Home'),
      ),
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

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          '$title placeholder',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}
