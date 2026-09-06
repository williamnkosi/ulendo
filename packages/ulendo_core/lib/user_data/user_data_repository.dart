import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ulendo_models/ulendo_models.dart';

/// Repository that handles all user profile data operations against Firestore.
class UserDataRepository {
  final FirebaseFirestore _firestore;

  /// The top-level Firestore collection that stores user profiles.
  static const String _usersCollection = 'users';

  /// Creates a new instance of [UserDataRepository].
  ///
  /// If no [FirebaseFirestore] is provided, [FirebaseFirestore.instance] is used.
  UserDataRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Returns a reference to the user document for the given [uid].
  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _firestore.collection(_usersCollection).doc(uid);

  /// Fetches the [UserModel] for the given [uid] once.
  ///
  /// Returns null if no document exists for that uid.
  Future<UserModel?> getUser(String uid) async {
    final snapshot = await _userDoc(uid).get();
    if (!snapshot.exists || snapshot.data() == null) return null;
    return UserModel.fromJson(snapshot.data()!);
  }

  /// Returns a stream of [UserModel] changes for the given [uid].
  ///
  /// Emits null when the document does not exist.
  Stream<UserModel?> watchUser(String uid) {
    return _userDoc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return UserModel.fromJson(snapshot.data()!);
    });
  }

  /// Updates only the provided non-null fields on the user's document.
  Future<void> updateUser({
    required String uid,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? profileImageUrl,
  }) async {
    final updates = <String, dynamic>{
      'firstName': ?firstName,
      'lastName': ?lastName,
      'phoneNumber': ?phoneNumber,
      'profileImageUrl': ?profileImageUrl,
    };

    await _userDoc(uid).update(updates);
  }
}
