import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovorideuser/core/utils/dimensions.dart';
import 'package:ovorideuser/core/utils/my_color.dart';
import 'package:ovorideuser/core/utils/style.dart';
import 'package:ovorideuser/core/utils/helper.dart';
import 'package:ovorideuser/core/helper/string_format_helper.dart';
import 'package:ovorideuser/data/controller/scheduled_ride/scheduled_ride_controller.dart';
import 'package:ovorideuser/data/controller/pusher/scheduled_ride_pusher_controller.dart';
import 'package:ovorideuser/data/model/scheduled_ride/scheduled_ride_model.dart';
import 'package:ovorideuser/data/services/api_service.dart';
import 'package:ovorideuser/presentation/components/buttons/rounded_button.dart';
import 'package:ovorideuser/presentation/components/divider/custom_spacer.dart';
import 'package:ovorideuser/presentation/components/snack_bar/show_custom_snackbar.dart';
import 'package:ovorideuser/presentation/screens/scheduled_rides/payment_bottom_sheet.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:ovorideuser/environment.dart';

class ActiveScheduledRideScreen extends StatefulWidget {
  final AvailableRideModel ride;
  final UserPassenger? userPassengerInfo;

  const ActiveScheduledRideScreen({
    super.key,
    required this.ride,
    this.userPassengerInfo,
  });

  @override
  State<ActiveScheduledRideScreen> createState() => _ActiveScheduledRideScreenState();
}

class _ActiveScheduledRideScreenState extends State<ActiveScheduledRideScreen> {
  // Map controller and markers
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  // Locations
  LatLng? _driverLocation;
  LatLng? _userLocation;
  LatLng? _passengerPickupLocation;  // Passenger's custom pickup location
  LatLng? _ridePickupLocation;       // Ride's original pickup location
  LatLng? _rideDestinationLocation;  // Ride's destination location

  // Timer for refreshing data
  Timer? _refreshTimer;

  // Icons
  BitmapDescriptor? _driverIcon;
  BitmapDescriptor? _userIcon;

  // Pusher controller for real-time tracking
  ScheduledRidePusherController? _pusherController;

  // Loading state
  bool _isLoadingRoute = false;
  bool _hasInitialRouteDrawn = false; // Track if initial route has been drawn

  @override
  void initState() {
    super.initState();
    _initializeLocations();
    _createCustomIcons();
    _startDataRefresh();
    _getCurrentLocation();
    _initializePusher();
    // Immediately fetch driver location on screen load
    _fetchDriverLocationImmediately();
  }

  void _fetchDriverLocationImmediately() async {
    // Fetch driver location from API immediately when screen loads
    if (widget.ride.id != null) {
      try {
        final controller = Get.find<ScheduledRideController>();
        Map<String, dynamic>? locationData = await controller.fetchDriverLocationFromAPI(widget.ride.id!);
        if (locationData != null) {
          double? lat = double.tryParse(locationData['driver_live_latitude']?.toString() ?? '');
          double? lng = double.tryParse(locationData['driver_live_longitude']?.toString() ?? '');

          if (lat != null && lng != null && lat != 0 && lng != 0) {
            setState(() {
              printX('📍 Initial driver location from API: Lat $lat, Lng $lng');
              _driverLocation = LatLng(lat, lng);
              _updateMapMarkers();
              _drawRoute();
            });
          }
        }
      } catch (e) {
        printX('Error fetching initial driver location: $e');
      }
    }
  }

