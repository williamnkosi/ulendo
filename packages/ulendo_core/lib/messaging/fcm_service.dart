import 'package:firebase_database/firebase_database.dart';
import 'package:logger/logger.dart';

import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';

/// FCM Service to handle Firebase Cloud Messaging operations
/// Manages FCM token registration, notification handling, and token storage
class FCMService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final Logger _logger = Logger(
    printer: PrefixPrinter(
      PrettyPrinter(methodCount: 0),
      info: '[FCMService]',
      error: '[FCMService]',
      warning: '[FCMService]',
      debug: '[FCMService]',
    ),
  );

  late String _driverId;
  late DatabaseReference _driverRef;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;

  /// Initialize FCM Service with driver ID
  Future<void> initialize(String driverId) async {
    _driverId = driverId;
    _driverRef = _database.ref('drivers/$_driverId');

    try {
      _logger.i('Initializing FCMService for driver: $_driverId');

      // Request notification permissions (iOS)
      if (Platform.isIOS) {
        _logger.d('Requesting iOS notification permissions');
        await _firebaseMessaging.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );
        _logger.d('iOS notification permissions requested');
      }

      // Get and store FCM token
      await _storeFCMToken();

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _logger.d('FCM token refresh detected');
        _updateFCMToken(newToken);
      });

      _logger.i('FCMService successfully initialized for driver: $_driverId');
    } catch (e) {
      _logger.e('FCMService initialization error', error: e);
      rethrow;
    }
  }

  /// Get the current FCM token
  Future<String?> getToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      _logger.d('FCM Token retrieved: ${token?.substring(0, 20)}...');
      return token;
    } catch (e) {
      _logger.e('Error getting FCM token', error: e);
      return null;
    }
  }

  /// Store FCM token in Firebase database
  Future<void> _storeFCMToken() async {
    try {
      _logger.d('Storing FCM token for driver: $_driverId');
      final token = await getToken();
      if (token != null) {
        await _driverRef.update({
          'fcmToken': token,
          'fcmTokenUpdatedAt': DateTime.now().toIso8601String(),
        });
        _logger.i('FCM token stored successfully for driver: $_driverId');
      } else {
        _logger.w('FCM token is null, cannot store');
      }
    } catch (e) {
      _logger.e('Error storing FCM token', error: e);
    }
  }

  /// Update FCM token when it refreshes
  Future<void> _updateFCMToken(String newToken) async {
    try {
      _logger.d('Updating FCM token for driver: $_driverId');
      await _driverRef.update({
        'fcmToken': newToken,
        'fcmTokenUpdatedAt': DateTime.now().toIso8601String(),
      });
      _logger.i('FCM token updated successfully for driver: $_driverId');
    } catch (e) {
      _logger.e('Error updating FCM token', error: e);
    }
  }

  /// Setup foreground message handler
  /// Called when notification is received while app is open
  void setupForegroundMessageHandler(void Function(RemoteMessage) handler) {
    _logger.d('Setting up foreground message handler');
    _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
      _logger.i('Foreground message received: ${message.notification?.title}');
      handler(message);
    });
    _logger.d('Foreground message handler setup complete');
  }

  /// Setup background message handler
  /// Called when notification is received while app is in background
  static void setupBackgroundMessageHandler(
    Future<void> Function(RemoteMessage) handler,
  ) {
    final logger = Logger(
      printer: PrefixPrinter(
        PrettyPrinter(methodCount: 0),
        info: '[FCMService]',
        error: '[FCMService]',
        warning: '[FCMService]',
        debug: '[FCMService]',
      ),
    );
    logger.d('Setting up background message handler');
    FirebaseMessaging.onBackgroundMessage((message) async {
      logger.i('Background message received: ${message.notification?.title}');
      await handler(message);
    });
  }

  /// Setup message opened handler
  /// Called when user taps on notification (app closed or background)
  void setupMessageOpenedHandler(void Function(RemoteMessage) handler) {
    _logger.d('Setting up message opened handler');
    _messageOpenedSubscription = FirebaseMessaging.onMessageOpenedApp.listen((
      message,
    ) {
      _logger.i(
        'Message opened from notification: ${message.notification?.title}',
      );
      handler(message);
    });
    _logger.d('Message opened handler setup complete');
  }

  /// Delete FCM token (cleanup when driver logs out)
  Future<void> deleteFCMToken() async {
    try {
      _logger.d('Deleting FCM token for driver: $_driverId');
      await _foregroundSubscription?.cancel();
      await _messageOpenedSubscription?.cancel();
      await _driverRef.update({'fcmToken': null});
      await _firebaseMessaging.deleteToken();
      _logger.i('FCM token deleted successfully for driver: $_driverId');
    } catch (e) {
      _logger.e('Error deleting FCM token', error: e);
    }
  }
}
