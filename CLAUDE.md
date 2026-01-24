# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**OVO RIDE USER** - Rider/User mobile application for a complete ride-sharing solution. Built with Flutter 3.5+ and uses GetX framework for state management, routing, and dependency injection.

## Architecture

The codebase follows a layered architecture with clear separation of concerns:

```
lib/
├── core/                 # Core utilities and configuration
│   ├── di_service/      # Dependency injection (GetX bindings)
│   ├── helper/          # Helper utilities, SharedPreferences keys
│   ├── route/           # Route definitions and navigation
│   ├── theme/           # App theming
│   └── utils/           # Constants, colors, styles, strings, dimensions
├── data/                # Data layer
│   ├── controller/      # GetX controllers (state + business logic)
│   ├── model/           # Data models and response classes
│   ├── repo/            # Repository layer for API calls
│   └── services/        # Services (API client, notifications, location)
└── presentation/        # UI layer
    ├── components/      # Reusable UI components
    └── screens/         # App screens/pages
```

### Key Architectural Patterns

**GetX Controllers** manage state and business logic:
```dart
class ExampleController extends GetxController {
  final ExampleRepo repo;
  ExampleController({required this.repo});

  bool isLoading = false;

  Future<void> loadData() async {
    isLoading = true;
    update();  // Triggers UI rebuild

    ResponseModel response = await repo.getData();

    isLoading = false;
    update();
  }
}
```

**Dependency Injection** in `lib/core/di_service/di_services.dart`:
```dart
Get.lazyPut(() => ExampleRepo(apiClient: Get.find()));
Get.lazyPut(() => ExampleController(repo: Get.find()));
```

**API Client** (`lib/data/services/api_service.dart`):
- Centralized HTTP client using `http` package
- Bearer token authentication stored in SharedPreferences
- Custom `dev-token` header for backend authentication
- Methods: GET, POST, DELETE, PATCH
- SSL certificate validation disabled (see Security Notes below)

**Routing** managed by GetX (`lib/core/route/route.dart`):
- All routes defined in `RouteHelper` class
- Navigation: `Get.toNamed(RouteHelper.screenName)`

**SharedPreferences Keys** defined in `lib/core/helper/shared_preference_helper.dart`

## Development Commands

### Basic Commands

```bash
# Install dependencies
flutter pub get

# Run the app (debug mode)
flutter run

# Run on specific device
flutter run -d <device-id>

# List available devices
flutter devices

# Analyze code
flutter analyze

# Clean build artifacts
flutter clean

# Build for production
flutter build apk --release          # Android APK
flutter build appbundle --release    # Android App Bundle for Play Store
flutter build ios --release          # iOS
```

### Code Quality

```bash
# Run Flutter lints
flutter analyze

# Format code
flutter format lib/

# Check for formatting issues
flutter format --set-exit-if-changed lib/
```

### Package Management

```bash
# Update dependencies
flutter pub upgrade

# Check for outdated packages
flutter pub outdated

# Get specific package
flutter pub add <package_name>
```

## Configuration

### Environment Variables
Located in `lib/environment.dart`:
- App name, version, default language
- OTP configuration (120 second resend)
- Google Maps API key
- Default country settings (US, dial code +1)

### API Configuration
Base URL in `lib/core/utils/url_container.dart`:
```dart
static const String domainUrl = 'https://www.halalfoodalliance.org/mysharingapp.com';
static const String baseUrl = '$domainUrl/api/';
```

### Firebase Configuration
- Firebase initialized in `lib/main.dart`
- Configuration in `lib/firebase_options.dart`
- Background message handler: `_messageHandler()`

## Key Features & Implementations

### Scheduled Rides
Riders can browse and join scheduled rides created by drivers. See `SCHEDULED_RIDES_README.md` for detailed documentation.

**Key files:**
- `lib/data/model/scheduled_ride/scheduled_ride_model.dart`
- `lib/data/repo/scheduled_ride/scheduled_ride_repo.dart`
- `lib/data/controller/scheduled_ride/scheduled_ride_controller.dart`
- `lib/presentation/screens/scheduled_rides/*`

### Real-time Updates

**Pusher Integration** (`pusher_channels_flutter`):
- Controller: `lib/data/controller/pusher/pusher_ride_controller.dart`
- Events: `pickup_ride`, `message`, `live_location`, `payment_complete`, `ride_end`
- Configuration stored via `ApiClient.getPushConfig()`

**Firebase Push Notifications**:
- Setup: `lib/data/services/push_notification_service.dart`
- Background handler registered in `main.dart`
- Notification navigation via `for_app` data field: `"route-id"` format
- Local notifications via `flutter_local_notifications`

### Location Services

**Google Maps**:
- API key in `lib/environment.dart` (mapKey constant)
- Packages: `google_maps_flutter`, `geolocator`, `geocoding`
- Polyline drawing: `flutter_polyline_points`
- Location controller: `lib/data/controller/location/app_location_controller.dart`

### Authentication

**Auth Flow:**
1. Login/Registration: `lib/presentation/screens/auth/`
2. SMS/Email verification
3. Profile completion
4. Token stored in SharedPreferences
5. Social auth supported (Google, Apple)

**Controllers:**
- `lib/data/controller/auth/auth/`
- `lib/data/controller/auth/forget_password/`

### Ride Management

**Core Features:**
- Create rides: `UrlContainer.createRide`
- Active rides: `lib/data/controller/ride/active_ride/`
- Ride details: `lib/data/controller/ride/ride_details/`
- Messaging: `lib/data/controller/ride/ride_meassage/`
- Bid system: `lib/data/controller/ride/ride_bid_list/`

## Adding New Features

### 1. Create a new screen

