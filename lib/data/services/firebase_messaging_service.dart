import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:ovorideuser/data/services/notification_handler_service.dart';

class FirebaseMessagingService {
  static final FirebaseMessagingService _instance =
      FirebaseMessagingService._internal();
  factory FirebaseMessagingService() => _instance;
  FirebaseMessagingService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final NotificationHandlerService _notificationHandler =
      NotificationHandlerService();

  // Initialize Firebase messaging
  Future<void> initialize() async {
    // Request permission for notifications
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    } else {}

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Handle notification tap when app is terminated
    _handleInitialMessage();
  }

  // Handle background messages
  static Future<void> _firebaseMessagingBackgroundHandler(
      RemoteMessage message) async {
    debugPrint('===== BACKGROUND NOTIFICATION RECEIVED =====');
    debugPrint('Message ID: ${message.messageId}');
    debugPrint('Title: ${message.notification?.title}');
    debugPrint('Body: ${message.notification?.body}');
    debugPrint('Data: ${message.data}');

    // Handle the notification data
    if (message.data.containsKey('type')) {
      debugPrint('Notification Type: ${message.data['type']}');
      // You might want to store this for when the app is opened
      // or handle it differently for background messages
    }
    debugPrint(' ===== END BACKGROUND NOTIFICATION =====');
  }

  // Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('===== FOREGROUND NOTIFICATION RECEIVED =====');
    debugPrint('Message ID: ${message.messageId}');
    debugPrint('Title: ${message.notification?.title}');
    debugPrint('Body: ${message.notification?.body}');
    debugPrint('Data: ${message.data}');

    // Show in-app notification or handle directly
    if (message.data.containsKey('type')) {
      debugPrint('Handling notification type: ${message.data['type']}');
      _notificationHandler.handleScheduledRideNotification(message.data);
    } else {
      debugPrint(' No type found in notification data');
    }
    debugPrint('===== END FOREGROUND NOTIFICATION =====');
  }

  // Handle notification tap when app is in background
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('===== NOTIFICATION TAPPED (Background) =====');
    debugPrint('Message ID: ${message.messageId}');
    debugPrint('Title: ${message.notification?.title}');
    debugPrint('Data: ${message.data}');

    // Handle navigation based on notification data
    if (message.data.containsKey('type')) {
      debugPrint('Navigating to: ${message.data['type']}');
      _notificationHandler.handleScheduledRideNotification(message.data);
    } else {
      debugPrint('No type found in notification data');
    }
  }

  // Handle notification tap when app is terminated
  Future<void> _handleInitialMessage() async {
    RemoteMessage? initialMessage =
        await _firebaseMessaging.getInitialMessage();

    if (initialMessage != null) {
      debugPrint('===== NOTIFICATION TAPPED (App Terminated) =====');
      debugPrint('Message ID: ${initialMessage.messageId}');
      debugPrint('Title: ${initialMessage.notification?.title}');
      debugPrint('Data: ${initialMessage.data}');

      // Handle navigation based on notification data
      if (initialMessage.data.containsKey('type')) {
        debugPrint('Navigating to: ${initialMessage.data['type']}');
        _notificationHandler
            .handleScheduledRideNotification(initialMessage.data);
      } else {
        debugPrint('No type found in notification data');
      }
      debugPrint('===== END INITIAL MESSAGE =====');
    } else {
      debugPrint('No initial message found (app not opened from notification)');
    }
  }

  // Get FCM token
  Future<String?> getToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      debugPrint('🔑 FCM Token retrieved: ${token?.substring(0, 20)}...');
      return token;
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
      return null;
    }
  }

  // Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  // Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
    } catch (e) {
      debugPrint(e.toString());
    }
  }
}
