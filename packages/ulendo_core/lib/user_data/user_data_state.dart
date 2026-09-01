import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ulendo_models/ulendo_models.dart';

part 'user_data_state.freezed.dart';
part 'user_data_state.g.dart';

enum UserDataStatus { initial, loading, success, failure }

/// State holding the current user profile data.
@freezed
abstract class UserDataState with _$UserDataState {
  const factory UserDataState({
    /// The current status of the user profile lifecycle.
    @Default(UserDataStatus.initial) UserDataStatus status,

    /// The current user profile, if one exists.
    UserModel? userProfile,
  }) = _UserDataState;

  factory UserDataState.fromJson(Map<String, dynamic> json) =>
      _$UserDataStateFromJson(json);
}
