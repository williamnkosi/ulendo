import 'package:ulendo_models/ulendo_models.dart';

/// Base class for all user data states.
sealed class UserDataState {
  const UserDataState();
}

/// The initial state before any user data has been requested.
class UserDataInitial extends UserDataState {
  const UserDataInitial();
}

/// The state indicating that user data is currently being loaded.
class UserDataLoading extends UserDataState {
  const UserDataLoading();
}

/// The state indicating user data was loaded successfully.
class UserDataSuccess extends UserDataState {
  /// The loaded user profile.
  final UserModel user;

  const UserDataSuccess(this.user);
}

/// The state indicating no profile document exists for this user.
class UserDataEmpty extends UserDataState {
  const UserDataEmpty();
}

/// The state indicating a user data operation has failed.
class UserDataFailure extends UserDataState {
  /// The error message explaining the failure.
  final String errorMessage;

  const UserDataFailure(this.errorMessage);
}
