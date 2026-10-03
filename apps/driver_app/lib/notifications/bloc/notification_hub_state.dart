part of 'notification_hub_bloc.dart';

abstract class NotificationHubState extends Equatable {
  const NotificationHubState();

  @override
  List<Object?> get props => [];
}

class FCMInitial extends NotificationHubState {
  const FCMInitial();
}

class FCMInitializing extends NotificationHubState {
  const FCMInitializing();
}

class FCMReady extends NotificationHubState {
  final String? fcmToken;

  const FCMReady({this.fcmToken});

  @override
  List<Object?> get props => [fcmToken];
}

class FCMError extends NotificationHubState {
  final String message;

  const FCMError(this.message);

  @override
  List<Object?> get props => [message];
}

class NotificationReceivedState extends NotificationHubState {
  final RemoteMessage message;

  const NotificationReceivedState({required this.message});

  @override
  List<Object?> get props => [message];
}
