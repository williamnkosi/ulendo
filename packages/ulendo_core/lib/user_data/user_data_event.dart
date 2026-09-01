import 'package:ulendo_models/ulendo_models.dart';

/// Base class for all user data events.
sealed class UserDataEvent {
  const UserDataEvent();
}

/// Event dispatched to load the user's profile from the data source.
class UserDataLoaded extends UserDataEvent {
  /// The UID of the user whose data should be loaded.
  final String uid;

  const UserDataLoaded(this.uid);
}

/// Event dispatched when the user's profile data changes (e.g. real-time update).
class UserDataChanged extends UserDataEvent {
  /// The updated [UserModel], or null if no data exists.
  final UserModel? user;

  const UserDataChanged(this.user);
}

/// Event dispatched to update specific fields on the user's profile.
class UserDataUpdated extends UserDataEvent {
  final String uid;
  final String? firstName;
  final String? lastName;
  final String? phoneNumber;
  final String? profileImageUrl;

  const UserDataUpdated({
    required this.uid,
    this.firstName,
    this.lastName,
    this.phoneNumber,
    this.profileImageUrl,
  });
}

/// Event dispatched to clear user data, typically on sign-out.
class UserDataCleared extends UserDataEvent {
  const UserDataCleared();
}
