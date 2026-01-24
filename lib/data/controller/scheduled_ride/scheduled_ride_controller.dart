import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geocoding/geocoding.dart';
import 'package:ovorideuser/core/helper/string_format_helper.dart';
import 'package:ovorideuser/core/helper/shared_preference_helper.dart';
import 'package:ovorideuser/core/utils/my_strings.dart';
import 'package:ovorideuser/data/model/global/response_model/response_model.dart';
import 'package:ovorideuser/data/model/scheduled_ride/scheduled_ride_model.dart';
import 'package:ovorideuser/data/repo/scheduled_ride/scheduled_ride_repo.dart';
import 'package:ovorideuser/presentation/components/snack_bar/show_custom_snackbar.dart';
import 'dart:async'; // Added for Timer
import 'package:geolocator/geolocator.dart'; // Added for geolocator
import 'package:ovorideuser/data/model/location/selected_location_info.dart';

import '../../../core/utils/method.dart';
import '../../../core/utils/url_container.dart'; // Added for SelectedLocationInfo

class ScheduledRideController extends GetxController {
  ScheduledRideRepo repo;
  ScheduledRideController({required this.repo});

  // Loading states
  bool isLoading = false;
  bool isLoadingJoinedRides = false;
  bool isJoining = false;
  bool isMakingPayment = false;
  bool isLeaving = false;
  bool isProcessingCashPayment = false;
  bool isCreatingStripeCheckout = false;

  // Data lists
  List<AvailableRideModel> availableRides = [];
  List<JoinedRideModel> joinedRides = [];
  List<PassengerModel> pendingPassengers = [];

  // Current active ride
  JoinedRideModel? currentScheduledRide;
  AvailableRideModel? currentAvailableScheduledRide;
  UserPassenger? userPassengerInfo;  // User's passenger info if they've joined current ride

  // Pagination
  String? nextPageUrl;
  int currentPage = 1;
  bool hasNextPage = false;

  // Search and filter
  String searchQuery = '';
  String selectedTab =
      'available'; // 'available', 'joined' for main screen tabs
  String selectedFilter =
      'all'; // 'all', 'pending', 'approved', 'completed' for joined rides filter

  // Switch tab and load appropriate data
  void switchTab(String tab) {
    selectedTab = tab;
    update();

    // Load data for the selected tab
    if (tab == 'available') {
      if (availableRides.isEmpty) {
        loadAvailableScheduledRides();
      }
    } else if (tab == 'joined') {
      if (joinedRides.isEmpty) {
        loadJoinedRides();
      }
    }
  }

  // Form controllers for joining ride
  TextEditingController noteController = TextEditingController();
  TextEditingController pickupLocationController = TextEditingController();
  TextEditingController destinationController = TextEditingController();

  // Selected values for joining ride
  double? pickupLatitude;
  double? pickupLongitude;
  double? destinationLatitude;
  double? destinationLongitude;
  int? seatsBooked;

  // New fields for pickup location
  SelectedLocationInfo? pickupLocationInfo;
  bool showLocationError = false;

  // Timestamps for last refresh
  DateTime? lastAvailableRidesRefresh;
  DateTime? lastJoinedRidesRefresh;

  // Auto refresh timer
  Timer? _autoRefreshTimer;
  // Auto refresh settings
  bool isAutoRefreshEnabled = true;
  static const Duration autoRefreshInterval =
      Duration(minutes: 5); // Refresh every 5 minutes

  // Toggle auto refresh
  void toggleAutoRefresh() {
    isAutoRefreshEnabled = !isAutoRefreshEnabled;
    if (isAutoRefreshEnabled) {
      startAutoRefresh();
    } else {
      stopAutoRefresh();
    }
    update();
  }

  // Start auto refresh
  void startAutoRefresh() {
    if (!isAutoRefreshEnabled) return;

    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(autoRefreshInterval, (timer) {
      if (!isRefreshing) {
        refreshCurrentTabSilently(); // Use silent refresh for auto-refresh
      }
    });
  }

  // Stop auto refresh
  void stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  @override
  void onInit() {
    super.onInit();
    loadAvailableScheduledRides();
    loadJoinedRides();
    startAutoRefresh();
  }

  @override
  void onClose() {
    stopAutoRefresh();
    super.onClose();
  }

