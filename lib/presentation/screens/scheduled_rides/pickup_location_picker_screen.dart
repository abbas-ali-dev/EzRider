import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:ovorideuser/core/utils/dimensions.dart';
import 'package:ovorideuser/core/utils/my_color.dart';
import 'package:ovorideuser/core/utils/style.dart';
import 'package:ovorideuser/data/model/location/selected_location_info.dart';
import 'package:ovorideuser/presentation/components/custom_loader/custom_loader.dart';
import 'package:ovorideuser/presentation/components/divider/custom_spacer.dart';
import 'package:ovorideuser/presentation/components/snack_bar/show_custom_snackbar.dart';
import 'package:ovorideuser/presentation/components/buttons/rounded_button.dart';

class PickupLocationPickerScreen extends StatefulWidget {
  const PickupLocationPickerScreen({super.key});

  @override
  State<PickupLocationPickerScreen> createState() => _PickupLocationPickerScreenState();
}

class _PickupLocationPickerScreenState extends State<PickupLocationPickerScreen>
    with TickerProviderStateMixin {

  // Controllers
  final TextEditingController searchController = TextEditingController();
  GoogleMapController? mapController;
  final FocusNode searchFocusNode = FocusNode();

  // Animation Controllers
  late AnimationController _bottomSheetAnimationController;
  late AnimationController _searchBarAnimationController;
  late Animation<Offset> _bottomSheetSlideAnimation;
  late Animation<double> _searchBarFadeAnimation;

  // Location variables
  Position? currentPosition;
  LatLng? selectedLocation;
  String selectedAddress = '';
  String selectedPlaceName = '';
  String selectedCity = '';
  String selectedCountry = '';

  // State variables
  bool isLoading = true;
  bool isSearching = false;
  bool isLoadingAddress = false;
  List<Map<String, dynamic>> searchResults = [];

  // Map variables
  Set<Marker> markers = {};
  final CameraPosition _initialPosition = const CameraPosition(
    target: LatLng(37.7749, -122.4194), // Default San Francisco
    zoom: 14.0,
  );

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _getCurrentLocation();
  }

  void _initializeAnimations() {
    _bottomSheetAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _searchBarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _bottomSheetSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _bottomSheetAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _searchBarFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _searchBarAnimationController,
      curve: Curves.easeIn,
    ));

    _searchBarAnimationController.forward();
  }

  @override
  void dispose() {
    searchController.dispose();
    mapController?.dispose();
    searchFocusNode.dispose();
    _bottomSheetAnimationController.dispose();
    _searchBarAnimationController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Check location permission
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        CustomSnackBar.error(errorList: ['Location services are disabled']);
        setState(() {
          isLoading = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          CustomSnackBar.error(errorList: ['Location permission denied']);
          setState(() {
            isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
        CustomSnackBar.error(errorList: ['Location permission permanently denied']);
        setState(() {
          isLoading = false;
        });
        return;
      }

      // Get current position
      currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // Move map to current location
      if (mapController != null && currentPosition != null) {
        mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(currentPosition!.latitude, currentPosition!.longitude),
              zoom: 16.0,
            ),
          ),
        );

        // Set initial selected location to current position
        _onMapTapped(LatLng(currentPosition!.latitude, currentPosition!.longitude));
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      CustomSnackBar.error(errorList: ['Error getting current location']);
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _onMapTapped(LatLng position) async {
    setState(() {
      selectedLocation = position;
      isLoadingAddress = true;

      // Update marker
      markers = {
        Marker(
          markerId: const MarkerId('selected_location'),
          position: position,
          infoWindow: const InfoWindow(title: 'Selected Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      };
    });

    // Show bottom sheet with animation
    _bottomSheetAnimationController.forward();

    try {
      // Get address from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];

        setState(() {
          selectedPlaceName = place.name ?? '';
          selectedCity = place.locality ?? place.subAdministrativeArea ?? '';
          selectedCountry = place.country ?? '';

          // Build full address
          List<String> addressParts = [];
          if (place.name != null && place.name!.isNotEmpty) addressParts.add(place.name!);
          if (place.street != null && place.street!.isNotEmpty) addressParts.add(place.street!);
          if (place.locality != null && place.locality!.isNotEmpty) addressParts.add(place.locality!);
          if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
            addressParts.add(place.administrativeArea!);
          }
          if (place.postalCode != null && place.postalCode!.isNotEmpty) {
            addressParts.add(place.postalCode!);
          }
          if (place.country != null && place.country!.isNotEmpty) addressParts.add(place.country!);

          selectedAddress = addressParts.join(', ');
          isLoadingAddress = false;
        });
      }
    } catch (e) {
      debugPrint('Error getting address: $e');
      setState(() {
        selectedAddress = 'Location selected (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
        isLoadingAddress = false;
      });
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      setState(() {
        searchResults = [];
        isSearching = false;
      });
      return;
    }

    setState(() {
      isSearching = true;
    });

    try {
      List<Location> locations = await locationFromAddress(query);

      setState(() {
        searchResults = locations.map((location) {
          return {
            'address': query,
            'lat': location.latitude,
            'lng': location.longitude,
          };
        }).toList();
        isSearching = false;
      });
    } catch (e) {
      debugPrint('Error searching location: $e');
      setState(() {
        searchResults = [];
        isSearching = false;
      });
    }
  }

  void _selectSearchResult(Map<String, dynamic> result) {
    LatLng position = LatLng(result['lat'], result['lng']);

    // Hide keyboard and clear search
    searchFocusNode.unfocus();
    setState(() {
      searchResults = [];
      searchController.clear();
    });

    // Move map and select location
    mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: position,
          zoom: 16.0,
        ),
      ),
    );

    _onMapTapped(position);
  }

  void _confirmLocation() {
    if (selectedLocation == null) {
      CustomSnackBar.error(errorList: ['Please select a pickup location']);
      return;
    }

    // Create selected location info
    SelectedLocationInfo locationInfo = SelectedLocationInfo(
      latitude: selectedLocation!.latitude,
      longitude: selectedLocation!.longitude,
      placeName: selectedPlaceName.isNotEmpty ? selectedPlaceName : 'Selected Location',
      address: selectedAddress,
      city: selectedCity,
      country: selectedCountry,
      fullAddress: selectedAddress,
    );

    // Return the selected location
    Get.back(result: locationInfo);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            initialCameraPosition: _initialPosition,
            onMapCreated: (GoogleMapController controller) {
              mapController = controller;
              if (currentPosition != null) {
                controller.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: LatLng(currentPosition!.latitude, currentPosition!.longitude),
                      zoom: 16.0,
                    ),
                  ),
                );
              }
            },
            onTap: _onMapTapped,
            markers: markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
          ),

          // Loading overlay
          if (isLoading)
            Container(
              color: Colors.white.withValues(alpha: 0.8),
              child: const Center(
                child: CustomLoader(),
              ),
            ),

          // Top search bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _searchBarFadeAnimation,
              child: Container(
                decoration: BoxDecoration(
                  color: MyColor.colorWhite,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      // Header with back button and search field
                      Container(
                        padding: const EdgeInsets.all(Dimensions.space15),
                        child: Row(
                          children: [
                            // Back button
                            IconButton(
                              onPressed: () => Get.back(),
                              icon: Icon(
                                Icons.arrow_back_ios,
                                color: MyColor.colorBlack,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            spaceSide(Dimensions.space10),

                            // Search field
                            Expanded(
                              child: Container(
                                height: 45,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(Dimensions.mediumRadius),
                                ),
                                child: TextField(
                                  controller: searchController,
                                  focusNode: searchFocusNode,
                                  decoration: InputDecoration(
                                    hintText: 'Search pickup location...',
                                    hintStyle: regularDefault.copyWith(
                                      color: Colors.grey,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.search,
                                      color: Colors.grey.shade600,
                                    ),
                                    suffixIcon: searchController.text.isNotEmpty
                                        ? IconButton(
                                            icon: Icon(
                                              Icons.clear,
                                              color: Colors.grey.shade600,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                searchController.clear();
                                                searchResults = [];
                                              });
                                            },
                                          )
                                        : null,
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: Dimensions.space15,
                                      vertical: Dimensions.space12,
                                    ),
                                  ),
                                  onChanged: (value) {
                                    // Debounce search
                                    Future.delayed(const Duration(milliseconds: 500), () {
                                      if (value == searchController.text) {
                                        _searchLocation(value);
                                      }
                                    });
                                  },
                                  style: regularDefault.copyWith(
                                    color: MyColor.colorBlack,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Search results
                      if (searchResults.isNotEmpty)
                        Container(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.of(context).size.height * 0.3,
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: searchResults.length,
                            itemBuilder: (context, index) {
                              final result = searchResults[index];
                              return ListTile(
                                leading: Icon(
                                  Icons.location_on_outlined,
                                  color: MyColor.primaryColor,
                                ),
                                title: Text(
                                  result['address'],
                                  style: regularDefault.copyWith(
                                    color: MyColor.colorBlack,
                                  ),
                                ),
                                onTap: () => _selectSearchResult(result),
                              );
                            },
                          ),
                        ),

                      if (isSearching)
                        const Padding(
                          padding: EdgeInsets.all(Dimensions.space15),
                          child: CircularProgressIndicator(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Current location button
          Positioned(
            right: Dimensions.space15,
            bottom: selectedLocation != null ? 220 : 100,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: MyColor.colorWhite,
              onPressed: _getCurrentLocation,
              child: Icon(
                Icons.my_location,
                color: MyColor.primaryColor,
              ),
            ),
          ),

          // Bottom sheet with selected location
          if (selectedLocation != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SlideTransition(
                position: _bottomSheetSlideAnimation,
                child: Container(
                  decoration: BoxDecoration(
                    color: MyColor.colorWhite,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(Dimensions.largeRadius),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(Dimensions.space20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Drag handle
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          spaceDown(Dimensions.space15),

                          // Location details
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(Dimensions.space10),
                                decoration: BoxDecoration(
                                  color: MyColor.primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(Dimensions.mediumRadius),
                                ),
                                child: Icon(
                                  Icons.location_on,
                                  color: MyColor.primaryColor,
                                  size: 24,
                                ),
                              ),
                              spaceSide(Dimensions.space15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Pickup Location',
                                      style: regularSmall.copyWith(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                    spaceDown(Dimensions.space4),
                                    if (isLoadingAddress)
                                      const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    else
                                      Text(
                                        selectedAddress.isNotEmpty
                                            ? selectedAddress
                                            : 'Getting address...',
                                        style: boldDefault.copyWith(
                                          color: MyColor.colorBlack,
                                          fontSize: 14,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          spaceDown(Dimensions.space20),

                          // Confirm button
                          SizedBox(
                            width: double.infinity,
                            child: RoundedButton(
                              text: 'Confirm Pickup Location',
                              press: _confirmLocation,
                              isOutlined: false,
                              color: MyColor.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}