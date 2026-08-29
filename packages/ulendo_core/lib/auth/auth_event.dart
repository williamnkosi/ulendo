import 'package:firebase_auth/firebase_auth.dart';

/// Base class for all authentication events.
sealed class AuthEvent {
  const AuthEvent();
}

/// Event dispatched when the application starts, to initiate authentication checks.
class AuthStarted extends AuthEvent {
  const AuthStarted();
}

/// Event dispatched when the user's authentication state changes.
class AuthUserChanged extends AuthEvent {
  /// The current Firebase user, or null if unauthenticated.
  final User? user;

  const AuthUserChanged(this.user);
}

/// Event dispatched when a user requests signing in.
class SignInRequested extends AuthEvent {
  final String email;
  final String password;

  const SignInRequested({
    required this.email,
    required this.password,
  });
}

/// Event dispatched when a user requests signing up.
class SignUpRequested extends AuthEvent {
  final String email;
  final String password;

  const SignUpRequested({
    required this.email,
    required this.password,
  });
}

/// Event dispatched when a user requests signing out.
class SignOutRequested extends AuthEvent {
  const SignOutRequested();
}
