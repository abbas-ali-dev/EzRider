// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:ovorideuser/core/helper/shared_preference_helper.dart';
import 'package:ovorideuser/core/helper/string_format_helper.dart';
import 'package:ovorideuser/core/utils/method.dart';
import 'package:ovorideuser/core/utils/url_container.dart';
import 'package:ovorideuser/data/services/api_service.dart';
import 'package:path_provider/path_provider.dart';

class PushNotificationService {
  ApiClient apiClient;
  PushNotificationService({required this.apiClient});

  Future<void> setupInteractedMessage() async {
    // Firebase is already initialized in main.dart
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await _requestPermissions();

    await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    await enableIOSNotifications();
    await registerNotificationListeners();

    // Handle notification when app is opened from terminated state
    RemoteMessage? initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationNavigation(initialMessage);
    }

    // Handle notification when app is in background and opened
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationNavigation(message);
    });
  }

  void _handleNotificationNavigation(RemoteMessage message) {
    try {
      if (message.data.isNotEmpty) {
        Map<String, dynamic> payload = message.data;
        printX('Notification opened with data: $payload');

        String? remark = payload['for_app'];
        if (remark != null && remark.isNotEmpty && remark.contains('-')) {
          String route = remark.split('-')[0];
          String id = remark.split('-')[1];
          Get.toNamed(route, arguments: id);
        }
      }
    } catch (e) {
      printX('Error handling notification navigation: $e');
    }
  }

  registerNotificationListeners() async {
    AndroidNotificationChannel channel = androidNotificationChannel();
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    var androidSettings =
        const AndroidInitializationSettings('@mipmap/ic_launcher');
    var iOSSettings = const DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true);
    var initSettings =
        InitializationSettings(android: androidSettings, iOS: iOSSettings);
    flutterLocalNotificationsPlugin.initialize(initSettings,
        onDidReceiveNotificationResponse: (message) async {
      try {
        String? payloadString = message.payload is String
            ? message.payload
            : jsonEncode(message.payload);
        printX('remarkNotification $payloadString');
        if (payloadString != null && payloadString.isNotEmpty) {
          Map<dynamic, dynamic> payloadMap = jsonDecode(payloadString);
          Map<String, String> payload = payloadMap
              .map((key, value) => MapEntry(key.toString(), value.toString()));

          printX('remarkNotification ${payload['for_app']}');
          printX('remarkNotification ${payload['ride_id']}');
          String? remark = payload['for_app'];

          if (remark != null && remark.isNotEmpty) {
            String route = remark.split('-')[0];
            String id = remark.split('-')[1];
            //redirect any specific page
            Get.toNamed(route, arguments: id);
          }
        }
      } catch (e) {
        if (kDebugMode) {
          printX(e.toString());
        }
      }
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage? message) async {
      RemoteNotification? notification = message!.notification;
      AndroidNotification? android = message.notification?.android;
      printX(">>>>>> ${message.notification?.toMap()}");
      printX(">>>>>> ${android?.imageUrl}");
      if (notification != null && android != null) {
        late BigPictureStyleInformation bigPictureStyle;
        if (android.imageUrl != null) {
          final http.Response response = await http.get(
            Uri.parse(android.imageUrl!),
            headers: {
              "dev-token":
                  "\$2y\$12\$mEVBW3QASB5HMBv8igls3ejh6zw2A0Xb480HWAmYq6BY9xEifyBjG",
            },
          );
          final String localImagePath =
              await _saveImageLocally(response.bodyBytes);
          bigPictureStyle = BigPictureStyleInformation(
            FilePathAndroidBitmap(localImagePath),
            contentTitle: notification.title,
            summaryText: notification.body,
          );
        }
        flutterLocalNotificationsPlugin.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                channel.id,
                channel.name,
                channelDescription: channel.description,
                icon: '@mipmap/ic_launcher',
                playSound: true,
                enableVibration: true,
                enableLights: true,
                fullScreenIntent: true,
                priority: Priority.high,
                styleInformation: android.imageUrl != null
                    ? bigPictureStyle
                    : const BigTextStyleInformation(''),
                importance: Importance.high,
              ),
            ),
            payload: jsonEncode(message.data));
      }
    });
  }

  enableIOSNotifications() async {
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true, // Required to display a heads up notification
      badge: true,
      sound: true,
    );
  }

  androidNotificationChannel() => const AndroidNotificationChannel(
        'high_importance_channel', // id
        'High Importance Notifications', // title
        description: 'This channel is used for important notifications.',
        playSound: true,
        enableVibration: true,
        enableLights: true,
        importance: Importance.high,
      );

  Future<void> _requestPermissions() async {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    if (Platform.isIOS || Platform.isMacOS) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    } else if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();
    }
  }

  // Function to save the image locally
  Future<String> _saveImageLocally(Uint8List bytes) async {
    final directory = await getTemporaryDirectory();
    final imagePath = '${directory.path}/notification_image.png';
    final file = File(imagePath);
    await file.writeAsBytes(bytes);
    return imagePath;
  }

  //
  Future<bool> sendUserToken() async {
    String deviceToken;
    if (apiClient.sharedPreferences
        .containsKey(SharedPreferenceHelper.fcmDeviceKey)) {
      deviceToken = apiClient.sharedPreferences
              .getString(SharedPreferenceHelper.fcmDeviceKey) ??
          '';
    } else {
      deviceToken = '';
    }

    print("🔑 Current stored FCM Token: $deviceToken");

    FirebaseMessaging firebaseMessaging = FirebaseMessaging.instance;
    bool success = false;

    try {
      // Always get the current token to ensure we have the latest one
      String? fcmDeviceToken = await firebaseMessaging.getToken();

      if (fcmDeviceToken != null && fcmDeviceToken.isNotEmpty) {
        print("🔑 FCM Token retrieved: $fcmDeviceToken");

        // If stored token is empty or different, update it
        if (deviceToken.isEmpty || deviceToken != fcmDeviceToken) {
          // Save to SharedPreferences first
          await apiClient.sharedPreferences
              .setString(SharedPreferenceHelper.fcmDeviceKey, fcmDeviceToken);
          print("🔑 FCM Token saved to SharedPreferences");

          // Then send to server
          success = await sendUpdatedToken(fcmDeviceToken);
        } else {
          print("🔑 FCM Token already stored, sending to server");
          success = await sendUpdatedToken(fcmDeviceToken);
        }
      } else {
        print("❌ FCM Token is null or empty");
      }

      // Also set up listener for token refresh
      firebaseMessaging.onTokenRefresh.listen((refreshedToken) async {
        print("🔄 FCM Token refreshed: $refreshedToken");
        await apiClient.sharedPreferences
            .setString(SharedPreferenceHelper.fcmDeviceKey, refreshedToken);
        await sendUpdatedToken(refreshedToken);
      });
    } catch (e) {
      print("❌ Error getting FCM token: $e");
      loggerX(e);
      success = false;
    }

    return success;
  }

  Future<bool> sendUpdatedToken(String deviceToken) async {
    if (deviceToken.isEmpty) {
      print("⚠️ Cannot send empty device token");
      return false;
    }

    String url = '${UrlContainer.baseUrl}${UrlContainer.deviceTokenEndPoint}';
    Map<String, String> map = deviceTokenMap(deviceToken);

    try {
      await apiClient.request(url, Method.postMethod, map, passHeader: true);
      print("✅ Device token sent to server successfully");
      return true;
    } catch (e) {
      print("❌ Error sending device token to server: $e");
      loggerX(e);
      return false;
    }
  }

  Map<String, String> deviceTokenMap(String deviceToken) {
    Map<String, String> map = {'token': deviceToken.toString()};
    return map;
  }
}
