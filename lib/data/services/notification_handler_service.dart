// ignore_for_file: avoid_print

import 'package:get/get.dart';
import 'package:ovorideuser/data/controller/scheduled_ride/scheduled_ride_controller.dart';
import 'package:ovorideuser/presentation/screens/scheduled_rides/scheduled_rides_screen.dart';

class NotificationHandlerService {
  static final NotificationHandlerService _instance =
      NotificationHandlerService._internal();
  factory NotificationHandlerService() => _instance;
  NotificationHandlerService._internal();

  // Handle scheduled ride notifications for rider
  void handleScheduledRideNotification(Map<String, dynamic> payload) {
    try {
      String type = payload['type'] ?? '';
      String rideId = payload['data']?['ride_id'] ?? '';
      String screen = payload['data']?['screen'] ?? '';

      // Get current route
      String currentRoute = Get.currentRoute;

      switch (type) {
        case 'passenger_approved':
          _handlePassengerApproved(rideId, screen, currentRoute);
          break;
        case 'passenger_rejected':
          _handlePassengerRejected(rideId, screen, currentRoute);
          break;
        case 'ride_started':
          _handleRideStarted(rideId, screen, currentRoute);
          break;
        case 'ride_cancelled':
          _handleRideCancelled(rideId, screen, currentRoute);
          break;
        case 'ride_completed':
          _handleRideCompleted(rideId, screen, currentRoute);
          break;
        case 'pickup_started':
          _handlePickupStarted(rideId, screen, currentRoute);
          break;
        case 'driver_reached':
          _handleDriverReached(rideId, screen, currentRoute);
          break;
        case 'pickup_cancelled':
          _handlePickupCancelled(rideId, screen, currentRoute);
          break;
        case 'new_ride_available':
          _handleNewRideAvailable(rideId, screen, currentRoute);
          break;
        case 'ride_updated':
          _handleRideUpdated(rideId, screen, currentRoute);
          break;
        case 'ride_deleted':
          _handleRideDeleted(rideId, screen, currentRoute);
          break;
        default:
          print('Unknown notification type: $type');
      }
    } catch (e) {
      print('Error handling notification: $e');
    }
  }

  void _handlePassengerApproved(
      String rideId, String screen, String currentRoute) {
    if (rideId.isEmpty) return;

    // Check if user is on ride details screen for this ride
    if (currentRoute == '/scheduled_ride_detail' && _isCurrentRide(rideId)) {
      // Refresh ride details data
      _refreshRideDetails(rideId);
    } else if (currentRoute == '/scheduled_rides') {
      // Refresh scheduled rides list
      _refreshScheduledRidesList();
    } else {
      // Navigate to ride details screen
      // Note: You'll need to get the ride object from the controller
      // For now, we'll refresh the data instead of navigating
      _refreshScheduledRidesList();
    }
  }

  void _handlePassengerRejected(
      String rideId, String screen, String currentRoute) {
    if (rideId.isEmpty) return;

    // Check if user is on available rides screen
    if (currentRoute == '/scheduled_rides' ||
        currentRoute == '/available_rides') {
      // Refresh available rides list
      _refreshAvailableRidesList();
    } else {
      // Navigate to available rides screen
      Get.to(() => ScheduledRidesScreen());
    }
  }

  void _handleRideStarted(String rideId, String screen, String currentRoute) {
    if (rideId.isEmpty) return;

    // Check if user is on ride details screen for this ride
    if (currentRoute == '/scheduled_ride_detail' && _isCurrentRide(rideId)) {
      // Refresh ride details data
      _refreshRideDetails(rideId);
    } else if (currentRoute == '/scheduled_rides') {
      // Refresh scheduled rides list
      _refreshScheduledRidesList();
    } else {
      // Navigate to ride details screen
      // Note: You'll need to get the ride object from the controller
      // For now, we'll refresh the data instead of navigating
      _refreshScheduledRidesList();
    }
  }

  void _handleRideCancelled(String rideId, String screen, String currentRoute) {
    if (rideId.isEmpty) return;

    // Check if user is on available rides screen
    if (currentRoute == '/scheduled_rides' ||
        currentRoute == '/available_rides') {
      // Refresh available rides list
      _refreshAvailableRidesList();
    } else {
      // Navigate to available rides screen
      Get.to(() => ScheduledRidesScreen());
    }
  }

