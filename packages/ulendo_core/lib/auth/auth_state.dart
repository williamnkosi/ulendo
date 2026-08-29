import 'package:firebase_auth/firebase_auth.dart';

/// Base class for all authentication states.
sealed class AuthState {
  const AuthState();
}

/// The initial state when the authentication status is yet to be determined.
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// The state indicating an authentication process is currently in progress.
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// The state indicating the user has been successfully authenticated.
class Authenticated extends AuthState {
  /// The currently authenticated user.
  final User user;

  const Authenticated(this.user);
}

/// The state indicating the user is not authenticated.
class Unauthenticated extends AuthState {
  const Unauthenticated();
}

/// The state indicating that an authentication operation has failed.
class AuthFailure extends AuthState {
  /// The error message explaining why the authentication failed.
  final String errorMessage;

  const AuthFailure(this.errorMessage);
}