  void _initializePusher() {
    // Initialize Pusher for real-time driver tracking
    try {
      _pusherController = Get.put(
        ScheduledRidePusherController(
          apiClient: Get.find<ApiClient>(),
        ),
        tag: 'scheduled_ride_${widget.ride.id}',
      );

      // Subscribe to Pusher channel for this scheduled ride
      _pusherController?.subscribePusher(
        rideId: widget.ride.id ?? '',
        onLocationUpdate: (LatLng driverLocation) {
          // Update driver location in real-time
          setState(() {
            printX('🚗 Real-time driver location update received in UI!');
            printX('📍 New Driver Location: Lat ${driverLocation.latitude}, Lng ${driverLocation.longitude}');
            _driverLocation = driverLocation;
            printX('🗺️ Updating map markers and route...');
            _updateMapMarkers();
            _drawRoute();

            // Animate map to show updated driver location with appropriate bounds
            if (_mapController != null) {
              _updateCameraBounds();
            }
          });
        },
      );

      printX('Pusher initialized for scheduled ride: ${widget.ride.id}');
    } catch (e) {
      printX('Failed to initialize Pusher: $e');
      // Continue with API polling as fallback
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _mapController?.dispose();

    // Clean up Pusher connection
    if (_pusherController != null) {
      _pusherController!.clearData();
      Get.delete<ScheduledRidePusherController>(
        tag: 'scheduled_ride_${widget.ride.id}',
      );
    }

    super.dispose();
  }

  void _initializeLocations() {
    // Set passenger's custom pickup location (from when they joined the ride)
    if (widget.userPassengerInfo?.pickupLatitude != null &&
        widget.userPassengerInfo?.pickupLongitude != null) {
      // Use passenger's specific pickup location
      _passengerPickupLocation = LatLng(
        double.parse(widget.userPassengerInfo!.pickupLatitude!),
        double.parse(widget.userPassengerInfo!.pickupLongitude!),
      );
      printX('Passenger pickup location: ${widget.userPassengerInfo!.pickupLocation}');
    }

    // Set ride's original pickup location
    if (widget.ride.pickupLatitude != null && widget.ride.pickupLongitude != null) {
      _ridePickupLocation = LatLng(
        double.parse(widget.ride.pickupLatitude!),
        double.parse(widget.ride.pickupLongitude!),
      );
    }

    // Set ride's destination location
    if (widget.ride.destinationLatitude != null && widget.ride.destinationLongitude != null) {
      _rideDestinationLocation = LatLng(
        double.parse(widget.ride.destinationLatitude!),
        double.parse(widget.ride.destinationLongitude!),
      );
    }

    // Set driver's current location from API if available
    if (widget.ride.driverCurrentLatitude != null &&
        widget.ride.driverCurrentLongitude != null) {
      // Use actual driver location from API
      _driverLocation = LatLng(
        double.parse(widget.ride.driverCurrentLatitude!),
        double.parse(widget.ride.driverCurrentLongitude!),
      );
      printX('Using driver live location from API: $_driverLocation');
    } else {
      // Don't set dummy location - wait for real location from Pusher
      printX('WARNING: Driver location not provided by API, waiting for Pusher updates');
      // Driver location will be set when we receive it from Pusher
    }

    _updateMapMarkers();
    _drawRoute();
  }

  void _createCustomIcons() async {
    // Load custom marker icons
    try {
      // Load car icon for driver
      final Uint8List? carIconBytes = await Helper.getBytesFromAsset(
        'assets/img/map/ic_marker_car.png',
        100, // Size of the icon
      );
      if (carIconBytes != null) {
        _driverIcon = BitmapDescriptor.fromBytes(carIconBytes);
      }

      // Load custom marker for passenger pickup location
      final Uint8List? pickupIconBytes = await Helper.getBytesFromAsset(
        'assets/icon/ic_marker_rides_stoppage.png',
        100, // Size of the icon
      );
      if (pickupIconBytes != null) {
        _userIcon = BitmapDescriptor.fromBytes(pickupIconBytes);
      }

      _updateMapMarkers();
    } catch (e) {
      printX('Error loading custom marker icons: $e');
      // Fallback to default markers if custom icons fail to load
      _driverIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      _userIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      _updateMapMarkers();
    }
  }

  void _updateMapMarkers() {
    setState(() {
      _markers.clear();

      bool isPickedUp = widget.userPassengerInfo?.isPickedUp ?? false;

      // Add driver marker (car icon) - always show if location available
      if (_driverLocation != null) {
        _markers.add(
          Marker(
            markerId: const MarkerId('driver'),
            position: _driverLocation!,
            icon: _driverIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            infoWindow: InfoWindow(
              title: 'Driver: ${widget.ride.driver?.firstname ?? 'Unknown'}',
              snippet: widget.ride.service?.name ?? '',
            ),
          ),
        );
      }

      // Only show pickup markers if passenger hasn't been picked up yet
      if (!isPickedUp) {
        // Add passenger's pickup marker (most important - custom marker icon)
        if (_passengerPickupLocation != null) {
          _markers.add(
            Marker(
              markerId: const MarkerId('passenger_pickup'),
              position: _passengerPickupLocation!,
              icon: _userIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              infoWindow: InfoWindow(
                title: 'Your Pickup Location',
                snippet: widget.userPassengerInfo?.pickupLocation ?? '',
              ),
            ),
          );
        }

        // Add ride's original pickup marker (orange/yellow)
        if (_ridePickupLocation != null) {
          _markers.add(
            Marker(
              markerId: const MarkerId('ride_pickup'),
              position: _ridePickupLocation!,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
              infoWindow: InfoWindow(
                title: 'Ride Start Point',
                snippet: widget.ride.pickupLocation ?? '',
              ),
            ),
          );
        }
      }

      // Always show destination marker
      if (_rideDestinationLocation != null) {
        _markers.add(
          Marker(
            markerId: const MarkerId('ride_destination'),
            position: _rideDestinationLocation!,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(
              title: 'Ride Destination',
              snippet: widget.ride.destination ?? '',
            ),
          ),
        );
      }
    });
  }

  void _drawRoute() async {
    // Only show loading indicator on initial route draw
    if (!_hasInitialRouteDrawn) {
      setState(() {
        _isLoadingRoute = true;
      });
    }

    // Determine navigation based on pickup status
    bool isPickedUp = widget.userPassengerInfo?.isPickedUp ?? false;

    // CASE 1: Passenger has been picked up - show navigation from driver to destination
    if (isPickedUp) {
      if (_driverLocation == null || _rideDestinationLocation == null) {
        if (!_hasInitialRouteDrawn) {
          setState(() {
            _isLoadingRoute = false;
          });
        }
        return;
      }
      
      try {
        PolylinePoints polylinePoints = PolylinePoints();
        
        // Get route from driver to destination
        PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
          request: PolylineRequest(
            origin: PointLatLng(_driverLocation!.latitude, _driverLocation!.longitude),
            destination: PointLatLng(_rideDestinationLocation!.latitude, _rideDestinationLocation!.longitude),
            mode: TravelMode.driving,
          ),
          googleApiKey: Environment.mapKey,
        );

        List<LatLng> polylineCoordinates = [];
        
        if (result.points.isNotEmpty) {
          for (var point in result.points) {
            polylineCoordinates.add(LatLng(point.latitude, point.longitude));
          }
          
          setState(() {
            _polylines.clear();
            _polylines.add(
              Polyline(
                polylineId: const PolylineId('driver_to_destination'),
                color: MyColor.primaryColor,
                width: 5,
                points: polylineCoordinates,
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
                jointType: JointType.round,
              ),
            );
            _isLoadingRoute = false;
            _hasInitialRouteDrawn = true; // Mark initial route as drawn
          });
          
          printX('✅ Route drawn (picked up): Driver → Destination with ${polylineCoordinates.length} points');
        } else {
          printX('⚠️ No route points returned from API: ${result.errorMessage}');
          _drawFallbackRoutePickedUp();
          if (!_hasInitialRouteDrawn) {
            setState(() {
              _isLoadingRoute = false;
              _hasInitialRouteDrawn = true;
            });
          }
        }
      } catch (e) {
        printX('❌ Error drawing route (picked up): $e');
        _drawFallbackRoutePickedUp();
        if (!_hasInitialRouteDrawn) {
          setState(() {
            _isLoadingRoute = false;
            _hasInitialRouteDrawn = true;
          });
        }
      }
      return;
    }

    // CASE 2: Driver location not available - show navigation from passenger pickup to destination
    if (_driverLocation == null) {
      if (_passengerPickupLocation == null || _rideDestinationLocation == null) {
        if (!_hasInitialRouteDrawn) {
          setState(() {
            _isLoadingRoute = false;
          });
        }
        return;
      }
      
      try {
        PolylinePoints polylinePoints = PolylinePoints();
        
        // Get route from passenger pickup to destination
        PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
          request: PolylineRequest(
            origin: PointLatLng(_passengerPickupLocation!.latitude, _passengerPickupLocation!.longitude),
            destination: PointLatLng(_rideDestinationLocation!.latitude, _rideDestinationLocation!.longitude),
            mode: TravelMode.driving,
          ),
          googleApiKey: Environment.mapKey,
        );

        List<LatLng> polylineCoordinates = [];
        
        if (result.points.isNotEmpty) {
          for (var point in result.points) {
            polylineCoordinates.add(LatLng(point.latitude, point.longitude));
          }
          
          setState(() {
            _polylines.clear();
            _polylines.add(
              Polyline(
                polylineId: const PolylineId('pickup_to_destination'),
                color: Colors.blue, // Different color for pickup to destination
                width: 5,
                points: polylineCoordinates,
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
                jointType: JointType.round,
              ),
            );
            _isLoadingRoute = false;
            _hasInitialRouteDrawn = true; // Mark initial route as drawn
          });
          
          printX('✅ Route drawn (no driver): Pickup → Destination with ${polylineCoordinates.length} points');
        } else {
          printX('⚠️ No route points returned from API: ${result.errorMessage}');
          _drawFallbackRouteNoDriver();
          if (!_hasInitialRouteDrawn) {
            setState(() {
              _isLoadingRoute = false;
              _hasInitialRouteDrawn = true;
            });
          }
        }
      } catch (e) {
        printX('❌ Error drawing route (no driver): $e');
        _drawFallbackRouteNoDriver();
        if (!_hasInitialRouteDrawn) {
          setState(() {
            _isLoadingRoute = false;
            _hasInitialRouteDrawn = true;
          });
        }
      }
      return;
    }

