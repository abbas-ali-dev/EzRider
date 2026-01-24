import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:ovorideuser/core/helper/shared_preference_helper.dart';
import 'package:ovorideuser/core/utils/method.dart';
import 'package:ovorideuser/core/utils/url_container.dart';
import 'package:ovorideuser/data/model/global/response_model/response_model.dart';
import 'package:ovorideuser/data/services/api_service.dart';

class SocialAuthRepo {
  ApiClient apiClient;

  SocialAuthRepo({required this.apiClient});

  Future<ResponseModel> socialLoginUser({
    String accessToken = '',
    String? provider,
  }) async {
    Map<String, String>? map;

    if (provider == 'google') {
      map = {'token': accessToken, 'provider': "google"};
    }

    if (provider == 'linkedin') {
      map = {'token': accessToken, 'provider': "linkedin"};
    }

    if (provider == 'facebook') {
      map = {'token': accessToken, 'provider': "facebook"};
    }

    String url = '${UrlContainer.baseUrl}${UrlContainer.socialLoginEndPoint}';
    ResponseModel model =
        await apiClient.request(url, Method.postMethod, map, passHeader: false);
    return model;
  }

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

    FirebaseMessaging firebaseMessaging = FirebaseMessaging.instance;
    bool success = false;

    try {
      // Always get the current token to ensure we have the latest one
      String? fcmDeviceToken = await firebaseMessaging.getToken();

      if (fcmDeviceToken != null && fcmDeviceToken.isNotEmpty) {
        // If stored token is empty or different, update it
        if (deviceToken.isEmpty || deviceToken != fcmDeviceToken) {
          // Save to SharedPreferences first
          await apiClient.sharedPreferences
              .setString(SharedPreferenceHelper.fcmDeviceKey, fcmDeviceToken);

          // Then send to server
          success = await sendUpdatedToken(fcmDeviceToken);
        } else {
          // Token is already stored and matches, but still send to server to ensure it's up to date
          success = await sendUpdatedToken(fcmDeviceToken);
        }
      }

      // Also set up listener for token refresh
      firebaseMessaging.onTokenRefresh.listen((refreshedToken) async {
        await apiClient.sharedPreferences
            .setString(SharedPreferenceHelper.fcmDeviceKey, refreshedToken);
        await sendUpdatedToken(refreshedToken);
      });
    } catch (e) {
      success = false;
    }

    return success;
  }

  Future<bool> sendUpdatedToken(String deviceToken) async {
    if (deviceToken.isEmpty) {
      return false;
    }

    String url = '${UrlContainer.baseUrl}${UrlContainer.deviceTokenEndPoint}';
    Map<String, String> map = deviceTokenMap(deviceToken);

    try {
      await apiClient.request(url, Method.postMethod, map, passHeader: true);
      return true;
    } catch (e) {
      return false;
    }
  }

  Map<String, String> deviceTokenMap(String deviceToken) {
    Map<String, String> map = {'token': deviceToken.toString()};
    return map;
  }
}
