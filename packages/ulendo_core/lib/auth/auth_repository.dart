import 'package:firebase_auth/firebase_auth.dart';

/// Repository that handles all authentication-related requests.
class AuthRepository {
  final FirebaseAuth _firebaseAuth;

  /// Creates a new instance of [AuthRepository].
  ///
  /// If no [FirebaseAuth] is provided, the default instance [FirebaseAuth.instance] is used.
  AuthRepository({FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  /// Exposes a stream of [User] changes.
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// Returns the current [User] if authenticated, otherwise null.
  User? get currentUser => _firebaseAuth.currentUser;

  /// Signs in a user with the provided [email] and [password].
  ///
  /// Throws a [FirebaseAuthException] if sign in fails.
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Registers a user with the provided [email] and [password].
  ///
  /// Throws a [FirebaseAuthException] if sign up fails.
  Future<UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Signs out the currently authenticated user.
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      rethrow;
    }
  }
}
