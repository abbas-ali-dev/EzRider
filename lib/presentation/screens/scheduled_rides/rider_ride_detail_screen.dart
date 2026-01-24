// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovorideuser/core/utils/dimensions.dart';
import 'package:ovorideuser/core/utils/my_color.dart';
import 'package:ovorideuser/core/utils/style.dart';
import 'package:ovorideuser/data/controller/scheduled_ride/scheduled_ride_controller.dart';
import 'package:ovorideuser/data/model/scheduled_ride/scheduled_ride_model.dart';
import 'package:ovorideuser/data/services/api_service.dart';
import 'package:ovorideuser/presentation/components/app-bar/custom_appbar.dart';
import 'package:ovorideuser/presentation/components/divider/custom_spacer.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

class RiderRideDetailScreen extends StatefulWidget {
  final JoinedRideModel ride;

  const RiderRideDetailScreen({
    super.key,
    required this.ride,
  });

  @override
  State<RiderRideDetailScreen> createState() => _RiderRideDetailScreenState();
}

class _RiderRideDetailScreenState extends State<RiderRideDetailScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Map related variables
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  LatLng? _riderLocation;
  LatLng? _driverLocation;
  LatLng? _pickupLocation;
  LatLng? _destinationLocation;
  BitmapDescriptor? _carIcon;
  BitmapDescriptor? _riderIcon;

  // Pusher variables
  final PusherChannelsFlutter _pusher = PusherChannelsFlutter.getInstance();
  String? _userId;
  String? _currentPickupStatus;
  Timer? _startRideTimer;
  final int _timerCountdown = 30;
  final bool _canStartRide = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();

    // Initialize map data
    _initializeMapData();

    // Create custom icons
    _createCustomIcons();

    // Initialize Pusher
    _initializePusher();

    // Get current location
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pusher.disconnect();
    _startRideTimer?.cancel();
    super.dispose();
  }

  // Initialize map data
  void _initializeMapData() {
    // Set pickup location
    if (widget.ride.pickupLatitude != null &&
        widget.ride.pickupLongitude != null) {
      _pickupLocation = LatLng(
        double.parse(widget.ride.pickupLatitude!),
        double.parse(widget.ride.pickupLongitude!),
      );
    }

    // Set destination location
    if (widget.ride.destinationLatitude != null &&
        widget.ride.destinationLongitude != null) {
      _destinationLocation = LatLng(
        double.parse(widget.ride.destinationLatitude!),
        double.parse(widget.ride.destinationLongitude!),
      );
    }

    _updateMarkers();
  }

  // Create custom icons
  Future<void> _createCustomIcons() async {
    try {
      // Create car icon
      final ui.PictureRecorder carRecorder = ui.PictureRecorder();
      final Canvas carCanvas = Canvas(carRecorder);

      const double size = 60.0;

      // Draw car icon
      final Paint carPaint = Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.fill;

      final Paint strokePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;

      // Draw car body
      final RRect carBody = RRect.fromRectAndRadius(
        Rect.fromLTWH(size * 0.1, size * 0.3, size * 0.8, size * 0.4),
        const Radius.circular(8),
      );
      carCanvas.drawRRect(carBody, carPaint);
      carCanvas.drawRRect(carBody, strokePaint);

      // Draw car roof
      final RRect carRoof = RRect.fromRectAndRadius(
        Rect.fromLTWH(size * 0.2, size * 0.15, size * 0.6, size * 0.25),
        const Radius.circular(6),
      );
      carCanvas.drawRRect(carRoof, carPaint);
      carCanvas.drawRRect(carRoof, strokePaint);

      // Draw wheels
      carCanvas.drawCircle(
        Offset(size * 0.25, size * 0.75),
        size * 0.08,
        Paint()..color = Colors.black,
      );
      carCanvas.drawCircle(
        Offset(size * 0.75, size * 0.75),
        size * 0.08,
        Paint()..color = Colors.black,
      );

      // Convert to image
      final ui.Picture carPicture = carRecorder.endRecording();
      final ui.Image carImage =
          await carPicture.toImage(size.toInt(), size.toInt());
      final ByteData? carByteData =
          await carImage.toByteData(format: ui.ImageByteFormat.png);

      if (carByteData != null) {
        _carIcon = BitmapDescriptor.bytes(carByteData.buffer.asUint8List());
      }

      // Create rider icon
      final ui.PictureRecorder riderRecorder = ui.PictureRecorder();
      final Canvas riderCanvas = Canvas(riderRecorder);

      // Draw rider icon (person)
      final Paint riderPaint = Paint()
        ..color = Colors.green
        ..style = PaintingStyle.fill;

      // Draw person shape
      riderCanvas.drawCircle(
        Offset(size * 0.5, size * 0.3),
        size * 0.15,
        riderPaint,
      );

      // Draw body
      riderCanvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size * 0.35, size * 0.45, size * 0.3, size * 0.4),
          const Radius.circular(4),
        ),
        riderPaint,
      );

      // Convert to image
      final ui.Picture riderPicture = riderRecorder.endRecording();
      final ui.Image riderImage =
          await riderPicture.toImage(size.toInt(), size.toInt());
      final ByteData? riderByteData =
          await riderImage.toByteData(format: ui.ImageByteFormat.png);

      if (riderByteData != null) {
        _riderIcon = BitmapDescriptor.bytes(riderByteData.buffer.asUint8List());
      }
    } catch (e) {
      print('Error creating custom icons: $e');
      _carIcon =
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      _riderIcon =
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    }
  }

  // Initialize Pusher
  void _initializePusher() {
    try {
      final apiClient = Get.find<ApiClient>();
      _userId = apiClient.sharedPreferences.getString('user_id') ?? '';

      if (_userId!.isNotEmpty) {
        _connectToPusher();
      }
    } catch (e) {
      print('Error initializing Pusher: $e');
    }
  }

  // Connect to Pusher
  void _connectToPusher() async {
    try {
      await _pusher.init(
        apiKey: 'your_pusher_key', // Replace with actual key
        cluster: 'your_cluster', // Replace with actual cluster
        onEvent: _onPusherEvent,
        onConnectionStateChange: (String currentState, String previousState) {
          print(
              'Pusher connection state changed: $previousState -> $currentState');
          if (currentState == 'connected') {
            _subscribeToChannel();
          }
        },
        onError: (String message, int? code, dynamic e) {
          print('Pusher error: $message');
        },
      );

      await _pusher.connect();
    } catch (e) {
      print('Error connecting to Pusher: $e');
    }
  }

  // Subscribe to Pusher channel
  void _subscribeToChannel() async {
    try {
      final channelName = 'scheduled-ride-${widget.ride.id}';
      await _pusher.subscribe(channelName: channelName);

      print('Subscribed to channel: $channelName');
    } catch (e) {
      print('Error subscribing to channel: $e');
    }
  }

  // Handle Pusher events
  void _onPusherEvent(PusherEvent event) {
    try {
      print('Received Pusher event: ${event.eventName}');

      switch (event.eventName) {
        case 'driver-location-update':
          _handleDriverLocationUpdate(event);
          break;
        case 'rider-status-update':
          _handleRiderStatusUpdate(event);
          break;
        case 'ride-status-update':
          _handleRideStatusUpdate(event);
          break;
        default:
          print('Unhandled event: ${event.eventName}');
      }
    } catch (e) {
      print('Error handling Pusher event: $e');
    }
  }

  // Handle driver location updates
  void _handleDriverLocationUpdate(dynamic event) {
    try {
      final data = jsonDecode(event.data);

      if (data['latitude'] != null && data['longitude'] != null) {
        setState(() {
          _driverLocation = LatLng(
            double.parse(data['latitude'].toString()),
            double.parse(data['longitude'].toString()),
          );
        });

        _updateMarkers();

        // Show notification if driver is nearby
        if (data['distance'] != null) {
          final distance = double.parse(data['distance'].toString());
          if (distance <= 200) {
            // Within 200 meters
            _showDriverNearbyNotification(distance);
          }
        }

        print('Driver location updated: $_driverLocation');
      }
    } catch (e) {
      print('Error handling driver location update: $e');
    }
  }

  // Handle rider status updates
  void _handleRiderStatusUpdate(dynamic event) {
    try {
      final data = jsonDecode(event.data);

      if (data['status'] != null) {
        setState(() {
          _currentPickupStatus = data['status'];
        });

        // Show appropriate notification based on status
        _showStatusNotification(data['status'], data);

        print('Rider status updated: $_currentPickupStatus');
      }
    } catch (e) {
      print('Error handling rider status update: $e');
    }
  }

  // Handle ride status updates
  void _handleRideStatusUpdate(dynamic event) {
    try {
      final data = jsonDecode(event.data);

      if (data['ride_status'] != null) {
        // Update ride status and refresh UI
        _refreshRideData();

        print('Ride status updated: ${data['ride_status']}');
      }
    } catch (e) {
      print('Error handling ride status update: $e');
    }
  }

  // Show driver nearby notification
  void _showDriverNearbyNotification(double distance) {
    Get.snackbar(
      'Driver Nearby',
      'Your driver is ${(distance).toInt()} meters away',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.blue,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
      icon: const Icon(Icons.location_on, color: Colors.white),
    );
  }

  // Show status notification
  void _showStatusNotification(String status, Map<String, dynamic> data) {
    String title = '';
    String message = '';
    Color backgroundColor = Colors.blue;
    IconData icon = Icons.info;

    switch (status) {
      case 'on_way':
        title = 'Driver On The Way';
        message = 'Your driver is heading to your pickup location';
        backgroundColor = Colors.blue;
        icon = Icons.directions_car;
        break;
      case 'reached':
        title = 'Driver Arrived';
        message = 'Your driver has arrived at the pickup location';
        backgroundColor = Colors.green;
        icon = Icons.location_on;
        break;
      case 'cancelled':
        title = 'Pickup Cancelled';
        message = 'The driver has cancelled your pickup';
        backgroundColor = Colors.red;
        icon = Icons.cancel;
        break;
      case 'started':
        title = 'Ride Started';
        message = 'Your ride has begun';
        backgroundColor = Colors.green;
        icon = Icons.play_arrow;
        break;
      case 'completed':
        title = 'Ride Completed';
        message = 'Your ride has been completed';
        backgroundColor = Colors.green;
        icon = Icons.check_circle;
        break;
    }

    if (title.isNotEmpty) {
      Get.snackbar(
        title,
        message,
        snackPosition: SnackPosition.TOP,
        backgroundColor: backgroundColor,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
        icon: Icon(icon, color: Colors.white),
      );
    }
  }

  // Refresh ride data
  void _refreshRideData() {
    // This would typically refresh the ride data from the API
    // For now, we'll just update the UI
    setState(() {});
  }

  // Calculate distance between two points
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // Earth's radius in meters

    double lat1Rad = point1.latitude * (3.14159265359 / 180);
    double lat2Rad = point2.latitude * (3.14159265359 / 180);
    double deltaLatRad =
        (point2.latitude - point1.latitude) * (3.14159265359 / 180);
    double deltaLngRad =
        (point2.longitude - point1.longitude) * (3.14159265359 / 180);

    double a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) *
            cos(lat2Rad) *
            sin(deltaLngRad / 2) *
            sin(deltaLngRad / 2);
    double c = 2 * asin(sqrt(a));

    return earthRadius * c;
  }

  // Get formatted distance string
  String _getFormattedDistance() {
    if (_driverLocation == null || _pickupLocation == null) {
      return 'Calculating...';
    }

    double distance = _calculateDistance(_driverLocation!, _pickupLocation!);

    if (distance < 1000) {
      return '${distance.toInt()} m';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)} km';
    }
  }

  // Manual start ride
  void _manualStartRide() {
    _startRideTimer?.cancel();
    final controller = Get.find<ScheduledRideController>();
    controller.startScheduledRide(widget.ride.id!);

    Get.snackbar(
      'Ride Started',
      'Your ride has been started.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green,
      colorText: Colors.white,
    );
  }

  // Get current location
  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        _riderLocation = LatLng(position.latitude, position.longitude);
      });
      _updateMarkers();
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  // Update map markers
  void _updateMarkers() {
    _markers.clear();
    _polylines.clear();

    // Rider location marker
    if (_riderLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('rider'),
          position: _riderLocation!,
          icon: _riderIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Your Location'),
        ),
      );
    }

    // Driver location marker
    if (_driverLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: _driverLocation!,
          icon: _carIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Driver Location'),
        ),
      );
    }

    // Pickup location marker
    if (_pickupLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: _pickupLocation!,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: const InfoWindow(title: 'Pickup Location'),
        ),
      );
    }

    // Destination marker
    if (_destinationLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _destinationLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Destination'),
        ),
      );
    }

    // Add route polyline if we have both driver and pickup locations
    if (_driverLocation != null && _pickupLocation != null) {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('driver_route'),
          points: [_driverLocation!, _pickupLocation!],
          color: MyColor.primaryColor,
          width: 4,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ),
      );
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyColor.screenBgColor,
      appBar: CustomAppBar(
        title: 'Ride Tracking',
        isShowBackBtn: true,
        bgColor: MyColor.primaryColor,
        elevation: 0,
      ),
      body: GetBuilder<ScheduledRideController>(
        builder: (controller) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                children: [
                  // Map View
                  Expanded(
                    flex: 2,
                    child: _buildMapView(),
                  ),

                  // Bottom Details Panel
                  Expanded(
                    flex: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: MyColor.colorWhite,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.1),
                            spreadRadius: 1,
                            blurRadius: 10,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(Dimensions.space15),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Drag handle
                            Center(
                              child: Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            spaceDown(Dimensions.space20),

                            // Ride info
                            _buildRideInfoCard(),
                            spaceDown(Dimensions.space15),

                            // Status info
                            _buildStatusCard(),
                            spaceDown(Dimensions.space15),

                            // Start ride button (if reached)
                            if (_canStartRide) _buildStartRideButton(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Build map view
  Widget _buildMapView() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Dimensions.largeRadius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Dimensions.largeRadius),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _pickupLocation ?? const LatLng(37.7749, -122.4194),
            zoom: 15.0,
          ),
          markers: _markers,
          polylines: _polylines,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          zoomControlsEnabled: true,
          mapToolbarEnabled: false,
        ),
      ),
    );
  }

  // Build ride info card
  Widget _buildRideInfoCard() {
    return Container(
      padding: const EdgeInsets.all(Dimensions.space15),
      decoration: BoxDecoration(
        color: MyColor.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(Dimensions.mediumRadius),
        border: Border.all(color: MyColor.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ride Information',
            style: boldDefault.copyWith(
              color: MyColor.colorBlack,
              fontSize: Dimensions.fontLarge,
            ),
          ),
          spaceDown(Dimensions.space10),
          _buildInfoRow(Icons.location_on, 'From',
              widget.ride.pickupLocation ?? 'Not specified'),
          spaceDown(Dimensions.space8),
          _buildInfoRow(Icons.location_on_outlined, 'To',
              widget.ride.destination ?? 'Not specified'),
          spaceDown(Dimensions.space8),
          _buildInfoRow(Icons.person, 'Driver',
              widget.ride.driver?.firstname ?? 'Unknown'),
          spaceDown(Dimensions.space8),
          _buildInfoRow(Icons.directions_car, 'Vehicle',
              widget.ride.service?.name ?? 'Unknown'),
        ],
      ),
    );
  }

  // Build status card
  Widget _buildStatusCard() {
    String statusText = 'Waiting for driver...';
    Color statusColor = Colors.orange;
    IconData statusIcon = Icons.schedule;
    String? distanceText;

    switch (_currentPickupStatus) {
      case 'on_way':
        statusText = 'Driver is on the way';
        statusColor = Colors.blue;
        statusIcon = Icons.directions_car;
        if (_driverLocation != null) {
          distanceText = 'Distance: ${_getFormattedDistance()}';
        }
        break;
      case 'reached':
        statusText = 'Driver has arrived';
        statusColor = Colors.green;
        statusIcon = Icons.location_on;
        break;
      case 'cancelled':
        statusText = 'Ride cancelled by driver';
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(Dimensions.space15),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(Dimensions.mediumRadius),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 24),
              spaceSide(Dimensions.space12),
              Expanded(
                child: Text(
                  statusText,
                  style: boldDefault.copyWith(
                    color: statusColor,
                    fontSize: Dimensions.fontDefault,
                  ),
                ),
              ),
            ],
          ),
          if (distanceText != null) ...[
            spaceDown(Dimensions.space8),
            Row(
              children: [
                spaceSide(Dimensions.space15 * 2.4), // Align with text above
                Expanded(
                  child: Text(
                    distanceText,
                    style: regularDefault.copyWith(
                      color: statusColor.withValues(alpha: 0.8),
                      fontSize: Dimensions.fontSmall,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // Build start ride button
  Widget _buildStartRideButton() {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green, Colors.green.shade600],
        ),
        borderRadius: BorderRadius.circular(Dimensions.mediumRadius),
      ),
      child: TextButton.icon(
        onPressed: _manualStartRide,
        icon: const Icon(Icons.play_arrow, color: Colors.white, size: 24),
        label: Text(
          _timerCountdown > 0
              ? 'Start Ride (${_timerCountdown}s)'
              : 'Start Ride',
          style: boldDefault.copyWith(
            color: Colors.white,
            fontSize: Dimensions.fontDefault,
          ),
        ),
      ),
    );
  }

  // Build info row
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: MyColor.primaryColor, size: 18),
        spaceSide(Dimensions.space8),
        Text(
          '$label: ',
          style: regularDefault.copyWith(
            color: MyColor.colorBlack.withValues(alpha: 0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: regularDefault.copyWith(
              color: MyColor.colorBlack,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
