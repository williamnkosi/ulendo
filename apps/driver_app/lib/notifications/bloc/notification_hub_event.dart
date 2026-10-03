part of 'notification_hub_bloc.dart';

abstract class NotificationHubEvent extends Equatable {
  const NotificationHubEvent();

  @override
  List<Object?> get props => [];
}

class InitializeNotificationHubEvent extends NotificationHubEvent {
  final String driverId;

  const InitializeNotificationHubEvent({required this.driverId});

  @override
  List<Object?> get props => [driverId];
}

class NotificationReceivedEvent extends NotificationHubEvent {
  final RemoteMessage message;

  const NotificationReceivedEvent({required this.message});

  @override
  List<Object?> get props => [message];
}

class DisconnectNotificationHubEvent extends NotificationHubEvent {
  const DisconnectNotificationHubEvent();
}