  void _handleRideCompleted(String rideId, String screen, String currentRoute) {
    if (rideId.isEmpty) return;

    // Check if user is on ride details screen for this ride
    if (currentRoute == '/scheduled_ride_detail' && _isCurrentRide(rideId)) {
      // Refresh ride details data
      _refreshRideDetails(rideId);
    } else if (currentRoute == '/scheduled_rides') {
      // Refresh scheduled rides list
      _refreshScheduledRidesList();
    } else {
      // Navigate to ride review screen (you might need to create this)
      // Note: You'll need to get the ride object from the controller
      // For now, we'll refresh the data instead of navigating
      _refreshScheduledRidesList();
    }
  }

  void _handlePickupStarted(String rideId, String screen, String currentRoute) {
    if (rideId.isEmpty) return;

    // Check if user is on ride details screen for this ride
    if (currentRoute == '/scheduled_ride_detail' && _isCurrentRide(rideId)) {
      // Refresh ride details data
      _refreshRideDetails(rideId);
    } else {
      // Navigate to live tracking screen (you might need to create this)
      // Note: You'll need to get the ride object from the controller
      // For now, we'll refresh the data instead of navigating
      _refreshScheduledRidesList();
    }
  }

  void _handleDriverReached(String rideId, String screen, String currentRoute) {
    if (rideId.isEmpty) return;

    // Check if user is on ride details screen for this ride
    if (currentRoute == '/scheduled_ride_detail' && _isCurrentRide(rideId)) {
      // Refresh ride details data
      _refreshRideDetails(rideId);
    } else {
      // Navigate to ride details screen
      // Note: You'll need to get the ride object from the controller
      // For now, we'll refresh the data instead of navigating
      _refreshScheduledRidesList();
    }
  }

  void _handlePickupCancelled(
      String rideId, String screen, String currentRoute) {
    if (rideId.isEmpty) return;

    // Check if user is on available rides screen
    if (currentRoute == '/scheduled_rides' ||
        currentRoute == '/available_rides') {
      // Refresh available rides list
      _refreshAvailableRidesList();
    } else {
      // Navigate to available rides screen
      Get.to(() => ScheduledRidesScreen());
    }
  }

  void _handleNewRideAvailable(
      String rideId, String screen, String currentRoute) {
    if (rideId.isEmpty) return;

    // Check if user is on available rides screen
    if (currentRoute == '/scheduled_rides' ||
        currentRoute == '/available_rides') {
      // Refresh available rides list
      _refreshAvailableRidesList();
    } else {
      // Navigate to available rides screen
      Get.to(() => ScheduledRidesScreen());
    }
  }

  void _handleRideUpdated(String rideId, String screen, String currentRoute) {
    if (rideId.isEmpty) return;

    // Check if user is on ride details screen for this ride
    if (currentRoute == '/scheduled_ride_detail' && _isCurrentRide(rideId)) {
      // Refresh ride details data
      _refreshRideDetails(rideId);
    } else if (currentRoute == '/scheduled_rides') {
      // Refresh scheduled rides list
      _refreshScheduledRidesList();
    } else {
      // Navigate to ride details screen
      // Note: You'll need to get the ride object from the controller
      // For now, we'll refresh the data instead of navigating
      _refreshScheduledRidesList();
    }
  }

  void _handleRideDeleted(String rideId, String screen, String currentRoute) {
    if (rideId.isEmpty) return;

    // Check if user is on available rides screen
    if (currentRoute == '/scheduled_rides' ||
        currentRoute == '/available_rides') {
      // Refresh available rides list
      _refreshAvailableRidesList();
    } else {
      // Navigate to available rides screen
      Get.to(() => ScheduledRidesScreen());
    }
  }

  // Helper methods
  bool _isCurrentRide(String rideId) {
    // This would need to be implemented based on how you track current ride
    // For now, we'll assume we can get it from the controller
    try {
      // You might need to add a method to check current ride ID
      return true; // Simplified for now
    } catch (e) {
      return false;
    }
  }

  void _refreshRideDetails(String rideId) {
    try {
      final controller = Get.find<ScheduledRideController>();
      // You might need to add a refresh method for ride details
      controller.loadAvailableScheduledRides(refresh: true);
    } catch (e) {
      print('Error refreshing ride details: $e');
    }
  }

  void _refreshScheduledRidesList() {
    try {
      final controller = Get.find<ScheduledRideController>();
      controller.loadJoinedRides(refresh: true);
    } catch (e) {
      print('Error refreshing scheduled rides list: $e');
    }
  }

  void _refreshAvailableRidesList() {
    try {
      final controller = Get.find<ScheduledRideController>();
      controller.loadAvailableScheduledRides(refresh: true);
    } catch (e) {
      print('Error refreshing available rides list: $e');
    }
  }
}
