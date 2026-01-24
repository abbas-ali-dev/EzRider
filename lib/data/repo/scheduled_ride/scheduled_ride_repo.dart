import 'package:ovorideuser/core/utils/method.dart';
import 'package:ovorideuser/core/utils/url_container.dart';
import 'package:ovorideuser/data/model/global/response_model/response_model.dart';
import 'package:ovorideuser/data/services/api_service.dart';

class ScheduledRideRepo {
  ApiClient apiClient;
  ScheduledRideRepo({required this.apiClient});

  // Get available scheduled rides for riders to join
  Future<ResponseModel> getAvailableScheduledRides({String page = '1'}) async {
    String url = "${UrlContainer.baseUrl}scheduled-rides/available";
    if (page != '1') {
      url += "?page=$page";
    }
    ResponseModel responseModel =
        await apiClient.request(url, Method.getMethod, null, passHeader: true);
    return responseModel;
  }

  // Get detailed information about a specific scheduled ride
  Future<ResponseModel> getScheduledRideDetails(String rideId) async {
    String url = "${UrlContainer.baseUrl}scheduled-rides/$rideId";
    ResponseModel responseModel =
        await apiClient.request(url, Method.getMethod, null, passHeader: true);
    return responseModel;
  }

  // Join a scheduled ride
  Future<ResponseModel> joinScheduledRide(
      String rideId, Map<String, dynamic> params) async {
    String url = "${UrlContainer.baseUrl}scheduled-rides/join/$rideId";
    ResponseModel responseModel = await apiClient
        .request(url, Method.postMethod, params, passHeader: true);
    return responseModel;
  }

  // Leave a scheduled ride (cancel participation)
  Future<ResponseModel> leaveScheduledRide(String rideId) async {
    String url = "${UrlContainer.baseUrl}scheduled-rides/leave/$rideId";
    ResponseModel responseModel =
        await apiClient.request(url, Method.postMethod, null, passHeader: true);
    return responseModel;
  }

  // Make cash payment for scheduled ride
  Future<ResponseModel> makeCashPayment(
      String rideId, Map<String, dynamic> params) async {
    String url = "${UrlContainer.baseUrl}scheduled-rides/$rideId/cash-payment";
    ResponseModel responseModel = await apiClient
        .request(url, Method.postMethod, params, passHeader: true);
    return responseModel;
  }

  // Create stripe checkout session for scheduled ride
  Future<ResponseModel> createStripeCheckout(
      String rideId, Map<String, dynamic> params) async {
    String url =
        "${UrlContainer.baseUrl}scheduled-rides/$rideId/stripe-checkout";
    ResponseModel responseModel = await apiClient
        .request(url, Method.postMethod, params, passHeader: true);
    return responseModel;
  }

  // Get available rides for riders to join (legacy method - keeping for backward compatibility)
  Future<ResponseModel> getAvailableRides({String page = '1'}) async {
    String url = "${UrlContainer.baseUrl}scheduled-rides/available";
    if (page != '1') {
      url += "?page=$page";
    }
    ResponseModel responseModel =
        await apiClient.request(url, Method.getMethod, null, passHeader: true);
    return responseModel;
  }

  // Join a ride (legacy method - keeping for backward compatibility)
  Future<ResponseModel> joinRide(
      String rideId, Map<String, dynamic> params) async {
    String url = "${UrlContainer.baseUrl}ride/join/$rideId";
    ResponseModel responseModel = await apiClient
        .request(url, Method.postMethod, params, passHeader: true);
    return responseModel;
  }

  // Get pending passenger requests for a driver
  Future<ResponseModel> getPendingPassengers(String rideId) async {
    String url = "${UrlContainer.baseUrl}driver/rides/passengers/$rideId";
    ResponseModel responseModel =
        await apiClient.request(url, Method.getMethod, null, passHeader: true);
    return responseModel;
  }

  // Driver approve pending passenger request
  Future<ResponseModel> approvePassenger(String rideId, String riderId) async {
    String url =
        "${UrlContainer.baseUrl}driver/rides/approve-passenger/$rideId/$riderId";
    ResponseModel responseModel =
        await apiClient.request(url, Method.postMethod, null, passHeader: true);
    return responseModel;
  }

  // Check rider's joined rides
  Future<ResponseModel> getJoinedRides({String page = '1'}) async {
    String url = "${UrlContainer.baseUrl}scheduled-rides/my-rides";
    if (page != '1') {
      url += "?page=$page";
    }
    ResponseModel responseModel =
        await apiClient.request(url, Method.getMethod, null, passHeader: true);
    return responseModel;
  }

  // Rider make cash payment - uses same endpoint as simple ride
  Future<ResponseModel> makePassengerPayment(
      String passengerId, Map<String, dynamic> params) async {
    String url = "${UrlContainer.baseUrl}ride/passenger-payment/$passengerId";
    print('=== CASH PAYMENT API CALL ===');
    print('URL: $url');
    print('Params: $params');
    print('Passenger ID: $passengerId');
    ResponseModel responseModel = await apiClient
        .request(url, Method.postMethod, params, passHeader: true);
    print('Response Status: ${responseModel.statusCode}');
    print('Response Body: ${responseModel.responseJson}');
    print('=============================');
    return responseModel;
  }

  // Start scheduled ride
  Future<ResponseModel> startScheduledRide(String rideId) async {
    String url = "${UrlContainer.baseUrl}start-scheduled-ride";
    Map<String, String> params = {
      'ride_id': rideId,
    };
    ResponseModel responseModel = await apiClient
        .request(url, Method.postMethod, params, passHeader: true);
    return responseModel;
  }
}
