import 'package:firebase_database/firebase_database.dart';

import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';

/// FCM Service to handle Firebase Cloud Messaging operations
/// Manages FCM token registration, notification handling, and token storage
class FCMService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  late String _driverId;
  late DatabaseReference _driverRef;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;

  /// Initialize FCM Service with driver ID
  Future<void> initialize(String driverId) async {
    _driverId = driverId;
    _driverRef = _database.ref('drivers/$_driverId');

    try {
      // Request notification permissions (iOS)
      if (Platform.isIOS) {
        await _firebaseMessaging.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );
      }

      // Get and store FCM token
      await _storeFCMToken();

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _updateFCMToken(newToken);
      });

      print('FCMService initialized for driver: $_driverId');
    } catch (e) {
      print('FCMService initialization error: $e');
      rethrow;
    }
  }

  /// Get the current FCM token
  Future<String?> getToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      print('FCM Token: $token');
      return token;
    } catch (e) {
      print('Error getting FCM token: $e');
      return null;
    }
  }

  /// Store FCM token in Firebase database
  Future<void> _storeFCMToken() async {
    try {
      final token = await getToken();
      if (token != null) {
        await _driverRef.update({
          'fcmToken': token,
          'fcmTokenUpdatedAt': DateTime.now().toIso8601String(),
        });
        print('FCM token stored successfully');
      }
    } catch (e) {
      print('Error storing FCM token: $e');
    }
  }

  /// Update FCM token when it refreshes
  Future<void> _updateFCMToken(String newToken) async {
    try {
      await _driverRef.update({
        'fcmToken': newToken,
        'fcmTokenUpdatedAt': DateTime.now().toIso8601String(),
      });
      print('FCM token updated: $newToken');
    } catch (e) {
      print('Error updating FCM token: $e');
    }
  }

  /// Setup foreground message handler
  /// Called when notification is received while app is open
  Future<void> setupForegroundMessageHandler(
    void Function(RemoteMessage) handler,
  ) async {
    _foregroundSubscription = FirebaseMessaging.onMessage.listen(handler);
  }

  /// Setup background message handler
  /// Called when notification is received while app is in background
  static void setupBackgroundMessageHandler(
    Future<void> Function(RemoteMessage) handler,
  ) {
    FirebaseMessaging.onBackgroundMessage(handler);
  }

  /// Setup message opened handler
  /// Called when user taps on notification (app closed or background)
  Future<void> setupMessageOpenedHandler(
    void Function(RemoteMessage) handler,
  ) async {
    _messageOpenedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      handler,
    );
  }

  /// Delete FCM token (cleanup when driver logs out)
  Future<void> deleteFCMToken() async {
    try {
      await _foregroundSubscription?.cancel();
      await _messageOpenedSubscription?.cancel();
      await _driverRef.update({'fcmToken': null});
      await _firebaseMessaging.deleteToken();
      print('FCM token deleted');
    } catch (e) {
      print('Error deleting FCM token: $e');
    }
  }
}
