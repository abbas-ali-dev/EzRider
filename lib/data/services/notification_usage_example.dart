// Example usage of the notification system for rider app

import 'package:ovorideuser/data/services/firebase_messaging_service.dart';
import 'package:ovorideuser/data/services/notification_handler_service.dart';

class NotificationUsageExample {
  // Initialize the notification system in your main.dart or app initialization
  static Future<void> initializeNotifications() async {
    // Initialize Firebase messaging
    await FirebaseMessagingService().initialize();

    // Get FCM token and send to your backend
    String? token = await FirebaseMessagingService().getToken();
    if (token != null) {
      // Send token to your backend to associate with user
      await _sendTokenToBackend(token);
    }

    // Subscribe to rider-specific topics
    await FirebaseMessagingService().subscribeToTopic('riders');
    await FirebaseMessagingService().subscribeToTopic('scheduled_rides');
  }

  // Example of handling a notification payload
  static void handleNotificationExample() {
    // Example notification payload from your backend
    Map<String, dynamic> notificationPayload = {
      "type": "passenger_approved",
      "title": "Ride Request Approved",
      "body": "Your request to join the ride has been approved",
      "recipient_id": "rider_123",
      "data": {"ride_id": "ride_456", "screen": "ride_details"}
    };

    // Handle the notification
    NotificationHandlerService()
        .handleScheduledRideNotification(notificationPayload);
  }

  // Send FCM token to your backend
  static Future<void> _sendTokenToBackend(String token) async {
    // Make API call to your backend to store the FCM token
    // This allows your backend to send notifications to this device
    print('Sending FCM token to backend: $token');

    // Example API call:
    // await apiService.updateFCMToken(token);
  }

  // Example of different notification types
  static void notificationExamples() {
    // Ride approved notification
    Map<String, dynamic> rideApproved = {
      "type": "passenger_approved",
      "title": "Ride Request Approved",
      "body": "Your request to join the ride has been approved",
      "recipient_id": "rider_123",
      "data": {"ride_id": "ride_789", "screen": "ride_details"}
    };

    // Ride started notification
    Map<String, dynamic> rideStarted = {
      "type": "ride_started",
      "title": "Ride Started",
      "body": "Your scheduled ride has started",
      "recipient_ids": ["rider_123", "rider_456"],
      "data": {"ride_id": "ride_789", "screen": "live_tracking"}
    };

    // Ride cancelled notification
    Map<String, dynamic> rideCancelled = {
      "type": "ride_cancelled",
      "title": "Ride Cancelled",
      "body": "Your scheduled ride has been cancelled",
      "recipient_ids": ["rider_123", "rider_456"],
      "data": {"ride_id": "ride_789", "screen": "available_rides"}
    };

    // Driver reached notification
    Map<String, dynamic> driverReached = {
      "type": "driver_reached",
      "title": "Driver Has Arrived",
      "body": "Driver has reached your pickup location",
      "recipient_id": "rider_123",
      "data": {"ride_id": "ride_789", "screen": "ride_details"}
    };

    // Handle each notification
    NotificationHandlerService().handleScheduledRideNotification(rideApproved);
    NotificationHandlerService().handleScheduledRideNotification(rideStarted);
    NotificationHandlerService().handleScheduledRideNotification(rideCancelled);
    NotificationHandlerService().handleScheduledRideNotification(driverReached);
  }
}
