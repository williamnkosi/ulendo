import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:logger/logger.dart';
import 'package:ulendo_core/messaging/fcm_service.dart';

part 'notification_hub_event.dart';
part 'notification_hub_state.dart';

/// Central notification hub for managing Firebase Cloud Messaging
/// Handles FCM initialization, token management, and message handler registration
class NotificationHubBloc
    extends Bloc<NotificationHubEvent, NotificationHubState> {
  final FCMService _fcmService;
  final Logger _logger = Logger(
    printer: PrefixPrinter(
      PrettyPrinter(methodCount: 0),
      info: '[NotificationHubBloc]',
      error: '[NotificationHubBloc]',
      warning: '[NotificationHubBloc]',
      debug: '[NotificationHubBloc]',
    ),
  );

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
      _logger.i('Starting FCM initialization for driver: ${event.driverId}');
      emit(const FCMInitializing());

      // Initialize FCM service with driver ID
      _logger.d('Calling FCMService.initialize()');
      await _fcmService.initialize(event.driverId);
      _logger.d('FCMService.initialize() completed');

      // Get current FCM token
      _logger.d('Getting FCM token');
      final token = await _fcmService.getToken();
      _logger.d('FCM token obtained: ${token?.substring(0, 20)}...');

      // Setup foreground message handler (app is open)
      // Synchronous to ensure subscription is set up immediately
      _logger.d('Setting up foreground message handler');
      _fcmService.setupForegroundMessageHandler((message) {
        _logger.i('Foreground notification dispatched to bloc');
        add(NotificationReceivedEvent(message: message));
      });
      _logger.d('Foreground message handler setup completed');

      // Setup message opened handler (user taps notification)
      // Synchronous to ensure subscription is set up immediately
      _logger.d('Setting up message opened handler');
      _fcmService.setupMessageOpenedHandler((message) {
        _logger.i('Message opened notification dispatched to bloc');
        add(NotificationReceivedEvent(message: message));
      });
      _logger.d('Message opened handler setup completed');

      _logger.i('FCM initialization completed successfully');
      emit(FCMReady(fcmToken: token));
    } catch (e) {
      _logger.e('FCM initialization failed', error: e);
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
      _logger.i(
        'Processing notification: ${event.message.notification?.title}',
      );
      // Emit the notification received state so other BLoCs can react
      emit(NotificationReceivedState(message: event.message));
    } catch (e) {
      _logger.e('Error processing notification', error: e);
      emit(FCMError('Error processing notification: ${e.toString()}'));
    }
  }

  /// Handle disconnection and cleanup
  Future<void> _onDisconnect(
    DisconnectNotificationHubEvent event,
    Emitter<NotificationHubState> emit,
  ) async {
    try {
      _logger.d('Disconnecting notification hub');
      await _fcmService.deleteFCMToken();
      _logger.i('Notification hub disconnected successfully');
      emit(const FCMInitial());
    } catch (e) {
      _logger.e('Failed to disconnect notification hub', error: e);
      emit(FCMError('Failed to disconnect: ${e.toString()}'));
    }
  }

  @override
  Future<void> close() async {
    return super.close();
  }
}