    // CASE 3: Normal case - passenger not picked up yet, show driver to passenger pickup
    if (_passengerPickupLocation == null) {
      if (!_hasInitialRouteDrawn) {
        setState(() {
          _isLoadingRoute = false;
        });
      }
      return;
    }

    try {
      PolylinePoints polylinePoints = PolylinePoints();
      
      // Get route from driver to passenger pickup location
      PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        request: PolylineRequest(
          origin: PointLatLng(_driverLocation!.latitude, _driverLocation!.longitude),
          destination: PointLatLng(_passengerPickupLocation!.latitude, _passengerPickupLocation!.longitude),
          mode: TravelMode.driving,
        ),
        googleApiKey: Environment.mapKey,
      );

      List<LatLng> polylineCoordinates = [];
      
      if (result.points.isNotEmpty) {
        for (var point in result.points) {
          polylineCoordinates.add(LatLng(point.latitude, point.longitude));
        }
        
        setState(() {
          _polylines.clear();

          // Main route: Driver to Passenger's pickup location with proper navigation path
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('driver_to_passenger_pickup'),
              color: MyColor.primaryColor,
              width: 5,
              points: polylineCoordinates,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
              jointType: JointType.round,
            ),
          );
        });
        
        printX('✅ Route drawn (waiting): Driver → Pickup with ${polylineCoordinates.length} points');
        
        // Show navigation route from passenger pickup to destination
        if (_rideDestinationLocation != null) {
          await _drawRouteToDestination();
        } else {
          if (!_hasInitialRouteDrawn) {
            setState(() {
              _isLoadingRoute = false;
              _hasInitialRouteDrawn = true;
            });
          }
        }
      } else {
        printX('⚠️ No route points returned from API: ${result.errorMessage}');
        _drawFallbackRoute();
        if (!_hasInitialRouteDrawn) {
          setState(() {
            _isLoadingRoute = false;
            _hasInitialRouteDrawn = true;
          });
        }
      }
    } catch (e) {
      printX('❌ Error drawing route (waiting): $e');
      _drawFallbackRoute();
      if (!_hasInitialRouteDrawn) {
        setState(() {
          _isLoadingRoute = false;
          _hasInitialRouteDrawn = true;
        });
      }
    }
  }

  // Helper method to draw route from pickup to destination
  Future<void> _drawRouteToDestination() async {
    if (_passengerPickupLocation == null || _rideDestinationLocation == null) {
      if (!_hasInitialRouteDrawn) {
        setState(() {
          _isLoadingRoute = false;
        });
      }
      return;
    }

    try {
      PolylinePoints polylinePoints = PolylinePoints();
      
      PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        request: PolylineRequest(
          origin: PointLatLng(_passengerPickupLocation!.latitude, _passengerPickupLocation!.longitude),
          destination: PointLatLng(_rideDestinationLocation!.latitude, _rideDestinationLocation!.longitude),
          mode: TravelMode.driving,
        ),
        googleApiKey: Environment.mapKey,
      );

      if (result.points.isNotEmpty) {
        List<LatLng> destinationPolylineCoordinates = [];
        for (var point in result.points) {
          destinationPolylineCoordinates.add(LatLng(point.latitude, point.longitude));
        }

        setState(() {
          // Add the pickup to destination route with solid line and different color
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('pickup_to_destination'),
              color: Colors.blue, // Different color - solid blue
              width: 4,
              points: destinationPolylineCoordinates,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
              jointType: JointType.round,
            ),
          );
          if (!_hasInitialRouteDrawn) {
            _isLoadingRoute = false;
            _hasInitialRouteDrawn = true;
          }
        });
        printX('✅ Route drawn: Pickup → Destination with ${destinationPolylineCoordinates.length} points');
      } else {
        if (!_hasInitialRouteDrawn) {
          setState(() {
            _isLoadingRoute = false;
            _hasInitialRouteDrawn = true;
          });
        }
      }
    } catch (e) {
      printX('❌ Error drawing route to destination: $e');
      if (!_hasInitialRouteDrawn) {
        setState(() {
          _isLoadingRoute = false;
          _hasInitialRouteDrawn = true;
        });
      }
    }
  }

  // Fallback method to draw a simple straight line if API fails (waiting for pickup)
  void _drawFallbackRoute() {
    if (_driverLocation == null || _passengerPickupLocation == null) return;
    
    setState(() {
      _polylines.clear();

      // Simple straight line as fallback
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('driver_to_passenger_pickup'),
          color: MyColor.primaryColor,
          width: 5,
          points: [_driverLocation!, _passengerPickupLocation!],
        ),
      );

      // Show route from passenger pickup to ride destination (solid line)
      if (_rideDestinationLocation != null) {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('pickup_to_destination'),
            color: Colors.blue, // Different color - solid blue
            width: 4,
            points: [_passengerPickupLocation!, _rideDestinationLocation!],
          ),
        );
      }
      if (!_hasInitialRouteDrawn) {
        _isLoadingRoute = false;
        _hasInitialRouteDrawn = true;
      }
    });
  }

  // Fallback for when passenger is picked up
  void _drawFallbackRoutePickedUp() {
    if (_driverLocation == null || _rideDestinationLocation == null) return;
    
    setState(() {
      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('driver_to_destination'),
          color: MyColor.primaryColor,
          width: 5,
          points: [_driverLocation!, _rideDestinationLocation!],
        ),
      );
      if (!_hasInitialRouteDrawn) {
        _isLoadingRoute = false;
        _hasInitialRouteDrawn = true;
      }
    });
  }

  // Fallback for when driver location is not available
  void _drawFallbackRouteNoDriver() {
    if (_passengerPickupLocation == null || _rideDestinationLocation == null) return;
    
    setState(() {
      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('pickup_to_destination'),
          color: Colors.blue, // Different color for pickup to destination
          width: 5,
          points: [_passengerPickupLocation!, _rideDestinationLocation!],
        ),
      );
      if (!_hasInitialRouteDrawn) {
        _isLoadingRoute = false;
        _hasInitialRouteDrawn = true;
      }
    });
  }

  void _startDataRefresh() {
    // Refresh data every 10 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _refreshRideData();
    });
  }

  void _refreshRideData() async {
    // Refresh ride data and driver location silently (no error popups)
    final controller = Get.find<ScheduledRideController>();
    await controller.refreshCurrentTabSilently();

    // Also try to fetch driver location from API as a fallback
    if (widget.ride.id != null) {
      Map<String, dynamic>? locationData = await controller.fetchDriverLocationFromAPI(widget.ride.id!);
      if (locationData != null) {
        // API returns driver_live_latitude and driver_live_longitude
        double? lat = double.tryParse(locationData['driver_live_latitude']?.toString() ?? '');
        double? lng = double.tryParse(locationData['driver_live_longitude']?.toString() ?? '');

        if (lat != null && lng != null && lat != 0 && lng != 0) {
          setState(() {
            printX('📍 API Fallback: Driver location updated from API');
            printX('📍 Driver coordinates: Lat $lat, Lng $lng');
            _driverLocation = LatLng(lat, lng);
            _updateMapMarkers();
            _drawRoute();

            // Update camera to show appropriate bounds based on ride state
            if (_mapController != null) {
              _updateCameraBounds();
            }
          });
        }
      }
    }

    // Check for updated driver location based on tab
    AvailableRideModel? updatedRide;

    if (controller.selectedTab == 'available' && controller.currentAvailableScheduledRide != null) {
      updatedRide = controller.currentAvailableScheduledRide;
    } else if (controller.selectedTab == 'joined') {
      // For joined rides, find the specific ride in the list
      final joinedRide = controller.joinedRides.firstWhereOrNull(
        (ride) => ride.id == widget.ride.id,
      );

      if (joinedRide != null) {
        // Convert JoinedRideModel to AvailableRideModel for compatibility
        // Both models should have driver location fields
        updatedRide = AvailableRideModel(
          id: joinedRide.id,
          driverCurrentLatitude: joinedRide.driverCurrentLatitude,
          driverCurrentLongitude: joinedRide.driverCurrentLongitude,
        );
      }
    }

    // Update driver's location if available
    if (updatedRide != null &&
        updatedRide.driverCurrentLatitude != null &&
        updatedRide.driverCurrentLongitude != null) {
      setState(() {
        _driverLocation = LatLng(
          double.parse(updatedRide!.driverCurrentLatitude!),
          double.parse(updatedRide.driverCurrentLongitude!),
        );
        printX('Updated driver location from API refresh: $_driverLocation');
        _updateMapMarkers();
        _drawRoute();
      });
    } else {
      printX('No driver location available from API refresh - relying on Pusher');
    }
  }

  void _getCurrentLocation() async {
    // We don't need to show user's current location marker
    // Just get location for map services if needed
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Don't show error, just continue without location services
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // Store user location but don't add marker
      _userLocation = LatLng(position.latitude, position.longitude);

      // Center map based on current ride state
      if (_mapController != null) {
        _updateCameraBounds();
      }
    } catch (e) {
      // Silently handle error
    }
  }

  // Helper method to update camera bounds based on ride state
  void _updateCameraBounds() {
    if (_mapController == null) return;

    bool isPickedUp = widget.userPassengerInfo?.isPickedUp ?? false;

    try {
      if (isPickedUp) {
        // After pickup: Show driver and destination
        if (_driverLocation != null && _rideDestinationLocation != null) {
          LatLngBounds bounds = LatLngBounds(
            southwest: LatLng(
              _driverLocation!.latitude < _rideDestinationLocation!.latitude 
                  ? _driverLocation!.latitude 
                  : _rideDestinationLocation!.latitude,
              _driverLocation!.longitude < _rideDestinationLocation!.longitude 
                  ? _driverLocation!.longitude 
                  : _rideDestinationLocation!.longitude,
            ),
            northeast: LatLng(
              _driverLocation!.latitude > _rideDestinationLocation!.latitude 
                  ? _driverLocation!.latitude 
                  : _rideDestinationLocation!.latitude,
              _driverLocation!.longitude > _rideDestinationLocation!.longitude 
                  ? _driverLocation!.longitude 
                  : _rideDestinationLocation!.longitude,
            ),
          );
          _mapController!.animateCamera(
            CameraUpdate.newLatLngBounds(bounds, 100),
          );
        }
      } else if (_driverLocation != null && _passengerPickupLocation != null) {
        // Before pickup: Show driver and passenger pickup
        LatLngBounds bounds = LatLngBounds(
          southwest: LatLng(
            _driverLocation!.latitude < _passengerPickupLocation!.latitude 
                ? _driverLocation!.latitude 
                : _passengerPickupLocation!.latitude,
            _driverLocation!.longitude < _passengerPickupLocation!.longitude 
                ? _driverLocation!.longitude 
                : _passengerPickupLocation!.longitude,
          ),
          northeast: LatLng(
            _driverLocation!.latitude > _passengerPickupLocation!.latitude 
                ? _driverLocation!.latitude 
                : _passengerPickupLocation!.latitude,
            _driverLocation!.longitude > _passengerPickupLocation!.longitude 
                ? _driverLocation!.longitude 
                : _passengerPickupLocation!.longitude,
          ),
        );
        _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 100),
        );
      } else if (_passengerPickupLocation != null && _rideDestinationLocation != null) {
        // No driver location: Show pickup and destination
        LatLngBounds bounds = LatLngBounds(
          southwest: LatLng(
            _passengerPickupLocation!.latitude < _rideDestinationLocation!.latitude 
                ? _passengerPickupLocation!.latitude 
                : _rideDestinationLocation!.latitude,
            _passengerPickupLocation!.longitude < _rideDestinationLocation!.longitude 
                ? _passengerPickupLocation!.longitude 
                : _rideDestinationLocation!.longitude,
          ),
          northeast: LatLng(
            _passengerPickupLocation!.latitude > _rideDestinationLocation!.latitude 
                ? _passengerPickupLocation!.latitude 
                : _rideDestinationLocation!.latitude,
            _passengerPickupLocation!.longitude > _rideDestinationLocation!.longitude 
                ? _passengerPickupLocation!.longitude 
                : _rideDestinationLocation!.longitude,
          ),
        );
        _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 100),
        );
      }
    } catch (e) {
      printX('Error updating camera bounds: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GetBuilder<ScheduledRideController>(
        builder: (controller) {
          return Stack(
            children: [
              // Full Screen Map
              GoogleMap(
                onMapCreated: (mapController) {
                  _mapController = mapController;
                  // Center map based on current ride state
                  _updateCameraBounds();
                },
                initialCameraPosition: CameraPosition(
                  target: _passengerPickupLocation ?? _ridePickupLocation ?? const LatLng(0, 0),
                  zoom: 14,
                ),
                markers: _markers,
                polylines: _polylines,
                myLocationEnabled: false, // Don't show user's current location
                myLocationButtonEnabled: false,
                zoomControlsEnabled: true,
                mapToolbarEnabled: false,
                padding: EdgeInsets.only(
                  top: 60, // Only space for the floating header
                  bottom: MediaQuery.of(context).size.height * 0.2, // Space for bottom sheet minimum
                ),
              ),

              // Top Header with Driver Info and Back Button
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 8,
                    right: 8,
                    bottom: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.3),
                        Colors.black.withValues(alpha: 0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      // Back Button
                      IconButton(
                        onPressed: () => Get.back(),
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_back,
                            color: Colors.black,
                          ),
                        ),
                      ),

                      // Driver Info Card
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: MyColor.primaryColor.withValues(alpha: 0.1),
                                child: Icon(
                                  Icons.person,
                                  color: MyColor.primaryColor,
                                  size: 20,
                                ),
                              ),
                              spaceSide(10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Driver: ${widget.ride.driver?.firstname ?? 'Unknown'}',
                                      style: boldDefault.copyWith(
                                        fontSize: Dimensions.fontDefault,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      widget.ride.service?.name ?? 'Vehicle',
                                      style: regularSmall.copyWith(
                                        color: Colors.grey[600],
                                        fontSize: Dimensions.fontExtraSmall,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Draggable Bottom Sheet
              DraggableScrollableSheet(
                initialChildSize: 0.2, // 20% of screen
                minChildSize: 0.2, // Minimum 20%
                maxChildSize: 0.7, // Maximum 70%
                snapSizes: const [0.2, 0.4, 0.7], // Snap points
                snap: true,
                builder: (BuildContext context, ScrollController scrollController) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Handle bar
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),

                        // Scrollable Content
                        Expanded(
                          child: SingleChildScrollView(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Ride Status
                                _buildStatusRow(),
                                spaceDown(16),

                                // Location Details
                                _buildLocationDetails(),
                                spaceDown(16),

                                // Fare Details
                                _buildFareDetails(),
                                spaceDown(20),

                                // Action Buttons
                                _buildActionButtons(controller),
                                spaceDown(16),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Loading Indicator Overlay
              if (_isLoadingRoute)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.3),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(MyColor.primaryColor),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Loading route...',
                              style: boldDefault.copyWith(
                                color: MyColor.colorBlack,
                                fontSize: Dimensions.fontDefault,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusRow() {
    String statusText = 'Unknown';
    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.info;

    if (widget.userPassengerInfo != null) {
      if (widget.userPassengerInfo!.pickupStatus != null) {
        statusText = 'Picked Up';
        statusColor = Colors.blue;
        statusIcon = Icons.directions_car;
      } else if (widget.userPassengerInfo!.isActivePassenger) {
        // Use isActivePassenger to check for status 1 (approved), 4, or 5 (in_progress/on_way)
        statusText = 'Waiting for Pickup';
        statusColor = Colors.orange;
        statusIcon = Icons.access_time;
      } else if (widget.userPassengerInfo!.isPending) {
        statusText = 'Pending Approval';
        statusColor = Colors.yellow[700]!;
        statusIcon = Icons.hourglass_empty;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withValues(alpha:0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, color: statusColor, size: 20),
          spaceSide(8),
          Text(
            statusText,
            style: boldDefault.copyWith(
              color: statusColor,
              fontSize: Dimensions.fontDefault,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationDetails() {
    return Column(
      children: [
        _buildLocationRow(
          Icons.location_on,
          'Pickup',
          widget.userPassengerInfo?.pickupLocation ?? widget.ride.pickupLocation ?? 'Not specified',
          Colors.green,
        ),
        spaceDown(12),
        _buildLocationRow(
          Icons.location_on_outlined,
          'Destination',
          widget.ride.destination ?? 'Not specified',
          Colors.red,
        ),
      ],
    );
  }

  Widget _buildLocationRow(IconData icon, String label, String address, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha:0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        spaceSide(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: regularSmall.copyWith(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              spaceDown(4),
              Text(
                address,
                style: regularDefault.copyWith(
                  color: MyColor.colorBlack,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFareDetails() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MyColor.primaryColor.withValues(alpha:0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MyColor.primaryColor.withValues(alpha:0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Fare',
                style: regularSmall.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              spaceDown(4),
              Text(
                '\$${widget.userPassengerInfo?.totalFare ?? widget.ride.estimatedFare ?? '0'}',
                style: boldLarge.copyWith(
                  color: MyColor.primaryColor,
                  fontSize: Dimensions.fontOverLarge,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Distance',
                style: regularSmall.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              spaceDown(4),
              Text(
                '${widget.ride.distance ?? '0'} km',
                style: boldDefault.copyWith(
                  color: MyColor.colorBlack,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ScheduledRideController controller) {
    // Check user's status
    if (widget.userPassengerInfo == null) {
      return const Center(
        child: Text('No passenger information available'),
      );
    }

    if (widget.userPassengerInfo!.isPending) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.yellow[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.yellow[700]!.withValues(alpha:0.3)),
        ),
        child: Column(
          children: [
            Icon(
              Icons.hourglass_empty,
              color: Colors.yellow[700],
              size: 40,
            ),
            spaceDown(8),
            Text(
              'Waiting for Driver Approval',
              style: boldDefault.copyWith(
                color: Colors.yellow[700],
                fontSize: Dimensions.fontLarge,
              ),
            ),
            spaceDown(4),
            Text(
              'The driver will review and approve your request shortly',
              style: regularDefault.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Use isActivePassenger to check for status 1 (approved), 4, or 5 (in_progress/on_way)
    if (widget.userPassengerInfo!.isActivePassenger) {
      // Check if already picked up
      if (widget.userPassengerInfo!.isPickedUp) {
        // Check if ride is completed (payment made)
        if (widget.userPassengerInfo!.isCompleted) {
          // Show ride completed status
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: Colors.green,
                  size: 60,
                ),
                spaceDown(12),
                Text(
                  'Ride Completed',
                  style: boldLarge.copyWith(
                    color: Colors.green,
                    fontSize: Dimensions.fontLarge,
                  ),
                ),
                spaceDown(8),
                Text(
                  'Thank you for your payment!',
                  style: regularDefault.copyWith(
                    color: Colors.grey[700],
                  ),
                  textAlign: TextAlign.center,
                ),
                spaceDown(4),
                Text(
                  'Your ride has been completed successfully.',
                  style: regularSmall.copyWith(
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        // Show payment button if not completed
        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withValues(alpha:0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 24),
                  spaceSide(12),
                  Text(
                    'You have been picked up',
                    style: boldDefault.copyWith(
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            spaceDown(16),
            controller.isProcessingCashPayment
                ? Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: MyColor.primaryColor.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(Dimensions.defaultRadius),
                    ),
                    child: const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Processing Payment...',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : RoundedButton(
                    text: 'Make Cash Payment',
                    press: () {
                      showPaymentBottomSheet(
                        context,
                        controller,
                        widget.userPassengerInfo,
                        widget.ride.id,
                      );
                    },
                    color: MyColor.primaryColor,
                  ),
          ],
        );
      } else {
        // Show update pickup status button
        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha:0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue, size: 24),
                      spaceSide(12),
                      Expanded(
                        child: Text(
                          'Driver is on the way to pick you up',
                          style: regularDefault.copyWith(
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  spaceDown(8),
                  Text(
                    'Click the button below when the driver arrives and picks you up',
                    style: regularSmall.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            spaceDown(16),
            RoundedButton(
              text: 'I\'ve Been Picked Up',
              press: () {
                _updatePickupStatus(controller);
              },
              color: Colors.green,
            ),
          ],
        );
      }
    }

    return const SizedBox.shrink();
  }

  void _updatePickupStatus(ScheduledRideController controller) {
    // TODO: Implement API call to update pickup status
    Get.dialog(
      AlertDialog(
        title: const Text('Confirm Pickup'),
        content: const Text('Please confirm that the driver has picked you up.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              // Update pickup status
              CustomSnackBar.success(
                successList: ['Pickup status updated successfully'],
              );
              // Refresh the screen
              setState(() {
                widget.userPassengerInfo?.pickupStatus = 'picked_up';
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: MyColor.primaryColor,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog(ScheduledRideController controller) {
    Get.dialog(
      AlertDialog(
        title: const Text('Cash Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total Amount:',
              style: regularDefault.copyWith(
                color: Colors.grey[600],
              ),
            ),
            spaceDown(8),
            Text(
              '\$${widget.userPassengerInfo?.totalFare ?? '0'}',
              style: boldLarge.copyWith(
                color: MyColor.primaryColor,
                fontSize: Dimensions.fontOverLarge,
              ),
            ),
            spaceDown(16),
            const Text(
              'Please confirm that you have paid the driver in cash.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              // Process payment using scheduled ride cash payment API
              if (widget.userPassengerInfo?.id != null && widget.ride.id != null) {
                // Parse the total fare as double
                double amount = double.tryParse(widget.userPassengerInfo?.totalFare ?? '0') ?? 0;
                controller.makeScheduledRideCashPayment(
                  widget.ride.id!,
                  widget.userPassengerInfo!.id!,
                  amount,
                  null, // No note for simple payment dialog
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: MyColor.primaryColor,
            ),
            child: const Text('Confirm Payment'),
          ),
        ],
      ),
    );
  }
}