  // Get formatted last refresh time
  String getLastRefreshTime() {
    if (selectedTab == 'available') {
      return lastAvailableRidesRefresh != null
          ? 'Last updated: ${_formatTime(lastAvailableRidesRefresh!)}'
          : 'Never refreshed';
    } else {
      return lastJoinedRidesRefresh != null
          ? 'Last updated: ${_formatTime(lastJoinedRidesRefresh!)}'
          : 'Never refreshed';
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  // Check if any refresh operation is in progress
  bool get isRefreshing => isLoading || isLoadingJoinedRides;

  // Refresh only the current tab
  Future<void> refreshCurrentTab() async {
    try {
      if (selectedTab == 'available') {
        await loadAvailableScheduledRides(refresh: true);
        // Silently refresh - no success message
      } else {
        await loadJoinedRides(refresh: true);
        // Silently refresh - no success message
      }
    } catch (e) {
      printX(e);
      CustomSnackBar.error(errorList: [MyStrings.somethingWentWrong]);
    }
  }

  // Refresh current tab silently (for auto-refresh) - no error messages shown
  Future<void> refreshCurrentTabSilently() async {
    try {
      if (selectedTab == 'available') {
        await loadAvailableScheduledRides(refresh: true);
      } else {
        await loadJoinedRides(refresh: true);
      }
    } catch (e) {
      // Log error but don't show to user during auto-refresh
      printX('Silent refresh error: $e');
    }
  }

  // Refresh both available and joined rides
  Future<void> refreshAllRides() async {
    try {
      await Future.wait([
        loadAvailableScheduledRides(refresh: true),
        loadJoinedRides(refresh: true),
      ]);

      // Silently refresh - no success message
    } catch (e) {
      printX(e);
      CustomSnackBar.error(errorList: [MyStrings.somethingWentWrong]);
    }
  }

  // Load available rides
  Future<void> loadAvailableRides({bool refresh = false}) async {
    if (refresh) {
      currentPage = 1;
      availableRides.clear();
    }

    isLoading = true;
    update();

    try {
      ResponseModel responseModel = await repo.getAvailableRides(
        page: currentPage.toString(),
      );

      if (responseModel.statusCode == 200) {
        AvailableRidesResponseModel model =
            AvailableRidesResponseModel.fromJson(
                jsonDecode(responseModel.responseJson));

        if (model.status == MyStrings.success) {
          if (refresh) {
            availableRides.clear();
            lastAvailableRidesRefresh = DateTime.now();
          }

          // Add new rides if any
          if (model.data?.scheduledRides != null) {
            availableRides.addAll(model.data!.scheduledRides!);
          }

          // ALWAYS set current scheduled ride from API response (at root level, not in data)
          if (model.currentScheduledRide != null) {
            currentAvailableScheduledRide = model.currentScheduledRide;
            printX('Current scheduled ride set: ID ${currentAvailableScheduledRide!.id}');

            // Check if driver location is provided
            if (currentAvailableScheduledRide!.driverCurrentLatitude != null &&
                currentAvailableScheduledRide!.driverCurrentLongitude != null) {
              printX('Driver live location provided: Lat ${currentAvailableScheduledRide!.driverCurrentLatitude}, Lng ${currentAvailableScheduledRide!.driverCurrentLongitude}');
            } else {
              printX('WARNING: Driver live location NOT provided by API');
            }

            // Also set user passenger info if available
            userPassengerInfo = model.userPassenger;
            if (userPassengerInfo != null) {
              printX('User passenger info set: Status ${userPassengerInfo!.status}, Pickup Status: ${userPassengerInfo!.pickupStatus}');
            } else {
              printX('WARNING: user_passenger is null in response!');

              // Check if user is in the passengers list of current ride
              if (currentAvailableScheduledRide!.passengers != null && currentAvailableScheduledRide!.passengers!.isNotEmpty) {
                printX('Checking ${currentAvailableScheduledRide!.passengers!.length} passengers in current ride');
                // Get current user ID from SharedPreferences
                String? currentUserId = repo.apiClient.sharedPreferences.getString(SharedPreferenceHelper.userIdKey);
                printX('Current user ID: $currentUserId');

                // Look for current user in passengers list
                for (var passenger in currentAvailableScheduledRide!.passengers!) {
                  printX('Checking passenger - User ID from user object: ${passenger.user?.id}, Direct userId: ${passenger.userId}, Status: ${passenger.status}');

                  // Check both user.id and userId fields
                  bool isCurrentUser = (passenger.user?.id == currentUserId) ||
                                       (passenger.userId == currentUserId);

                  if (isCurrentUser) {
                    printX('FOUND CURRENT USER IN PASSENGERS LIST! Status: ${passenger.status}');

                    // Create a UserPassenger object from the passenger data
                    // Use available fields from the passenger
                    userPassengerInfo = UserPassenger(
                      id: passenger.id,
                      status: passenger.status,
                      seatsBooked: passenger.seatsBooked,
                      farePerSeat: passenger.farePerSeat,
                      pickupStatus: passenger.pickupStatus,
                      // Include pickup location fields from passenger
                      pickupLocation: passenger.pickupLocation,
                      pickupLatitude: passenger.pickupLatitude,
                      pickupLongitude: passenger.pickupLongitude,
                      // Calculate total fare if we have fare per seat
                      totalFare: passenger.farePerSeat != null
                          ? (double.tryParse(passenger.farePerSeat!) ?? 0).toString()
                          : currentAvailableScheduledRide!.estimatedFare,
                    );
                    printX('Created userPassengerInfo from passengers list - Status: ${userPassengerInfo!.status}, PickupStatus: ${userPassengerInfo!.pickupStatus}');
                    break;
                  }
                }

                if (userPassengerInfo == null) {
                  printX('Current user NOT found in passengers list');
                }
              } else {
                printX('No passengers in current ride');
              }
            }
          } else {
            // Only clear if explicitly null in response
            currentAvailableScheduledRide = null;
            userPassengerInfo = null;
            printX('No current scheduled ride in response');
          }

          nextPageUrl = model.data?.nextPageUrl;
          hasNextPage = nextPageUrl != null;
          currentPage++;
        } else {
          CustomSnackBar.error(
              errorList: model.message ?? [MyStrings.somethingWentWrong]);
        }
      } else {
        CustomSnackBar.error(errorList: [responseModel.message]);
      }
    } catch (e) {
      printX(e);
      CustomSnackBar.error(errorList: [MyStrings.somethingWentWrong]);
    }

    isLoading = false;
    update();
  }

  // Load available scheduled rides (new API)
  Future<void> loadAvailableScheduledRides({bool refresh = false}) async {
    if (refresh) {
      currentPage = 1;
      availableRides.clear();
      // Don't clear currentAvailableScheduledRide on refresh - it will be updated from API
    }

    isLoading = true;
    update();

    try {
      ResponseModel responseModel = await repo.getAvailableScheduledRides(
        page: currentPage.toString(),
      );

      if (responseModel.statusCode == 200) {
        // Parse the JSON response
        Map<String, dynamic> jsonResponse = jsonDecode(responseModel.responseJson);

        // Debug: Check if driver location fields exist in the raw response
        if (jsonResponse["current_scheduled_ride"] != null) {
          var currentRide = jsonResponse["current_scheduled_ride"];
          printX('=== CHECKING FOR DRIVER LOCATION IN API RESPONSE ===');

          // Check various possible field names for driver location
          if (currentRide["driver_current_latitude"] != null) {
            printX('Found driver_current_latitude: ${currentRide["driver_current_latitude"]}');
          }
          if (currentRide["driver_current_longitude"] != null) {
            printX('Found driver_current_longitude: ${currentRide["driver_current_longitude"]}');
          }
          if (currentRide["driver_latitude"] != null) {
            printX('Found driver_latitude: ${currentRide["driver_latitude"]}');
          }
          if (currentRide["driver_longitude"] != null) {
            printX('Found driver_longitude: ${currentRide["driver_longitude"]}');
          }
          if (currentRide["current_latitude"] != null) {
            printX('Found current_latitude: ${currentRide["current_latitude"]}');
          }
          if (currentRide["current_longitude"] != null) {
            printX('Found current_longitude: ${currentRide["current_longitude"]}');
          }

          // Check if driver object has location
          if (currentRide["driver"] != null) {
            var driver = currentRide["driver"];
            if (driver["latitude"] != null) {
              printX('Found driver.latitude: ${driver["latitude"]}');
            }
            if (driver["longitude"] != null) {
              printX('Found driver.longitude: ${driver["longitude"]}');
            }
            if (driver["current_latitude"] != null) {
              printX('Found driver.current_latitude: ${driver["current_latitude"]}');
            }
            if (driver["current_longitude"] != null) {
              printX('Found driver.current_longitude: ${driver["current_longitude"]}');
            }
          }

          printX('=== END DRIVER LOCATION CHECK ===');
        }

        AvailableRidesResponseModel model =
            AvailableRidesResponseModel.fromJson(jsonResponse);

        if (model.status == MyStrings.success) {
          if (refresh) {
            availableRides.clear();
            lastAvailableRidesRefresh = DateTime.now();
          }

          // Add new rides if any
          if (model.data?.scheduledRides != null) {
            availableRides.addAll(model.data!.scheduledRides!);
          }

          // ALWAYS set current scheduled ride from API response (at root level, not in data)
          if (model.currentScheduledRide != null) {
            currentAvailableScheduledRide = model.currentScheduledRide;
            printX('Current scheduled ride set: ID ${currentAvailableScheduledRide!.id}');

            // Check if driver location is provided
            if (currentAvailableScheduledRide!.driverCurrentLatitude != null &&
                currentAvailableScheduledRide!.driverCurrentLongitude != null) {
              printX('Driver live location provided: Lat ${currentAvailableScheduledRide!.driverCurrentLatitude}, Lng ${currentAvailableScheduledRide!.driverCurrentLongitude}');
            } else {
              printX('WARNING: Driver live location NOT provided by API');
            }

            // Also set user passenger info if available
            userPassengerInfo = model.userPassenger;
            if (userPassengerInfo != null) {
              printX('User passenger info set: Status ${userPassengerInfo!.status}, Pickup Status: ${userPassengerInfo!.pickupStatus}');
            } else {
              printX('WARNING: user_passenger is null in response!');

              // Check if user is in the passengers list of current ride
              if (currentAvailableScheduledRide!.passengers != null && currentAvailableScheduledRide!.passengers!.isNotEmpty) {
                printX('Checking ${currentAvailableScheduledRide!.passengers!.length} passengers in current ride');
                // Get current user ID from SharedPreferences
                String? currentUserId = repo.apiClient.sharedPreferences.getString(SharedPreferenceHelper.userIdKey);
                printX('Current user ID: $currentUserId');

                // Look for current user in passengers list
                for (var passenger in currentAvailableScheduledRide!.passengers!) {
                  printX('Checking passenger - User ID from user object: ${passenger.user?.id}, Direct userId: ${passenger.userId}, Status: ${passenger.status}');

                  // Check both user.id and userId fields
                  bool isCurrentUser = (passenger.user?.id == currentUserId) ||
                                       (passenger.userId == currentUserId);

                  if (isCurrentUser) {
                    printX('FOUND CURRENT USER IN PASSENGERS LIST! Status: ${passenger.status}');

                    // Create a UserPassenger object from the passenger data
                    // Use available fields from the passenger
                    userPassengerInfo = UserPassenger(
                      id: passenger.id,
                      status: passenger.status,
                      seatsBooked: passenger.seatsBooked,
                      farePerSeat: passenger.farePerSeat,
                      pickupStatus: passenger.pickupStatus,
                      // Include pickup location fields from passenger
                      pickupLocation: passenger.pickupLocation,
                      pickupLatitude: passenger.pickupLatitude,
                      pickupLongitude: passenger.pickupLongitude,
                      // Calculate total fare if we have fare per seat
                      totalFare: passenger.farePerSeat != null
                          ? (double.tryParse(passenger.farePerSeat!) ?? 0).toString()
                          : currentAvailableScheduledRide!.estimatedFare,
                    );
                    printX('Created userPassengerInfo from passengers list - Status: ${userPassengerInfo!.status}, PickupStatus: ${userPassengerInfo!.pickupStatus}');
                    break;
                  }
                }

                if (userPassengerInfo == null) {
                  printX('Current user NOT found in passengers list');
                }
              } else {
                printX('No passengers in current ride');
              }
            }
          } else {
            // Only clear if explicitly null in response
            currentAvailableScheduledRide = null;
            userPassengerInfo = null;
            printX('No current scheduled ride in response');
          }

          nextPageUrl = model.data?.nextPageUrl;
          hasNextPage = nextPageUrl != null;
          currentPage++;
        } else {
          CustomSnackBar.error(
              errorList: model.message ?? [MyStrings.somethingWentWrong]);
        }
      } else {
        CustomSnackBar.error(errorList: [responseModel.message]);
      }
    } catch (e) {
      printX(e);
      CustomSnackBar.error(errorList: [MyStrings.somethingWentWrong]);
    }

    isLoading = false;
    update();
  }

  // Get detailed information about a specific scheduled ride
  Future<ScheduledRideDetailsData?> getScheduledRideDetails(
      String rideId) async {
    try {
      ResponseModel responseModel = await repo.getScheduledRideDetails(rideId);

      if (responseModel.statusCode == 200) {
        ScheduledRideDetailsResponseModel model =
            ScheduledRideDetailsResponseModel.fromJson(
                jsonDecode(responseModel.responseJson));

        if (model.status == MyStrings.success) {
          return model.data;
        } else {
          CustomSnackBar.error(
              errorList: model.message ?? [MyStrings.somethingWentWrong]);
        }
      } else {
        CustomSnackBar.error(errorList: [responseModel.message]);
      }
    } catch (e) {
      printX(e);
      CustomSnackBar.error(errorList: [MyStrings.somethingWentWrong]);
    }

    return null;
  }

  // Join a scheduled ride (old API - kept for backward compatibility)
  Future<void> joinScheduledRide(
      String rideId, String seatsBooked, String? note) async {
    isJoining = true;
    update();

    try {
      Map<String, dynamic> params = {
        'seats_booked': seatsBooked,
      };

      if (note != null && note.isNotEmpty) {
        params['note'] = note;
      }

      ResponseModel responseModel =
          await repo.joinScheduledRide(rideId, params);
      if (responseModel.statusCode == 200) {
        JoinScheduledRideResponseModel model =
            JoinScheduledRideResponseModel.fromJson(
                jsonDecode(responseModel.responseJson));

        if (model.status == MyStrings.success) {
          CustomSnackBar.success(
              successList:
                  model.message ?? ['Successfully joined the scheduled ride']);
          loadJoinedRides(refresh: true);
          Get.back(); // Close the join screen
        } else {
          CustomSnackBar.error(
              errorList: model.message ?? [MyStrings.somethingWentWrong]);
        }
      } else {
        CustomSnackBar.error(errorList: [responseModel.message]);
      }
    } catch (e) {
      printX(e);
      CustomSnackBar.error(errorList: [MyStrings.somethingWentWrong]);
    }

    isJoining = false;
    update();
  }

  // Join a scheduled ride with pickup location (new method)
  Future<void> joinScheduledRideWithLocation(
      String rideId, String seatsBooked, String? note) async {
    isJoining = true;
    showLocationError = false;
    update();

    try {
      Map<String, dynamic> params = {
        'seats_booked': seatsBooked,
      };

      // Add pickup location information
      if (pickupLocationInfo != null) {
        params['pickup_location'] = pickupLocationInfo!.getFullAddress(showFull: true);
        params['pickup_latitude'] = pickupLocationInfo!.latitude.toString();
        params['pickup_longitude'] = pickupLocationInfo!.longitude.toString();
      }

      if (note != null && note.isNotEmpty) {
        params['note'] = note;
      }

      ResponseModel responseModel =
          await repo.joinScheduledRide(rideId, params);
      if (responseModel.statusCode == 200) {
        JoinScheduledRideResponseModel model =
            JoinScheduledRideResponseModel.fromJson(
                jsonDecode(responseModel.responseJson));

        if (model.status == MyStrings.success) {
          CustomSnackBar.success(
              successList:
                  model.message ?? ['Successfully joined the scheduled ride']);

          // Clear pickup location info after successful join
          pickupLocationInfo = null;
          showLocationError = false;

          loadJoinedRides(refresh: true);
          Get.back(); // Close the join screen
        } else {
          CustomSnackBar.error(
              errorList: model.message ?? [MyStrings.somethingWentWrong]);
        }
      } else {
        CustomSnackBar.error(errorList: [responseModel.message]);
      }
    } catch (e) {
      printX(e);
      CustomSnackBar.error(errorList: [MyStrings.somethingWentWrong]);
    }

    isJoining = false;
    update();
  }

  // Leave a scheduled ride (cancel participation)
  Future<void> leaveScheduledRide(String rideId) async {
    isLeaving = true;
    update();

    try {
      ResponseModel responseModel = await repo.leaveScheduledRide(rideId);
      if (responseModel.statusCode == 200) {
        LeaveScheduledRideResponseModel model =
            LeaveScheduledRideResponseModel.fromJson(
                jsonDecode(responseModel.responseJson));

        if (model.status == MyStrings.success) {
          CustomSnackBar.success(
              successList:
                  model.message ?? ['Successfully left the scheduled ride']);
          loadJoinedRides(refresh: true);
          loadAvailableScheduledRides(refresh: true);
        } else {
          CustomSnackBar.error(
              errorList: model.message ?? [MyStrings.somethingWentWrong]);
        }
      } else {
        CustomSnackBar.error(errorList: [responseModel.message]);
      }
    } catch (e) {
      printX(e);
      CustomSnackBar.error(errorList: [MyStrings.somethingWentWrong]);
    }

    isLeaving = false;
    update();
  }

  // Load joined rides
  Future<void> loadJoinedRides({bool refresh = false}) async {
    if (refresh) {
      joinedRides.clear();
    }

    isLoadingJoinedRides = true;
    update();

    try {
      ResponseModel responseModel = await repo.getJoinedRides();
      if (responseModel.statusCode == 200) {
        JoinedRidesResponseModel model = JoinedRidesResponseModel.fromJson(
            jsonDecode(responseModel.responseJson));

        if (model.status == MyStrings.success) {
          if (refresh) {
            joinedRides.clear();
            lastJoinedRidesRefresh = DateTime.now();
          }
          joinedRides = model.data?.scheduledRides ?? [];

          // Debug: Log passenger IDs from joined rides
          printX('=== JOINED RIDES DEBUG ===');
          for (var ride in joinedRides) {
            printX('Ride ID: ${ride.id}');
            printX('  passengerId (from API): ${ride.passengerId}');
            printX('  passengerStatus: ${ride.passengerStatus}');
            printX('  fare: ${ride.fare}');
            printX('  passengers count: ${ride.passengers?.length ?? 0}');
            if (ride.passengers != null && ride.passengers!.isNotEmpty) {
              for (var p in ride.passengers!) {
                printX('    Passenger - id: ${p.id}, userId: ${p.userId}, user.id: ${p.user?.id}');
              }
            }
          }
          printX('========================');

          // Set current scheduled ride from API response (at root level, not in data)
          currentScheduledRide = model.currentScheduledRide;

          // Debug logging
          if (currentScheduledRide != null) {
            printX('Current scheduled ride (joined) set: ID ${currentScheduledRide!.id}');
          } else {
            printX('No current scheduled ride in joined rides response');
          }

          // Find the active ride (status == "1") from the joined rides list
          // This is the ride that should be shown as "current active ride"
          _identifyActiveRideFromJoinedRides();
        } else {
          CustomSnackBar.error(
              errorList: model.message ?? [MyStrings.somethingWentWrong]);
        }
      } else {
        CustomSnackBar.error(errorList: [responseModel.message]);
      }
    } catch (e) {
      printX(e);
      CustomSnackBar.error(errorList: [MyStrings.somethingWentWrong]);
    }

    isLoadingJoinedRides = false;
    update();
  }

  /// Identify the active ride from joined rides list
  /// Active ride is identified by status == "1"
  /// Ride statuses: 0=pending, 1=active, 2=completed, 3=cancelled
  void _identifyActiveRideFromJoinedRides() {
    // Look for a ride with status "1" (active)
    JoinedRideModel? activeRide;
    for (var ride in joinedRides) {
      if (ride.status == "1") {
        activeRide = ride;
        printX('Found active ride (status=1) from my-rides: ID ${ride.id}');
        break;
      }
    }

    if (activeRide != null) {
      // Convert JoinedRideModel to AvailableRideModel for currentAvailableScheduledRide
      currentAvailableScheduledRide = _convertJoinedRideToAvailableRide(activeRide);
      printX('Set currentAvailableScheduledRide from my-rides API: ID ${currentAvailableScheduledRide!.id}');

      // Find and set user passenger info from the passengers list
      _extractUserPassengerInfo(activeRide);
    } else {
      // No active ride found, clear the current ride
      currentAvailableScheduledRide = null;
      userPassengerInfo = null;
      printX('No active ride (status=1) found in my-rides');
    }
  }

  /// Convert JoinedRideModel to AvailableRideModel
  AvailableRideModel _convertJoinedRideToAvailableRide(JoinedRideModel joinedRide) {
    return AvailableRideModel(
      id: joinedRide.id,
      driverId: joinedRide.driverId,
      serviceId: joinedRide.serviceId,
      pickupLocation: joinedRide.pickupLocation,
      pickupLatitude: joinedRide.pickupLatitude,
      pickupLongitude: joinedRide.pickupLongitude,
      destination: joinedRide.destination,
      destinationLatitude: joinedRide.destinationLatitude,
      destinationLongitude: joinedRide.destinationLongitude,
      scheduledDateTime: joinedRide.scheduledDateTime,
      numberOfPassengers: joinedRide.numberOfPassengers,
      availableSeats: joinedRide.availableSeats,
      note: joinedRide.note,
      estimatedFare: joinedRide.estimatedFare,
      distance: joinedRide.distance,
      duration: joinedRide.duration,
      isIntercity: joinedRide.isIntercity,
      status: joinedRide.status,
      statusText: joinedRide.statusText,
      cancelReason: joinedRide.cancelReason,
      createdAt: joinedRide.createdAt,
      updatedAt: joinedRide.updatedAt,
      driver: joinedRide.driver,
      service: joinedRide.service,
      passengers: joinedRide.passengers,
      canLeave: joinedRide.canLeave,
      driverCurrentLatitude: joinedRide.driverCurrentLatitude,
      driverCurrentLongitude: joinedRide.driverCurrentLongitude,
    );
  }

  /// Extract user passenger info from the active ride's passengers list
  void _extractUserPassengerInfo(JoinedRideModel activeRide) {
    // Get current user ID from SharedPreferences
    String? currentUserId = repo.apiClient.sharedPreferences.getString(SharedPreferenceHelper.userIdKey);
    printX('Current user ID: $currentUserId');

    if (activeRide.passengers != null && activeRide.passengers!.isNotEmpty) {
      printX('Checking ${activeRide.passengers!.length} passengers in active ride');

      // Look for current user in passengers list
      for (var passenger in activeRide.passengers!) {
        printX('Checking passenger - User ID: ${passenger.user?.id}, userId field: ${passenger.userId}, Status: ${passenger.status}');

        // Check both user.id and userId fields
        bool isCurrentUser = (passenger.user?.id == currentUserId) ||
                             (passenger.userId == currentUserId);

        if (isCurrentUser) {
          printX('FOUND CURRENT USER IN PASSENGERS LIST! Status: ${passenger.status}, PickupStatus: ${passenger.pickupStatus}');

          // Create a UserPassenger object from the passenger data
          userPassengerInfo = UserPassenger(
            id: passenger.id,
            status: passenger.status,
            seatsBooked: passenger.seatsBooked,
            farePerSeat: passenger.farePerSeat,
            pickupStatus: passenger.pickupStatus,
            pickupLocation: passenger.pickupLocation,
            pickupLatitude: passenger.pickupLatitude,
            pickupLongitude: passenger.pickupLongitude,
            totalFare: passenger.farePerSeat != null
                ? (double.tryParse(passenger.farePerSeat!) ?? 0).toString()
                : activeRide.estimatedFare,
          );
          printX('Created userPassengerInfo - Status: ${userPassengerInfo!.status}, PickupStatus: ${userPassengerInfo!.pickupStatus}');
          return;
        }
      }

      printX('Current user NOT found in passengers list');
    } else {
      printX('No passengers in active ride');
    }

    // If user not found in passengers, clear userPassengerInfo
    userPassengerInfo = null;
  }

  // Join a ride
  Future<void> joinRide(String rideId) async {
    if (!validateJoinForm()) return;

    isJoining = true;
    update();

    try {
      Map<String, dynamic> params = {
        'pickup_latitude': '$pickupLatitude',
        'pickup_longitude': '$pickupLongitude',
        'destination_latitude': '$destinationLatitude',
        'destination_longitude': '$destinationLongitude',
        'note': noteController.text,
      };

      ResponseModel responseModel = await repo.joinRide(rideId, params);
      if (responseModel.statusCode == 200) {
        JoinRideResponseModel model = JoinRideResponseModel.fromJson(
            jsonDecode(responseModel.responseJson));

        if (model.status == MyStrings.success) {
          CustomSnackBar.success(
              successList:
                  model.message ?? ['Request sent to driver for approval']);
          clearJoinForm();
          loadJoinedRides(refresh: true);
          Get.back(); // Close the join screen
        } else {
          CustomSnackBar.error(
              errorList: model.message ?? [MyStrings.somethingWentWrong]);
        }
      } else {
        CustomSnackBar.error(errorList: [responseModel.message]);
      }
    } catch (e) {
      printX(e);
      CustomSnackBar.error(errorList: [MyStrings.somethingWentWrong]);
    }

    isJoining = false;
    update();
  }

  // Make cash payment for scheduled ride (simple version)
  // Uses endpoint: POST scheduled-rides/{rideId}/cash-payment
  Future<void> makeCashPayment(String rideId, String passengerId, double amount) async {
    isProcessingCashPayment = true;
    update();

    try {
      Map<String, dynamic> params = {
        'passenger_id': passengerId,
        'amount_paid': amount.toString(),
      };

      ResponseModel responseModel = await repo.makeCashPayment(rideId, params);
      if (responseModel.statusCode == 200) {
        PassengerPaymentResponseModel model =
            PassengerPaymentResponseModel.fromJson(
                jsonDecode(responseModel.responseJson));

        if (model.status == MyStrings.success) {
          CustomSnackBar.success(
              successList: model.message ?? ['Payment completed successfully']);
          loadJoinedRides(refresh: true);
        } else {
          CustomSnackBar.error(
              errorList: model.message ?? [MyStrings.somethingWentWrong]);
        }
      } else {
        CustomSnackBar.error(errorList: [responseModel.message]);
      }
    } catch (e) {
      printX(e);
      CustomSnackBar.error(errorList: [MyStrings.somethingWentWrong]);
    }

    isProcessingCashPayment = false;
    update();
  }

  // Make cash payment for scheduled ride
  // Uses endpoint: POST scheduled-rides/{rideId}/cash-payment
  Future<void> makeScheduledRideCashPayment(
      String rideId, String passengerId, double amount, String? note) async {
    isProcessingCashPayment = true;
    update();

    try {
      // Log the parameters for debugging
      printX('Making scheduled ride cash payment:');
      printX('Ride ID: $rideId');
      printX('Passenger ID: $passengerId');
      printX('Amount: $amount');
      printX('Note: $note');

      // Use the correct scheduled ride cash payment endpoint
      Map<String, dynamic> params = {
        'passenger_id': passengerId,
        'amount_paid': amount.toString(),
      };

      // Add note if provided
      if (note != null && note.isNotEmpty) {
        params['note'] = note;
      }

      // Use makeCashPayment - correct endpoint for scheduled rides
      ResponseModel responseModel = await repo.makeCashPayment(rideId, params);
      printX('Payment API response code: ${responseModel.statusCode}');
      printX('Payment API response: ${responseModel.responseJson}');

      if (responseModel.statusCode == 200) {
        PassengerPaymentResponseModel model = PassengerPaymentResponseModel.fromJson(
            jsonDecode(responseModel.responseJson));

        if (model.status == MyStrings.success) {
          CustomSnackBar.success(
              successList:
                  model.message ?? ['Cash payment processed successfully']);
          loadJoinedRides(refresh: true);
          Get.back(); // Close payment screen after successful payment
        } else {
          // Log the actual error message from backend
          printX('Payment failed with message: ${model.message}');
          CustomSnackBar.error(
              errorList: model.message ?? [MyStrings.somethingWentWrong]);
        }
      } else {
        printX('Payment API error: ${responseModel.message}');
        CustomSnackBar.error(errorList: [responseModel.message]);
      }
    } catch (e) {
      printX('Payment exception: $e');
      CustomSnackBar.error(errorList: ['Payment failed: ${e.toString()}']);
    }

    isProcessingCashPayment = false;
    update();
  }

  // Create stripe checkout for scheduled ride
  Future<void> createScheduledRideStripeCheckout(
      String rideId, String passengerId, String returnUrl) async {
    isCreatingStripeCheckout = true;
    update();

    try {
      Map<String, dynamic> params = {
        'passenger_id': passengerId,
        'return_url': returnUrl,
      };

      ResponseModel responseModel =
          await repo.createStripeCheckout(rideId, params);
      if (responseModel.statusCode == 200) {
        StripeCheckoutResponseModel model =
            StripeCheckoutResponseModel.fromJson(
                jsonDecode(responseModel.responseJson));

        if (model.status == MyStrings.success) {
          // Open the checkout URL in browser or webview
          if (model.data?.checkoutUrl != null) {
            // TODO: Implement URL launcher or webview
            CustomSnackBar.success(
                successList: model.message ??
                    ['Stripe checkout session created successfully']);
            // You can use url_launcher package to open the URL
            // await launchUrl(Uri.parse(model.data!.checkoutUrl!));
          }
        } else {
          CustomSnackBar.error(
              errorList: model.message ?? [MyStrings.somethingWentWrong]);
        }
      } else {
        CustomSnackBar.error(errorList: [responseModel.message]);
      }
    } catch (e) {
      printX(e);
      CustomSnackBar.error(errorList: [MyStrings.somethingWentWrong]);
    }

    isCreatingStripeCheckout = false;
    update();
  }

  // Form validation for joining ride
  bool validateJoinForm() {
    if (pickupLatitude == null || pickupLongitude == null) {
      CustomSnackBar.error(errorList: ['Please select pickup location']);
      return false;
    }
    if (destinationLatitude == null || destinationLongitude == null) {
      CustomSnackBar.error(errorList: ['Please select destination']);
      return false;
    }
    return true;
  }

  // Clear join form
  void clearJoinForm() {
    noteController.clear();
    pickupLocationController.clear();
    destinationController.clear();
    pickupLatitude = null;
    pickupLongitude = null;
    destinationLatitude = null;
    destinationLongitude = null;
    seatsBooked = null;
    pickupLocationInfo = null;
    showLocationError = false;
    update();
  }

  // Fetch driver location from API for scheduled ride (fallback when Pusher fails)
  Future<Map<String, dynamic>?> fetchDriverLocationFromAPI(String scheduledRideId) async {
    try {
      printX('📍 Fetching driver location from API for scheduled ride: $scheduledRideId');

      String url = '${UrlContainer.baseUrl}${UrlContainer.scheduledRideLiveLocation}$scheduledRideId';
      printX('🔗 API URL: $url');

      ResponseModel response = await repo.apiClient.request(
        url,
        Method.getMethod,
        null,
        passHeader: true,
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> responseData = jsonDecode(response.responseJson);
        printX('✅ Driver location fetched from API: $responseData');

        // Expected response format:
        // {
        //   "status": "success",
        //   "data": {
        //     "latitude": "31.4653021",
        //     "longitude": "74.3072143",
        //     "speed": "0",
        //     "heading": "0",
        //     "accuracy": "10",
        //     "timestamp": "2024-01-01T12:00:00.000Z",
        //     "driver_id": "21"
        //   }
        // }

        if (responseData['status'] == 'success' && responseData['data'] != null) {
          return responseData['data'];
        }
      } else {
        printX('❌ Failed to fetch driver location from API: ${response.statusCode}');
        printX('❌ Response: ${response.responseJson}');
      }
    } catch (e) {
      printX('❌ Error fetching driver location from API: $e');
    }
    return null;
  }

  // Set pickup location from SelectedLocationInfo
  void setPickupLocation(SelectedLocationInfo location) {
    pickupLatitude = location.latitude;
    pickupLongitude = location.longitude;
    pickupLocationController.text = location.getFullAddress(showFull: true);
    update();
  }

  // Set destination location from SelectedLocationInfo
  void setDestinationLocation(SelectedLocationInfo location) {
    destinationLatitude = location.latitude;
    destinationLongitude = location.longitude;
    destinationController.text = location.getFullAddress(showFull: true);
    update();
  }

  // Set current location for pickup or destination
  Future<void> setCurrentLocation(bool isPickup) async {
    try {
      // Show loading indicator
      CustomSnackBar.success(successList: ['Getting your current location...']);

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        CustomSnackBar.error(errorList: [
          'Location services are disabled. Please enable location services.'
        ]);
        return;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          CustomSnackBar.error(errorList: [
            'Location permission denied. Please grant location permission.'
          ]);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
        CustomSnackBar.error(errorList: [
          'Location permission permanently denied. Please enable in app settings.'
        ]);
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      // Get address from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks[0];

        // Create location info from real GPS data
        var currentLocation = SelectedLocationInfo(
          latitude: position.latitude,
          longitude: position.longitude,
          placeName: 'Current Location',
          address: placemark.street ?? placemark.subThoroughfare ?? '',
          city: placemark.locality ?? placemark.administrativeArea ?? '',
          country: placemark.country ?? '',
          fullAddress:
              '${placemark.street ?? ''}, ${placemark.locality ?? ''}, ${placemark.administrativeArea ?? ''}, ${placemark.country ?? ''}'
                  .replaceAll(RegExp(r',\s*,+'), ',')
                  .replaceAll(RegExp(r'^,\s*|,\s*$'), ''),
        );

        // Set the location
        if (isPickup) {
          setPickupLocation(currentLocation);
        } else {
          setDestinationLocation(currentLocation);
        }

        // Show success message
        CustomSnackBar.success(successList: [
          'Current location set as ${isPickup ? 'pickup' : 'destination'}'
        ]);
      } else {
        CustomSnackBar.error(
            errorList: ['Unable to get address for current location.']);
      }
    } catch (e) {
      printX('Error getting current location: $e');
      CustomSnackBar.error(
          errorList: ['Failed to get current location. Please try again.']);
    }
  }

  // Search rides by destination
  List<AvailableRideModel> getFilteredRides() {
    if (searchQuery.isEmpty) {
      return availableRides;
    }
    return availableRides.where((ride) {
      return ride.destination
                  ?.toLowerCase()
                  .contains(searchQuery.toLowerCase()) ==
              true ||
          ride.pickupLocation
                  ?.toLowerCase()
                  .contains(searchQuery.toLowerCase()) ==
              true;
    }).toList();
  }

  // Filter joined rides by status
  List<JoinedRideModel> getFilteredJoinedRides() {
    if (selectedFilter == 'all') {
      return joinedRides;
    }
    return joinedRides.where((ride) {
      switch (selectedFilter) {
        case 'pending':
          return ride.passengerStatus == '0';
        case 'approved':
          return ride.passengerStatus == '1';
        case 'completed':
          return ride.passengerStatus == '2';
        default:
          return true;
      }
    }).toList();
  }

  // Get status color
  Color getStatusColor(String status) {
    switch (status) {
      case '0':
        return Colors.orange;
      case '1':
        return Colors.green;
      case '2':
        return Colors.blue;
      case '3':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Get status text
  String getStatusText(String status) {
    switch (status) {
      case '0':
        return 'Pending';
      case '1':
        return 'Approved';
      case '2':
        return 'Completed';
      case '3':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  // Get ride status color
  Color getRideStatusColor(String status) {
    switch (status) {
      case '1':
        return Colors.blue;
      case '2':
        return Colors.orange;
      case '3':
        return Colors.green;
      case '4':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Get ride status text
  String getRideStatusText(String status) {
    switch (status) {
      case '1':
        return 'Scheduled';
      case '2':
        return 'Started';
      case '3':
        return 'Active';
      case '4':
        return 'Completed';
      default:
        return 'Unknown';
    }
  }

  // Format date time
  String formatDateTime(String? dateTime) {
    if (dateTime == null) return 'Not specified';
    try {
      DateTime dt = DateTime.parse(dateTime);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTime;
    }
  }

  // Get available seats
  int getAvailableSeats(AvailableRideModel ride) {
    int totalSeats = int.tryParse(ride.numberOfPassengers ?? '0') ?? 0;
    int occupiedSeats = ride.passengers?.length ?? 0;
    return totalSeats - occupiedSeats;
  }

  // Check if ride is full
  bool isRideFull(AvailableRideModel ride) {
    return getAvailableSeats(ride) <= 0;
  }

  // Check if user has already joined this ride
  bool hasUserJoinedRide(String rideId) {
    return joinedRides.any((ride) => ride.id == rideId);
  }

  // Start scheduled ride
  Future<void> startScheduledRide(String rideId) async {
    try {
      ResponseModel responseModel = await repo.startScheduledRide(rideId);
      if (responseModel.statusCode == 200) {
        var jsonData = jsonDecode(responseModel.responseJson);

        if (jsonData['status'] == MyStrings.success) {
          CustomSnackBar.success(
              successList:
                  jsonData['message'] ?? ['Ride started successfully']);
          // Refresh rides data
          refreshAllRides();
        } else {
          CustomSnackBar.error(
              errorList: jsonData['message'] ?? [MyStrings.somethingWentWrong]);
        }
      } else {
        CustomSnackBar.error(errorList: [responseModel.message]);
      }
    } catch (e) {
      printX(e);
      CustomSnackBar.error(errorList: [MyStrings.somethingWentWrong]);
    }
  }
}