```bash
# Create screen file
lib/presentation/screens/feature_name/feature_screen.dart
```

### 2. Add route

In `lib/core/route/route.dart`:
```dart
static const String featureScreen = "/feature_screen";

GetPage(
  name: featureScreen,
  page: () => const FeatureScreen(),
)
```

### 3. Create controller

```dart
// lib/data/controller/feature/feature_controller.dart
class FeatureController extends GetxController {
  final FeatureRepo repo;
  FeatureController({required this.repo});

  // State and methods
}
```

### 4. Create repository

```dart
// lib/data/repo/feature/feature_repo.dart
class FeatureRepo {
  final ApiClient apiClient;
  FeatureRepo({required this.apiClient});

  Future<ResponseModel> getData() async {
    String url = '${UrlContainer.baseUrl}${UrlContainer.endpoint}';
    return await apiClient.request(url, Method.getMethod, null, passHeader: true);
  }
}
```

### 5. Register dependencies

In `lib/core/di_service/di_services.dart`:
```dart
Get.lazyPut(() => FeatureRepo(apiClient: Get.find()));
Get.lazyPut(() => FeatureController(repo: Get.find()));
```

## Security Notes

**IMPORTANT for Production:**

1. **SSL Certificate Validation**: Currently disabled via `MyHttpOverrides` in `main.dart`. Remove for production:
```dart
// Remove this in production
HttpOverrides.global = MyHttpOverrides();
```

2. **API Keys**: Google Maps API key is hardcoded in `environment.dart`. Move to secure environment variables.

3. **Dev Token**: Backend dev-token is hardcoded in `api_service.dart`. Should be environment-specific.

4. **Secrets**: Never commit `.env` files or credentials to version control.

## Dependencies

### Core Packages
- `get: ^4.6.6` - State management, routing, DI
- `dio: ^5.7.0` - Alternative HTTP client (alongside http)
- `http: ^1.3.0` - HTTP requests
- `shared_preferences: ^2.3.5` - Local storage

### Maps & Location
- `google_maps_flutter: ^2.10.0`
- `geolocator: ^13.0.2`
- `geocoding: ^3.0.0`
- `flutter_polyline_points: ^2.1.0`

### Firebase & Notifications
- `firebase_core: ^3.10.0`
- `firebase_messaging: ^15.2.1`
- `flutter_local_notifications: ^18.0.1`
- `pusher_channels_flutter: ^2.5.0`

### UI & Animation
- `flutter_animate: ^4.5.2`
- `lottie: ^3.3.1`
- `shimmer: ^3.0.0`
- `flutter_spinkit: ^5.2.1`

### Utilities
- `intl: ^0.20.0` - Internationalization
- `logger: ^2.5.0` - Logging
- `permission_handler: ^11.3.1` - Permissions
- `image_picker: ^1.1.2` - Image selection
- `file_picker: ^8.1.7` - File selection

## Localization

- Default: English (en_US)
- Controller: `LocalizationController`
- Translations: `Messages` class using GetX translations
- String constants: `lib/core/utils/my_strings.dart`

## Assets

```
assets/
├── images/          # General images
├── images/social/   # Social login icons
├── images/logo/     # App logos
├── images/onboard/  # Onboarding images
├── icon/            # Icons
├── img/             # Additional images and map icons
├── animation/       # Lottie animations
└── fonts/           # Inter font family
```

## Build Configuration

**Android**: `android/app/build.gradle`
- Application ID: `com.app.ridesharingrider`
- Update `minSdkVersion`, `targetSdkVersion` in build.gradle

**iOS**: `ios/Runner/Info.plist`
- Bundle identifier
- Location permissions required for maps
- Camera/Photo library permissions for profile pictures

## Common Development Patterns

### Making API Calls

```dart
// In repository
Future<ResponseModel> fetchData() async {
  String url = '${UrlContainer.baseUrl}endpoint';
  return await apiClient.request(url, Method.getMethod, null, passHeader: true);
}

// In controller
Future<void> getData() async {
  isLoading = true;
  update();

  ResponseModel response = await repo.fetchData();

  if (response.statusCode == 200) {
    // Handle success
  } else {
    // Handle error
  }

  isLoading = false;
  update();
}
```

### Navigation

```dart
// Navigate to screen
Get.toNamed(RouteHelper.screenName);

// Navigate with arguments
Get.toNamed(RouteHelper.screenName, arguments: data);

// Navigate and remove previous routes
Get.offAllNamed(RouteHelper.screenName);

// Go back
Get.back();
```

### Accessing SharedPreferences

```dart
// Via ApiClient
String? token = apiClient.sharedPreferences.getString(SharedPreferenceHelper.accessTokenKey);

// Via Get.find
SharedPreferences prefs = Get.find<SharedPreferences>();
await prefs.setString(SharedPreferenceHelper.userEmailKey, email);
```

## Testing Requirements

To run this app, you need:
- Backend API running (base URL in `url_container.dart`)
- Firebase project configured
- Google Maps API key
- Physical device or emulator with:
  - Location services enabled
  - Google Play Services (Android) / Location permissions (iOS)
  - Internet connection

## Debugging

### Common Issues

**Maps not showing:**
- Verify Google Maps API key in `environment.dart`
- Check location permissions
- Ensure Google Play Services installed (Android)

**Push notifications not working:**
- Verify Firebase configuration
- Check FCM token generation
- Ensure notification permissions granted

**API calls failing:**
- Check backend API URL in `url_container.dart`
- Verify dev-token matches backend
- Check auth token in SharedPreferences

### Logging

Use the custom `printX()` function (from `string_format_helper.dart`) for debug logging:
```dart
printX('Debug message: $variable');
```
