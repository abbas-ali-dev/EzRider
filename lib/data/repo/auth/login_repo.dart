import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:ovorideuser/core/helper/shared_preference_helper.dart';
import 'package:ovorideuser/core/helper/string_format_helper.dart';
import 'package:ovorideuser/core/utils/method.dart';
import 'package:ovorideuser/core/utils/my_strings.dart';
import 'package:ovorideuser/core/utils/url_container.dart';
import 'package:ovorideuser/data/model/auth/verification/email_verification_model.dart';
import 'package:ovorideuser/data/model/global/response_model/response_model.dart';
import 'package:ovorideuser/data/services/api_service.dart';
import 'package:ovorideuser/presentation/components/snack_bar/show_custom_snackbar.dart';

class LoginRepo {
  ApiClient apiClient;

  LoginRepo({required this.apiClient});

  Future<ResponseModel> loginUser(String email, String password) async {
    Map<String, String> map = {'username': email, 'password': password};
    String url = '${UrlContainer.baseUrl}${UrlContainer.loginEndPoint}';

    ResponseModel model =
        await apiClient.request(url, Method.postMethod, map, passHeader: false);

    return model;
  }

  Future<String> forgetPassword(String type, String value) async {
    final map = modelToMap(value, type);
    String url =
        '${UrlContainer.baseUrl}${UrlContainer.forgetPasswordEndPoint}';
    final response = await apiClient.request(url, Method.postMethod, map,
        isOnlyAcceptType: true, passHeader: true);

    EmailVerificationModel model =
        EmailVerificationModel.fromJson(jsonDecode(response.responseJson));

    if (model.status.toLowerCase() == "success") {
      apiClient.sharedPreferences.setString(
          SharedPreferenceHelper.userEmailKey, model.data?.email ?? '');
      CustomSnackBar.success(successList: [
        '${MyStrings.passwordResetEmailSentTo} ${model.data?.email ?? MyStrings.yourEmail}'
      ]);
      return model.data?.email ?? '';
    } else {
      CustomSnackBar.error(errorList: model.message ?? [MyStrings.requestFail]);
      return '';
    }
  }

  Map<String, String> modelToMap(String value, String type) {
    Map<String, String> map = {'type': type, 'value': value};
    return map;
  }

  Future<EmailVerificationModel> verifyForgetPassCode(String code) async {
    String? email = apiClient.sharedPreferences
            .getString(SharedPreferenceHelper.userEmailKey) ??
        '';
    Map<String, String> map = {'code': code, 'email': email};

    String url =
        '${UrlContainer.baseUrl}${UrlContainer.passwordVerifyEndPoint}';

    final response = await apiClient.request(url, Method.postMethod, map,
        passHeader: true, isOnlyAcceptType: true);

    EmailVerificationModel model =
        EmailVerificationModel.fromJson(jsonDecode(response.responseJson));
    if (model.status == 'success') {
      model.setCode(200);
      return model;
    } else {
      model.setCode(400);
      return model;
    }
  }

  Future<EmailVerificationModel> resetPassword(
      String email, String password, String code) async {
    Map<String, String> map = {
      'token': code,
      'email': email,
      'password': password,
      'password_confirmation': password,
    };

    Uri url = Uri.parse(
        '${UrlContainer.baseUrl}${UrlContainer.resetPasswordEndPoint}');

    final response = await http.post(url, body: map, headers: {
      "Accept": "application/json",
      "dev-token":
          "\$2y\$12\$mEVBW3QASB5HMBv8igls3ejh6zw2A0Xb480HWAmYq6BY9xEifyBjG",
    });
    EmailVerificationModel model =
        EmailVerificationModel.fromJson(jsonDecode(response.body));

    if (model.status == 'success') {
      CustomSnackBar.success(successList: model.message ?? []);
      model.setCode(200);
      return model;
    } else {
      CustomSnackBar.error(errorList: model.message ?? []);
      model.setCode(400);
      return model;
    }
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
        printX('🔑 FCM Token retrieved: $fcmDeviceToken');

        // If stored token is empty or different, update it
        if (deviceToken.isEmpty || deviceToken != fcmDeviceToken) {
          // Save to SharedPreferences first
          await apiClient.sharedPreferences
              .setString(SharedPreferenceHelper.fcmDeviceKey, fcmDeviceToken);
          printX('🔑 FCM Token saved to SharedPreferences');

          // Then send to server
          success = await sendUpdatedToken(fcmDeviceToken);
        } else {
          // Token is already stored and matches, but still send to server to ensure it's up to date
          success = await sendUpdatedToken(fcmDeviceToken);
        }
      } else {
        printX('❌ FCM Token is null or empty');
      }

      // Also set up listener for token refresh
      firebaseMessaging.onTokenRefresh.listen((refreshedToken) async {
        printX('🔄 FCM Token refreshed: $refreshedToken');
        await apiClient.sharedPreferences
            .setString(SharedPreferenceHelper.fcmDeviceKey, refreshedToken);
        await sendUpdatedToken(refreshedToken);
      });
    } catch (e) {
      printX('❌ Error getting FCM token: $e');
      success = false;
    }

    return success;
  }

  Future<bool> sendUpdatedToken(String deviceToken) async {
    if (deviceToken.isEmpty) {
      printX('⚠️ Cannot send empty device token');
      return false;
    }

    String url = '${UrlContainer.baseUrl}${UrlContainer.deviceTokenEndPoint}';
    Map<String, String> map = deviceTokenMap(deviceToken);

    try {
      await apiClient.request(url, Method.postMethod, map, passHeader: true);
      printX('✅ Device token sent to server successfully');
      return true;
    } catch (e) {
      printX('❌ Error sending device token to server: $e');
      return false;
    }
  }

  Map<String, String> deviceTokenMap(String deviceToken) {
    Map<String, String> map = {'token': deviceToken.toString()};
    return map;
  }

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

    String url = '${UrlContainer.baseUrl}${UrlContainer.socialLoginEndPoint}';

    ResponseModel model =
        await apiClient.request(url, Method.postMethod, map, passHeader: false);

    return model;
  }
}
