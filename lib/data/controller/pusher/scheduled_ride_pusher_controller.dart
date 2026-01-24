import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ovorideuser/core/helper/shared_preference_helper.dart';
import 'package:ovorideuser/core/helper/string_format_helper.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ovorideuser/core/utils/url_container.dart';
import 'package:ovorideuser/core/utils/util.dart';
import 'package:ovorideuser/core/utils/my_color.dart';
import 'package:ovorideuser/data/model/general_setting/general_setting_response_model.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import 'package:get/get.dart';
import 'package:ovorideuser/data/services/api_service.dart';

class ScheduledRidePusherController extends GetxController {
  final ApiClient apiClient;

  ScheduledRidePusherController({required this.apiClient});

  PusherChannelsFlutter pusher = PusherChannelsFlutter.getInstance();

  bool isPusherLoading = false;
  String appKey = '';
  String cluster = '';
  String token = '';
  String userId = '';
  String scheduledRideId = '';

  PusherConfig pusherConfig = PusherConfig();

  // Scheduled ride specific events
  final events = [
    "driver_location", // Driver's live location update
    "pickup_started", // Driver started coming to pickup
    "passenger_picked", // Passenger picked up
    "ride_completed", // Ride completed
    "driver_arrived", // Driver arrived at pickup
  ];

  // Callback for location updates
  Function(LatLng)? onDriverLocationUpdate;

  void subscribePusher({
    required String rideId,
    Function(LatLng)? onLocationUpdate,
  }) async {
    isPusherLoading = true;
    scheduledRideId = rideId;
    onDriverLocationUpdate = onLocationUpdate;

    pusherConfig = apiClient.getPushConfig();
    appKey = pusherConfig.appKey ?? '';
    cluster = pusherConfig.cluster ?? '';
    token = apiClient.sharedPreferences
            .getString(SharedPreferenceHelper.accessTokenKey) ?? '';
    userId = apiClient.sharedPreferences
            .getString(SharedPreferenceHelper.userIdKey) ?? '';
    update();

    printX('🔧 RIDER APP - INITIALIZING PUSHER FOR SCHEDULED RIDE');
    printX('📍 Scheduled Ride ID: $scheduledRideId');
    printX('👤 User ID: $userId');
    printX('🔑 Pusher App Key: $appKey');
    printX('🌍 Pusher Cluster: $cluster');
    printX('🎯 Channel: private-scheduled-ride-$scheduledRideId');
    printX('📞 Callback Registered: ${onLocationUpdate != null ? "YES" : "NO"}');

    configure("private-scheduled-ride-$scheduledRideId");
    isPusherLoading = false;
    update();
  }

  Future<void> configure(String channelName) async {
    try {
      await pusher.init(
        apiKey: appKey,
        cluster: cluster,
        onEvent: onEvent,
        onSubscriptionError: onSubscriptionError,
        onError: onError,
        onSubscriptionSucceeded: onSubscriptionSucceeded,
        onConnectionStateChange: onConnectionStateChange,
        onAuthorizer: onAuthorizer,
      );

      await pusher.subscribe(channelName: channelName);
      await pusher.connect();
      printX('Connected to Pusher channel: $channelName');
    } catch (e) {
      printX('Error connecting to Pusher: $e');
    }
  }

  Future<Map<String, dynamic>?> onAuthorizer(
      String channelName, String socketId, options) async {
    try {
      String authUrl =
          "${UrlContainer.baseUrl}${UrlContainer.pusherAuthenticate}$socketId/$channelName";
      printX("Authorizing Pusher: $authUrl");

      http.Response result = await http.post(
        Uri.parse(authUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          "dev-token":
              "\$2y\$12\$mEVBW3QASB5HMBv8igls3ejh6zw2A0Xb480HWAmYq6BY9xEifyBjG",
        },
      );

      if (result.statusCode == 200) {
        Map<String, dynamic> json = jsonDecode(result.body);
        printX('Pusher authorized successfully');
        return json;
      } else {
        printX('Pusher authorization failed: ${result.statusCode}');
        return null;
      }
    } catch (e) {
      printX('Pusher authorization error: $e');
      return null;
    }
  }

  void onConnectionStateChange(
      dynamic currentState, dynamic previousState) async {
    printX("Pusher connection state: $previousState -> $currentState");
  }

