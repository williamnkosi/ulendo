import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:ulendo_core/messaging/fcm_service.dart';

part 'notification_hub_event.dart';
part 'notification_hub_state.dart';

/// Central notification hub for managing Firebase Cloud Messaging
/// Handles FCM initialization, token management, and message handler registration
class NotificationHubBloc
    extends Bloc<NotificationHubEvent, NotificationHubState> {
  final FCMService _fcmService;

  NotificationHubBloc({required FCMService fcmService})
    : _fcmService = fcmService,
      super(const FCMInitial()) {
    on<InitializeNotificationHubEvent>(_onInitialize);
    on<NotificationReceivedEvent>(_onNotificationReceived);
    on<DisconnectNotificationHubEvent>(_onDisconnect);
  }

  /// Initialize FCM and set up message handlers
  Future<void> _onInitialize(
    InitializeNotificationHubEvent event,
    Emitter<NotificationHubState> emit,
  ) async {
    try {
      emit(const FCMInitializing());

      // Initialize FCM service with driver ID
      await _fcmService.initialize(event.driverId);

      // Get current FCM token
      final token = await _fcmService.getToken();

      // Setup foreground message handler
      await _fcmService.setupForegroundMessageHandler((message) {
        add(NotificationReceivedEvent(message: message));
      });

      emit(FCMReady(fcmToken: token));
    } catch (e) {
      emit(FCMError('Failed to initialize notifications: ${e.toString()}'));
    }

    return;
  }

  /// Handle incoming notification
  Future<void> _onNotificationReceived(
    NotificationReceivedEvent event,
    Emitter<NotificationHubState> emit,
  ) async {
    try {
      print('Notification received: ${event.message.notification?.title}');
      // Notification is processed by listeners in other BLoCs
      // This event ensures we can track notifications if needed
    } catch (e) {
      emit(FCMError('Error processing notification: ${e.toString()}'));
    }
  }

  /// Handle disconnection and cleanup
  Future<void> _onDisconnect(
    DisconnectNotificationHubEvent event,
    Emitter<NotificationHubState> emit,
  ) async {
    try {
      await _fcmService.deleteFCMToken();
      emit(const FCMInitial());
    } catch (e) {
      emit(FCMError('Failed to disconnect: ${e.toString()}'));
    }
  }

  @override
  Future<void> close() async {
    return super.close();
  }
}
