import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'user_data_repository.dart';
import 'user_data_event.dart';
import 'user_data_state.dart';

/// BLoC that manages the current user's profile data.
class UserDataBloc extends Bloc<UserDataEvent, UserDataState> {
  final UserDataRepository _userDataRepository;
  StreamSubscription? _userSubscription;

  /// Creates an instance of [UserDataBloc] with the required [UserDataRepository].
  UserDataBloc({required UserDataRepository userDataRepository})
    : _userDataRepository = userDataRepository,
      super(const UserDataState()) {
    on<UserDataLoaded>(_onUserDataLoaded);
    on<UserDataChanged>(_onUserDataChanged);
    on<UserDataUpdated>(_onUserDataUpdated);
    on<UserDataCleared>(_onUserDataCleared);
  }

  void _onUserDataLoaded(UserDataLoaded event, Emitter<UserDataState> emit) {
    emit(const UserDataState(status: UserDataStatus.loading));
    _userSubscription?.cancel();
    _userSubscription = _userDataRepository
        .watchUser(event.uid)
        .listen(
          (user) => add(UserDataChanged(user)),
          onError: (Object error) => add(UserDataChanged(null)),
        );
  }

  void _onUserDataChanged(UserDataChanged event, Emitter<UserDataState> emit) {
    final user = event.user;
    final hasMissingRequiredFields =
        user == null ||
        user.firstName.trim().isEmpty ||
        user.lastName.trim().isEmpty ||
        user.phoneNumber.trim().isEmpty;

    if (hasMissingRequiredFields) {
      emit(UserDataState(status: UserDataStatus.incomplete, userProfile: user));
      return;
    }

    emit(UserDataState(status: UserDataStatus.success, userProfile: user));
  }

  Future<void> _onUserDataUpdated(
    UserDataUpdated event,
    Emitter<UserDataState> emit,
  ) async {
    emit(
      UserDataState(
        status: UserDataStatus.loading,
        userProfile: state.userProfile,
      ),
    );

    try {
      await _userDataRepository.updateUser(
        uid: event.uid,
        firstName: event.firstName,
        lastName: event.lastName,
        phoneNumber: event.phoneNumber,
        profileImageUrl: event.profileImageUrl,
      );

      // Add a small delay to allow Firestore to fully commit the update
      await Future.delayed(const Duration(milliseconds: 500));

      // Fetch the updated user data to ensure UI is updated immediately
      final updatedUser = await _userDataRepository.getUser(event.uid);

      if (updatedUser != null) {
        emit(
          UserDataState(
            status: UserDataStatus.success,
            userProfile: updatedUser,
          ),
        );
      } else {
        print('Failed to fetch updated user data fadfadsor uid: ${event.uid}');
        // Still emit success since the write succeeded; the real-time listener will update the state
        emit(
          UserDataState(
            status: UserDataStatus.success,
            userProfile: state.userProfile,
          ),
        );
      }
    } catch (e) {
      print('Error updating user data for uid: ${event.uid}, error: $e');
      emit(
        UserDataState(
          status: UserDataStatus.failure,
          userProfile: state.userProfile,
        ),
      );
    }
  }

  void _onUserDataCleared(UserDataCleared event, Emitter<UserDataState> emit) {
    _userSubscription?.cancel();
    _userSubscription = null;
    emit(const UserDataState());
  }

  @override
  Future<void> close() {
    _userSubscription?.cancel();
    return super.close();
  }
}