  void onEvent(PusherEvent event) {
    try {
      printX('📨 Scheduled Ride Pusher Event: ${event.eventName}');
      printX('📡 Channel: ${event.channelName}');
      printX('📦 Raw Event Data: ${event.data}');

      // Skip system events like pusher:subscription_succeeded
      if (event.eventName.startsWith('pusher:')) {
        printX('⚙️ System event - skipping');
        return;
      }

      if (event.data == null) {
        printX('⚠️ Event data is null - skipping');
        return;
      }

      // Handle both cases: when data is already a Map or when it's a JSON string
      Map<String, dynamic> eventData;
      if (event.data is String) {
        eventData = jsonDecode(event.data);
      } else if (event.data is Map) {
        eventData = Map<String, dynamic>.from(event.data);
      } else {
        printX('Unexpected data type: ${event.data.runtimeType}');
        return;
      }

      printX('Event data received: $eventData');

      // Handle driver location update (the driver app sends 'client-driver_location')
      if (event.eventName == "client-driver_location" ||
          event.eventName == "driver_location" ||
          event.eventName.contains("location")) {
        printX('🗺️ DRIVER LOCATION EVENT DETECTED!');
        printX('📍 Event Name: ${event.eventName}');
        printX('📦 Location Data Fields: ${eventData.keys.toList()}');

        double? latitude = Converter.formatDouble(
            eventData['latitude']?.toString() ??
            eventData['driver_latitude']?.toString() ??
            eventData['driver_live_latitude']?.toString() ??
            eventData['lat']?.toString() ?? '0',
            precision: 10);
        double? longitude = Converter.formatDouble(
            eventData['longitude']?.toString() ??
            eventData['driver_longitude']?.toString() ??
            eventData['driver_live_longitude']?.toString() ??
            eventData['lng']?.toString() ?? '0',
            precision: 10);

        printX('📍 Extracted Coordinates: Lat $latitude, Lng $longitude');

        if (latitude != 0 && longitude != 0) {
          printX('✅ Valid Driver Location Update: Lat $latitude, Lng $longitude');
          printX('🚗 Additional Info - Speed: ${eventData['speed']}, Heading: ${eventData['heading']}');

          // Call the callback to update map
          if (onDriverLocationUpdate != null) {
            printX('🗺️ Updating map with new driver location');
            onDriverLocationUpdate!(LatLng(latitude, longitude));
          } else {
            printX('⚠️ No location update callback registered');
          }
        } else {
          printX('❌ Invalid coordinates received: Lat $latitude, Lng $longitude');
        }
      }

      // Handle other events
      else if (event.eventName == "driver_arrived") {
        printX('🚗 Driver has arrived at pickup location');
        printX('📍 Event data: $eventData');

        // Vibrate to notify user
        MyUtils.vibrate();

        // Show notification dialog
        Get.dialog(
          AlertDialog(
            title: Row(
              children: [
                Icon(Icons.local_taxi, color: MyColor.getPrimaryColor(), size: 30),
                const SizedBox(width: 10),
                const Text('Driver Arrived!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your driver has arrived at the pickup location.',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 10),
                if (eventData['driver_name'] != null)
                  Text(
                    'Driver: ${eventData['driver_name']}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                if (eventData['vehicle_info'] != null)
                  Text(
                    'Vehicle: ${eventData['vehicle_info']}',
                    style: const TextStyle(color: Colors.grey),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('OK'),
              ),
            ],
          ),
          barrierDismissible: false,
        );

        // Also show a snackbar for quick notification
        Get.snackbar(
          '🚗 Driver Arrived',
          'Your driver is waiting at the pickup location',
          backgroundColor: MyColor.greenSuccessColor,
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
          snackPosition: SnackPosition.TOP,
        );
      }
      else if (event.eventName == "pickup_started") {
        printX('Driver is on the way to pickup');
      }
      else if (event.eventName == "passenger_picked") {
        printX('Passenger has been picked up');
      }
      else if (event.eventName == "ride_completed") {
        printX('Scheduled ride completed');
      }
      else {
        printX('⚠️ Unhandled Pusher event: ${event.eventName}');
        printX('📦 Event data: $eventData');
      }

    } catch (e) {
      printX('❌ Error handling Pusher event: $e');
      printX('🔍 Event that caused error: ${event.eventName}');
    }
  }

  void onError(String message, int? code, dynamic e) {
    printX("Pusher Error: $message");
  }

  void onSubscriptionSucceeded(String channelName, dynamic data) {
    printX("✅ RIDER APP - Successfully subscribed to Pusher channel: $channelName");
    printX("🎯 Ready to receive driver location updates for scheduled ride: $scheduledRideId");
  }

  void onSubscriptionError(String message, dynamic e) {
    printX("❌ RIDER APP - Pusher Subscription Error: $message");
    printX("⚠️ Failed to subscribe to scheduled ride channel: private-scheduled-ride-$scheduledRideId");
    printX("🔧 Will rely on API polling fallback for location updates");
  }

  void clearData() {
    closePusher();
  }

  void closePusher() async {
    if (scheduledRideId.isNotEmpty) {
      await pusher.unsubscribe(channelName: "private-scheduled-ride-$scheduledRideId");
      await pusher.disconnect();
      printX('Disconnected from scheduled ride Pusher');
    }
  }

  @override
  void onClose() {
    clearData();
    super.onClose();
  }
}