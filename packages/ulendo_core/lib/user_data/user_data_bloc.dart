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
        super(const UserDataInitial()) {
    on<UserDataLoaded>(_onUserDataLoaded);
    on<UserDataChanged>(_onUserDataChanged);
    on<UserDataUpdated>(_onUserDataUpdated);
    on<UserDataCleared>(_onUserDataCleared);
  }

  void _onUserDataLoaded(
    UserDataLoaded event,
    Emitter<UserDataState> emit,
  ) {
    emit(const UserDataLoading());
    _userSubscription?.cancel();
    _userSubscription = _userDataRepository.watchUser(event.uid).listen(
      (user) => add(UserDataChanged(user)),
      onError: (Object error) =>
          add(UserDataChanged(null)),
    );
  }

  void _onUserDataChanged(
    UserDataChanged event,
    Emitter<UserDataState> emit,
  ) {
    final user = event.user;
    if (user != null) {
      emit(UserDataSuccess(user));
    } else {
      emit(const UserDataEmpty());
    }
  }

  Future<void> _onUserDataUpdated(
    UserDataUpdated event,
    Emitter<UserDataState> emit,
  ) async {
    try {
      await _userDataRepository.updateUser(
        uid: event.uid,
        firstName: event.firstName,
        lastName: event.lastName,
        phoneNumber: event.phoneNumber,
        profileImageUrl: event.profileImageUrl,
      );
      // The real-time listener from watchUser will emit the new state automatically.
    } catch (e) {
      emit(UserDataFailure(e.toString()));
    }
  }

  void _onUserDataCleared(
    UserDataCleared event,
    Emitter<UserDataState> emit,
  ) {
    _userSubscription?.cancel();
    _userSubscription = null;
    emit(const UserDataInitial());
  }

  @override
  Future<void> close() {
    _userSubscription?.cancel();
    return super.close();
  }
}
