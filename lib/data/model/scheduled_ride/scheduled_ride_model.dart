import 'package:ovorideuser/data/model/global/app/app_service_model.dart';
import 'package:ovorideuser/data/model/global/user/global_driver_model.dart';

/// Available ride model for riders to see
/// Updated to match the new API response structure:
/// - Uses 'scheduled_rides' instead of 'rides'
/// - New fields: available_seats, estimated_fare, is_intercity, scheduled_date_time
/// - Removed old fields: ride_type, uid, user_id, gateway_currency_id, etc.
/// - Updated driver and service models to match new structure
class AvailableRideModel {
  String? id;
  String? driverId;
  String? serviceId;
  String? pickupLocation;
  String? pickupLatitude;
  String? pickupLongitude;
  String? destination;
  String? destinationLatitude;
  String? destinationLongitude;
  String? scheduledDateTime;
  String? numberOfPassengers;
  String? availableSeats;
  String? note;
  String? estimatedFare;
  String? distance;
  String? duration;
  bool? isIntercity;
  String? status;
  String? statusText; // Human-readable status text
  String? cancelReason;
  String? createdAt;
  String? updatedAt;

  // Related models
  GlobalDriverInfo? driver;
  AppService? service;
  List<ScheduledRidePassenger>? passengers;
  bool? canLeave;

  // Driver's current location (if provided by API)
  String? driverCurrentLatitude;
  String? driverCurrentLongitude;

  AvailableRideModel({
    this.id,
    this.driverId,
    this.serviceId,
    this.pickupLocation,
    this.pickupLatitude,
    this.pickupLongitude,
    this.destination,
    this.destinationLatitude,
    this.destinationLongitude,
    this.scheduledDateTime,
    this.numberOfPassengers,
    this.availableSeats,
    this.note,
    this.estimatedFare,
    this.distance,
    this.duration,
    this.isIntercity,
    this.status,
    this.statusText,
    this.cancelReason,
    this.createdAt,
    this.updatedAt,
    this.driver,
    this.service,
    this.passengers,
    this.canLeave,
    this.driverCurrentLatitude,
    this.driverCurrentLongitude,
  });

  factory AvailableRideModel.fromJson(Map<String, dynamic> json) =>
      AvailableRideModel(
        id: json["id"]?.toString(),
        driverId: json["driver_id"]?.toString(),
        serviceId: json["service_id"]?.toString(),
        pickupLocation: json["pickup_location"]?.toString(),
        pickupLatitude: json["pickup_latitude"]?.toString(),
        pickupLongitude: json["pickup_longitude"]?.toString(),
        destination: json["destination"]?.toString(),
        destinationLatitude: json["destination_latitude"]?.toString(),
        destinationLongitude: json["destination_longitude"]?.toString(),
        scheduledDateTime: json["scheduled_date_time"]?.toString(),
        numberOfPassengers: json["number_of_passengers"]?.toString(),
        availableSeats: json["available_seats"]?.toString(),
        note: json["note"]?.toString(),
        estimatedFare: json["estimated_fare"]?.toString(),
        distance: json["distance"]?.toString(),
        duration: json["duration"]?.toString(),
        isIntercity: json["is_intercity"] == null || json["is_intercity"] == "" 
            ? null 
            : (json["is_intercity"] == "1" || json["is_intercity"] == 1 || json["is_intercity"] == true),
        status: json["status"]?.toString(),
        statusText: json["status_text"]?.toString(),
        cancelReason: json["cancel_reason"]?.toString(),
        createdAt: json["created_at"]?.toString(),
        updatedAt: json["updated_at"]?.toString(),
        driver: json["driver"] == null
            ? null
            : GlobalDriverInfo.fromJson(json["driver"]),
        service: json["service"] == null
            ? null
            : AppService.fromJson(json["service"]),
        passengers: json["passengers"] == null
            ? []
            : List<ScheduledRidePassenger>.from(json["passengers"]!
                .map((x) => ScheduledRidePassenger.fromJson(x))),
        canLeave: json["can_leave"] == null || json["can_leave"] == "" 
            ? null 
            : (json["can_leave"] == "1" || json["can_leave"] == 1 || json["can_leave"] == true),
        driverCurrentLatitude: json["driver_current_latitude"]?.toString(),
        driverCurrentLongitude: json["driver_current_longitude"]?.toString(),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "driver_id": driverId,
        "service_id": serviceId,
        "pickup_location": pickupLocation,
        "pickup_latitude": pickupLatitude,
        "pickup_longitude": pickupLongitude,
        "destination": destination,
        "destination_latitude": destinationLatitude,
        "destination_longitude": destinationLongitude,
        "scheduled_date_time": scheduledDateTime,
        "number_of_passengers": numberOfPassengers,
        "available_seats": availableSeats,
        "note": note,
        "estimated_fare": estimatedFare,
        "distance": distance,
        "duration": duration,
        "is_intercity": isIntercity,
        "status": status,
        "status_text": statusText,
        "cancel_reason": cancelReason,
        "created_at": createdAt,
        "updated_at": updatedAt,
        "driver": driver?.toJson(),
        "service": service?.toJson(),
        "passengers": passengers,
        "can_leave": canLeave,
        "driver_current_latitude": driverCurrentLatitude,
        "driver_current_longitude": driverCurrentLongitude,
      };

  // Helper method to calculate fare per seat
  String getFarePerSeat() {
    if (estimatedFare == null || numberOfPassengers == null) return '0';
    
    try {
      double totalFare = double.parse(estimatedFare!);
      int totalSeats = int.parse(numberOfPassengers!);
      
      if (totalSeats == 0) return '0';
      
      double farePerSeat = totalFare / totalSeats;
      return farePerSeat.toStringAsFixed(2);
    } catch (e) {
      return '0';
    }
  }

  // Helper method to calculate fare for specific number of seats
  String calculateFareForSeats(int seats) {
    if (estimatedFare == null || numberOfPassengers == null) return '0';
    
    try {
      double totalFare = double.parse(estimatedFare!);
      int totalSeats = int.parse(numberOfPassengers!);
      
      if (totalSeats == 0) return '0';
      
      double farePerSeat = totalFare / totalSeats;
      double fareForSelectedSeats = farePerSeat * seats;
      return fareForSelectedSeats.toStringAsFixed(2);
    } catch (e) {
      return '0';
    }
  }
}

// Passenger model for joining rides
class PassengerModel {
  String? id;
  String? rideId;
  String? userId;
  String? pickupLocation;
  String? pickupLatitude;
  String? pickupLongitude;
  String? destination;
  String? destinationLatitude;
  String? destinationLongitude;
  String? distance;
  String? fare;
  String? status; // 0: pending, 1: approved, 2: completed
  String?
      pickupStatus; // null: not started, "on_way": driver on way, "reached": driver reached, "cancelled": cancelled by driver
  String? driverApproved;
  String? joinedAt;
  String? completedAt;
  String? createdAt;
  String? updatedAt;

  PassengerModel({
    this.id,
    this.rideId,
    this.userId,
    this.pickupLocation,
    this.pickupLatitude,
    this.pickupLongitude,
    this.destination,
    this.destinationLatitude,
    this.destinationLongitude,
    this.distance,
    this.fare,
    this.status,
    this.pickupStatus,
    this.driverApproved,
    this.joinedAt,
    this.completedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory PassengerModel.fromJson(Map<String, dynamic> json) => PassengerModel(
        id: json["id"]?.toString(),
        rideId: json["ride_id"]?.toString(),
        userId: json["user_id"]?.toString(),
        pickupLocation: json["pickup_location"]?.toString(),
        pickupLatitude: json["pickup_latitude"]?.toString(),
        pickupLongitude: json["pickup_longitude"]?.toString(),
        destination: json["destination"]?.toString(),
        destinationLatitude: json["destination_latitude"]?.toString(),
        destinationLongitude: json["destination_longitude"]?.toString(),
        distance: json["distance"]?.toString(),
        // Check multiple possible fare field names from the API
        fare: json["fare"]?.toString() ??
              json["total_fare"]?.toString() ??
              json["passenger_fare"]?.toString() ??
              json["estimated_fare"]?.toString() ??
              '0',
        status: json["status"]?.toString(),
        pickupStatus: json["pickup_status"]?.toString(),
        driverApproved: json["driver_approved"]?.toString(),
        joinedAt: json["joined_at"]?.toString(),
        completedAt: json["completed_at"]?.toString(),
        createdAt: json["created_at"]?.toString(),
        updatedAt: json["updated_at"]?.toString(),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "ride_id": rideId,
        "user_id": userId,
        "pickup_location": pickupLocation,
        "pickup_latitude": pickupLatitude,
        "pickup_longitude": pickupLongitude,
        "destination": destination,
        "destination_latitude": destinationLatitude,
        "destination_longitude": destinationLongitude,
        "distance": distance,
        "fare": fare,
        "status": status,
        "pickup_status": pickupStatus,
        "driver_approved": driverApproved,
        "joined_at": joinedAt,
        "completed_at": completedAt,
        "created_at": createdAt,
        "updated_at": updatedAt,
      };
}

// Response model for available rides list
class AvailableRidesResponseModel {
  String? remark;
  String? status;
  List<String>? message;
  AvailableRidesData? data;
  AvailableRideModel? currentScheduledRide; // Add this field at root level
  UserPassenger? userPassenger; // User's passenger info if they've joined the ride

  AvailableRidesResponseModel({
    this.remark,
    this.status,
    this.message,
    this.data,
    this.currentScheduledRide,
    this.userPassenger,
  });

  factory AvailableRidesResponseModel.fromJson(Map<String, dynamic> json) =>
      AvailableRidesResponseModel(
        remark: json["remark"],
        status: json["status"],
        message: json["message"] == null
            ? []
            : List<String>.from(json["message"]!.map((x) => x)),
        data: json["data"] == null
            ? null
            : AvailableRidesData.fromJson(json["data"]),
        currentScheduledRide: json["current_scheduled_ride"] == null
            ? null
            : AvailableRideModel.fromJson(
                json["current_scheduled_ride"] as Map<String, dynamic>),
        userPassenger: json["user_passenger"] == null
            ? null
            : UserPassenger.fromJson(
                json["user_passenger"] as Map<String, dynamic>),
      );
}

class AvailableRidesData {
  List<AvailableRideModel>? scheduledRides;
  String? nextPageUrl;
  String? currentPage;
  String? totalPages;
  String? total;
  String? perPage;
  String? from;
  String? to;
  String? lastPage;
  String? firstPageUrl;
  String? lastPageUrl;
  String? path;
  String? prevPageUrl;
  List<dynamic>? links;

  AvailableRidesData({
    this.scheduledRides,
    this.nextPageUrl,
    this.currentPage,
    this.totalPages,
    this.total,
    this.perPage,
    this.from,
    this.to,
    this.lastPage,
    this.firstPageUrl,
    this.lastPageUrl,
    this.path,
    this.prevPageUrl,
    this.links,
  });

  factory AvailableRidesData.fromJson(Map<String, dynamic> json) {
    return AvailableRidesData(
      scheduledRides: json["scheduled_rides"] == null
          ? []
          : List<AvailableRideModel>.from(json["scheduled_rides"]!.map(
              (x) => AvailableRideModel.fromJson(x as Map<String, dynamic>))),
      nextPageUrl: json["next_page_url"],
      currentPage: json["current_page"]?.toString(),
      totalPages: json["total_pages"]?.toString(),
      total: json["total"]?.toString(),
      perPage: json["per_page"]?.toString(),
      from: json["from"]?.toString(),
      to: json["to"]?.toString(),
      lastPage: json["last_page"]?.toString(),
      firstPageUrl: json["first_page_url"],
      lastPageUrl: json["last_page_url"],
      path: json["path"],
      prevPageUrl: json["prev_page_url"],
      links: json["links"],
    );
  }
}

// Response model for join ride
class JoinRideResponseModel {
  String? remark;
  String? status;
  List<String>? message;
  JoinRideData? data;

  JoinRideResponseModel({
    this.remark,
    this.status,
    this.message,
    this.data,
  });

  factory JoinRideResponseModel.fromJson(Map<String, dynamic> json) =>
      JoinRideResponseModel(
        remark: json["remark"],
        status: json["status"],
        message: json["message"] == null
            ? []
            : List<String>.from(json["message"]!.map((x) => x)),
        data: json["data"] == null ? null : JoinRideData.fromJson(json["data"]),
      );
}

class JoinRideData {
  AvailableRideModel? ride;
  PassengerModel? passenger;

  JoinRideData({
    this.ride,
    this.passenger,
  });

  factory JoinRideData.fromJson(Map<String, dynamic> json) => JoinRideData(
        ride: json["ride"] == null
            ? null
            : AvailableRideModel.fromJson(json["ride"]),
        passenger: json["passenger"] == null
            ? null
            : PassengerModel.fromJson(json["passenger"]),
      );
}

// Response model for pending passengers
class PendingPassengersResponseModel {
  String? remark;
  String? status;
  List<String>? message;
  PendingPassengersData? data;

  PendingPassengersResponseModel({
    this.remark,
    this.status,
    this.message,
    this.data,
  });

  factory PendingPassengersResponseModel.fromJson(Map<String, dynamic> json) =>
      PendingPassengersResponseModel(
        remark: json["remark"],
        status: json["status"],
        message: json["message"] == null
            ? []
            : List<String>.from(json["message"]!.map((x) => x)),
        data: json["data"] == null
            ? null
            : PendingPassengersData.fromJson(json["data"]),
      );
}

class PendingPassengersData {
  List<PassengerModel>? passengers;

  PendingPassengersData({
    this.passengers,
  });

  factory PendingPassengersData.fromJson(Map<String, dynamic> json) =>
      PendingPassengersData(
        passengers: json["passengers"] == null
            ? []
            : List<PassengerModel>.from(
                json["passengers"]!.map((x) => PassengerModel.fromJson(x))),
      );
}

// Joined ride model for riders to see their joined rides
/// Similar structure to AvailableRideModel but for joined rides
/// Uses 'scheduled_rides' array with pagination
/// Includes all detailed fields from available rides plus passenger-specific fields
class JoinedRideModel {
  String? id;
  String? driverId;
  String? serviceId;
  String? pickupLocation;
  String? pickupLatitude;
  String? pickupLongitude;
  String? destination;
  String? destinationLatitude;
  String? destinationLongitude;
  String? scheduledDateTime;
  String? numberOfPassengers;
  String? availableSeats;
  String? note;
  String? estimatedFare;
  String? distance;
  String? duration;
  bool? isIntercity;
  String? status;
  String? statusText; // Human-readable status text
  String? cancelReason;
  String? createdAt;
  String? updatedAt;

  // Related models
  GlobalDriverInfo? driver;
  AppService? service;
  List<ScheduledRidePassenger>? passengers;
  bool? canLeave;

  // Additional fields for joined rides (passenger-specific)
  String? passengerId;
  String? seatsBooked;
  String? fare;
  String? passengerStatus;
  String? passengerNote;
  String? pickupLocationPassenger;
  String? pickupLatitudePassenger;
  String? pickupLongitudePassenger;

  // Driver's current location (if provided by API)
  String? driverCurrentLatitude;
  String? driverCurrentLongitude;

  JoinedRideModel({
    this.id,
    this.driverId,
    this.serviceId,
    this.pickupLocation,
    this.pickupLatitude,
    this.pickupLongitude,
    this.destination,
    this.destinationLatitude,
    this.destinationLongitude,
    this.scheduledDateTime,
    this.numberOfPassengers,
    this.availableSeats,
    this.note,
    this.estimatedFare,
    this.distance,
    this.duration,
    this.isIntercity,
    this.status,
    this.statusText,
    this.cancelReason,
    this.createdAt,
    this.updatedAt,
    this.driver,
    this.service,
    this.passengers,
    this.canLeave,
    this.passengerId,
    this.seatsBooked,
    this.fare,
    this.passengerStatus,
    this.passengerNote,
    this.pickupLocationPassenger,
    this.pickupLatitudePassenger,
    this.pickupLongitudePassenger,
    this.driverCurrentLatitude,
    this.driverCurrentLongitude,
  });

  factory JoinedRideModel.fromJson(Map<String, dynamic> json) =>
      JoinedRideModel(
        id: json["id"]?.toString(),
        driverId: json["driver_id"]?.toString(),
        serviceId: json["service_id"]?.toString(),
        pickupLocation: json["pickup_location"]?.toString(),
        pickupLatitude: json["pickup_latitude"]?.toString(),
        pickupLongitude: json["pickup_longitude"]?.toString(),
        destination: json["destination"]?.toString(),
        destinationLatitude: json["destination_latitude"]?.toString(),
        destinationLongitude: json["destination_longitude"]?.toString(),
        scheduledDateTime: json["scheduled_date_time"]?.toString(),
        numberOfPassengers: json["number_of_passengers"]?.toString(),
        availableSeats: json["available_seats"]?.toString(),
        note: json["note"]?.toString(),
        estimatedFare: json["estimated_fare"]?.toString(),
        distance: json["distance"]?.toString(),
        duration: json["duration"]?.toString(),
        isIntercity: json["is_intercity"] == null || json["is_intercity"] == "" 
            ? null 
            : (json["is_intercity"] == "1" || json["is_intercity"] == 1 || json["is_intercity"] == true),
        status: json["status"]?.toString(),
        statusText: json["status_text"]?.toString(),
        cancelReason: json["cancel_reason"]?.toString(),
        createdAt: json["created_at"]?.toString(),
        updatedAt: json["updated_at"]?.toString(),
        driver: json["driver"] == null
            ? null
            : GlobalDriverInfo.fromJson(json["driver"]),
        service: json["service"] == null
            ? null
            : AppService.fromJson(json["service"]),
        passengers: json["passengers"] == null
            ? []
            : List<ScheduledRidePassenger>.from(json["passengers"]!
                .map((x) => ScheduledRidePassenger.fromJson(x))),
        canLeave: json["can_leave"] == null || json["can_leave"] == "" 
            ? null 
            : (json["can_leave"] == "1" || json["can_leave"] == 1 || json["can_leave"] == true),
        // Passenger-specific fields
        passengerId: json["passenger_id"]?.toString(),
        seatsBooked: json["seats_booked"]?.toString(),
        // Check multiple possible fare field names from the API
        fare: json["fare"]?.toString() ??
              json["total_fare"]?.toString() ??
              json["passenger_fare"]?.toString() ??
              json["estimated_fare"]?.toString() ??
              '0',
        passengerStatus: json["passenger_status"]?.toString(),
        passengerNote: json["passenger_note"]?.toString(),
        pickupLocationPassenger: json["pickup_location_passenger"]?.toString(),
        pickupLatitudePassenger: json["pickup_latitude_passenger"]?.toString(),
        pickupLongitudePassenger:
            json["pickup_longitude_passenger"]?.toString(),
        driverCurrentLatitude: json["driver_current_latitude"]?.toString(),
        driverCurrentLongitude: json["driver_current_longitude"]?.toString(),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "driver_id": driverId,
        "service_id": serviceId,
        "pickup_location": pickupLocation,
        "pickup_latitude": pickupLatitude,
        "pickup_longitude": pickupLongitude,
        "destination": destination,
        "destination_latitude": destinationLatitude,
        "destination_longitude": destinationLongitude,
        "scheduled_date_time": scheduledDateTime,
        "number_of_passengers": numberOfPassengers,
        "available_seats": availableSeats,
        "note": note,
        "estimated_fare": estimatedFare,
        "distance": distance,
        "duration": duration,
        "is_intercity": isIntercity,
        "status": status,
        "status_text": statusText,
        "cancel_reason": cancelReason,
        "created_at": createdAt,
        "updated_at": updatedAt,
        "driver": driver?.toJson(),
        "service": service?.toJson(),
        "passengers": passengers,
        "can_leave": canLeave,
        "passenger_id": passengerId,
        "seats_booked": seatsBooked,
        "fare": fare,
        "passenger_status": passengerStatus,
        "passenger_note": passengerNote,
        "pickup_location_passenger": pickupLocationPassenger,
        "pickup_latitude_passenger": pickupLatitudePassenger,
        "pickup_longitude_passenger": pickupLongitudePassenger,
        "driver_current_latitude": driverCurrentLatitude,
        "driver_current_longitude": driverCurrentLongitude,
      };

  // Helper method to calculate fare per seat
  String getFarePerSeat() {
    if (estimatedFare == null || numberOfPassengers == null) return '0';
    
    try {
      double totalFare = double.parse(estimatedFare!);
      int totalSeats = int.parse(numberOfPassengers!);
      
      if (totalSeats == 0) return '0';
      
      double farePerSeat = totalFare / totalSeats;
      return farePerSeat.toStringAsFixed(2);
    } catch (e) {
      return '0';
    }
  }

  // Helper method to calculate fare for specific number of seats
  String calculateFareForSeats(int seats) {
    if (estimatedFare == null || numberOfPassengers == null) return '0';
    
    try {
      double totalFare = double.parse(estimatedFare!);
      int totalSeats = int.parse(numberOfPassengers!);
      
      if (totalSeats == 0) return '0';
      
      double farePerSeat = totalFare / totalSeats;
      double fareForSelectedSeats = farePerSeat * seats;
      return fareForSelectedSeats.toStringAsFixed(2);
    } catch (e) {
      return '0';
    }
  }
}

// Updated response model for joined rides
class JoinedRidesResponseModel {
  String? remark;
  String? status;
  List<String>? message;
  JoinedRidesData? data;
  JoinedRideModel? currentScheduledRide; // Add this field at root level

  JoinedRidesResponseModel({
    this.remark,
    this.status,
    this.message,
    this.data,
    this.currentScheduledRide,
  });

  factory JoinedRidesResponseModel.fromJson(Map<String, dynamic> json) =>
      JoinedRidesResponseModel(
        remark: json["remark"],
        status: json["status"],
        message: json["message"] == null
            ? []
            : List<String>.from(json["message"]!.map((x) => x)),
        data: json["data"] == null
            ? null
            : JoinedRidesData.fromJson(json["data"]),
        currentScheduledRide: json["current_scheduled_ride"] == null
            ? null
            : JoinedRideModel.fromJson(
                json["current_scheduled_ride"] as Map<String, dynamic>),
      );
}

class JoinedRidesData {
  List<JoinedRideModel>? scheduledRides;
  int? currentPage;
  int? totalPages;
  String? nextPageUrl;
  int? total;

  JoinedRidesData({
    this.scheduledRides,
    this.currentPage,
    this.totalPages,
    this.nextPageUrl,
    this.total,
  });

  factory JoinedRidesData.fromJson(Map<String, dynamic> json) =>
      JoinedRidesData(
        scheduledRides: json["scheduled_rides"] == null
            ? []
            : List<JoinedRideModel>.from(json["scheduled_rides"]!.map(
                (x) => JoinedRideModel.fromJson(x as Map<String, dynamic>))),
        currentPage: json["current_page"],
        totalPages: json["total_pages"],
        nextPageUrl: json["next_page_url"],
        total: json["total"],
      );

  Map<String, dynamic> toJson() => {
        "scheduled_rides": scheduledRides == null
            ? []
            : List<dynamic>.from(scheduledRides!.map((x) => x.toJson())),
        "current_page": currentPage,
        "total_pages": totalPages,
        "next_page_url": nextPageUrl,
        "total": total,
      };
}

// Response model for passenger payment
class PassengerPaymentResponseModel {
  String? remark;
  String? status;
  List<String>? message;
  PassengerPaymentData? data;

  PassengerPaymentResponseModel({
    this.remark,
    this.status,
    this.message,
    this.data,
  });

  factory PassengerPaymentResponseModel.fromJson(Map<String, dynamic> json) =>
      PassengerPaymentResponseModel(
        remark: json["remark"],
        status: json["status"],
        message: json["message"] == null
            ? []
            : List<String>.from(json["message"]!.map((x) => x)),
        data: json["data"] == null
            ? null
            : PassengerPaymentData.fromJson(json["data"]),
      );
}

class PassengerPaymentData {
  PassengerModel? passenger;

  PassengerPaymentData({
    this.passenger,
  });

  factory PassengerPaymentData.fromJson(Map<String, dynamic> json) =>
      PassengerPaymentData(
        passenger: json["passenger"] == null
            ? null
            : PassengerModel.fromJson(json["passenger"]),
      );
}

// Response model for detailed scheduled ride information
class ScheduledRideDetailsResponseModel {
  String? remark;
  String? status;
  List<String>? message;
  ScheduledRideDetailsData? data;

  ScheduledRideDetailsResponseModel({
    this.remark,
    this.status,
    this.message,
    this.data,
  });

  factory ScheduledRideDetailsResponseModel.fromJson(
          Map<String, dynamic> json) =>
      ScheduledRideDetailsResponseModel(
        remark: json["remark"],
        status: json["status"],
        message: json["message"] == null
            ? []
            : List<String>.from(json["message"]!.map((x) => x)),
        data: json["data"] == null
            ? null
            : ScheduledRideDetailsData.fromJson(json["data"]),
      );
}

class ScheduledRideDetailsData {
  String? id;
  String? pickupLocation;
  String? destination;
  String? scheduledDateTime;
  String? numberOfPassengers;
  String? availableSeats;
  String? estimatedFare;
  GlobalDriverInfo? driver;
  AppService? service;

  ScheduledRideDetailsData({
    this.id,
    this.pickupLocation,
    this.destination,
    this.scheduledDateTime,
    this.numberOfPassengers,
    this.availableSeats,
    this.estimatedFare,
    this.driver,
    this.service,
  });

  factory ScheduledRideDetailsData.fromJson(Map<String, dynamic> json) =>
      ScheduledRideDetailsData(
        id: json["id"]?.toString(),
        pickupLocation: json["pickup_location"]?.toString(),
        destination: json["destination"]?.toString(),
        scheduledDateTime: json["scheduled_date_time"]?.toString(),
        numberOfPassengers: json["number_of_passengers"]?.toString(),
        availableSeats: json["available_seats"]?.toString(),
        estimatedFare: json["estimated_fare"]?.toString(),
        driver: json["driver"] == null
            ? null
            : GlobalDriverInfo.fromJson(json["driver"]),
        service: json["service"] == null
            ? null
            : AppService.fromJson(json["service"]),
      );
}

// Response model for join scheduled ride
class JoinScheduledRideResponseModel {
  String? remark;
  String? status;
  List<String>? message;
  JoinScheduledRideData? data;

  JoinScheduledRideResponseModel({
    this.remark,
    this.status,
    this.message,
    this.data,
  });

  factory JoinScheduledRideResponseModel.fromJson(Map<String, dynamic> json) =>
      JoinScheduledRideResponseModel(
        remark: json["remark"],
        status: json["status"],
        message: json["message"] == null
            ? []
            : List<String>.from(json["message"]!.map((x) => x)),
        data: json["data"] == null
            ? null
            : JoinScheduledRideData.fromJson(json["data"]),
      );
}

class JoinScheduledRideData {
  ScheduledRidePassenger? passenger;
  String? totalFare;
  String? farePerSeat;

  JoinScheduledRideData({
    this.passenger,
    this.totalFare,
    this.farePerSeat,
  });

  factory JoinScheduledRideData.fromJson(Map<String, dynamic> json) =>
      JoinScheduledRideData(
        passenger: json["passenger"] == null
            ? null
            : ScheduledRidePassenger.fromJson(json["passenger"]),
        totalFare: json["total_fare"]?.toString(),
        farePerSeat: json["fare_per_seat"]?.toString(),
      );
}

// Passenger model for scheduled ride join response
class ScheduledRidePassenger {
  String? id;
  String? scheduledRideId;
  String? userId;
  String? seatsBooked;
  String? status;
  String? farePerSeat;
  String? pickupStatus;
  String? pickupLocation;
  String? pickupLatitude;
  String? pickupLongitude;
  ScheduledRideUser? user;

  ScheduledRidePassenger({
    this.id,
    this.scheduledRideId,
    this.userId,
    this.seatsBooked,
    this.status,
    this.farePerSeat,
    this.pickupStatus,
    this.pickupLocation,
    this.pickupLatitude,
    this.pickupLongitude,
    this.user,
  });

  factory ScheduledRidePassenger.fromJson(Map<String, dynamic> json) =>
      ScheduledRidePassenger(
        id: json["id"]?.toString(),
        scheduledRideId: json["scheduled_ride_id"]?.toString(),
        userId: json["user_id"]?.toString(),
        seatsBooked: json["seats_booked"]?.toString(),
        status: json["status"]?.toString(),
        farePerSeat: json["fare_per_seat"]?.toString(),
        pickupStatus: json["pickup_status"]?.toString(),
        pickupLocation: json["pickup_location"]?.toString(),
        pickupLatitude: json["pickup_latitude"]?.toString(),
        pickupLongitude: json["pickup_longitude"]?.toString(),
        user: json["user"] == null
            ? null
            : ScheduledRideUser.fromJson(json["user"]),
      );
}

// User model for scheduled ride passenger
class ScheduledRideUser {
  String? id;
  String? firstname;
  String? lastname;

  ScheduledRideUser({
    this.id,
    this.firstname,
    this.lastname,
  });

  factory ScheduledRideUser.fromJson(Map<String, dynamic> json) =>
      ScheduledRideUser(
        id: json["id"]?.toString(),
        firstname: json["firstname"]?.toString(),
        lastname: json["lastname"]?.toString(),
      );
}

// Response model for leave scheduled ride
class LeaveScheduledRideResponseModel {
  String? remark;
  String? status;
  List<String>? message;

  LeaveScheduledRideResponseModel({
    this.remark,
    this.status,
    this.message,
  });

  factory LeaveScheduledRideResponseModel.fromJson(Map<String, dynamic> json) =>
      LeaveScheduledRideResponseModel(
        remark: json["remark"],
        status: json["status"],
        message: json["message"] == null
            ? []
            : List<String>.from(json["message"]!.map((x) => x)),
      );
}

// Response model for cash payment
class CashPaymentResponseModel {
  String? remark;
  String? status;
  List<String>? message;
  CashPaymentData? data;

  CashPaymentResponseModel({
    this.remark,
    this.status,
    this.message,
    this.data,
  });

  factory CashPaymentResponseModel.fromJson(Map<String, dynamic> json) =>
      CashPaymentResponseModel(
        remark: json["remark"],
        status: json["status"],
        message: json["message"] == null
            ? []
            : List<String>.from(json["message"]!.map((x) => x)),
        data: json["data"] == null
            ? null
            : CashPaymentData.fromJson(json["data"]),
      );
}

class CashPaymentData {
  ScheduledRidePassenger? passenger;
  String? amountPaid;
  String? paymentMethod;

  CashPaymentData({
    this.passenger,
    this.amountPaid,
    this.paymentMethod,
  });

  factory CashPaymentData.fromJson(Map<String, dynamic> json) =>
      CashPaymentData(
        passenger: json["passenger"] == null
            ? null
            : ScheduledRidePassenger.fromJson(json["passenger"]),
        amountPaid: json["amount_paid"]?.toString(),
        paymentMethod: json["payment_method"]?.toString(),
      );
}

// Response model for stripe checkout
class StripeCheckoutResponseModel {
  String? remark;
  String? status;
  List<String>? message;
  StripeCheckoutData? data;

  StripeCheckoutResponseModel({
    this.remark,
    this.status,
    this.message,
    this.data,
  });

  factory StripeCheckoutResponseModel.fromJson(Map<String, dynamic> json) =>
      StripeCheckoutResponseModel(
        remark: json["remark"],
        status: json["status"],
        message: json["message"] == null
            ? []
            : List<String>.from(json["message"]!.map((x) => x)),
        data: json["data"] == null
            ? null
            : StripeCheckoutData.fromJson(json["data"]),
      );
}

class StripeCheckoutData {
  String? checkoutUrl;
  String? sessionId;
  String? amount;
  ScheduledRidePassenger? passenger;

  StripeCheckoutData({
    this.checkoutUrl,
    this.sessionId,
    this.amount,
    this.passenger,
  });

  factory StripeCheckoutData.fromJson(Map<String, dynamic> json) =>
      StripeCheckoutData(
        checkoutUrl: json["checkout_url"]?.toString(),
        sessionId: json["session_id"]?.toString(),
        amount: json["amount"]?.toString(),
        passenger: json["passenger"] == null
            ? null
            : ScheduledRidePassenger.fromJson(json["passenger"]),
      );
}

// User passenger model for when user has joined a scheduled ride
class UserPassenger {
  String? id;
  String? seatsBooked;
  String? farePerSeat;
  String? totalFare;
  String? status;  // 0: pending, 1: confirmed/approved, 2: completed
  String? pickupStatus;  // null, picked_up, etc.
  String? statusText;
  String? note;
  String? confirmedAt;
  String? createdAt;
  String? pickupLocation;
  String? pickupLatitude;
  String? pickupLongitude;

  UserPassenger({
    this.id,
    this.seatsBooked,
    this.farePerSeat,
    this.totalFare,
    this.status,
    this.pickupStatus,
    this.statusText,
    this.note,
    this.confirmedAt,
    this.createdAt,
    this.pickupLocation,
    this.pickupLatitude,
    this.pickupLongitude,
  });

  factory UserPassenger.fromJson(Map<String, dynamic> json) =>
      UserPassenger(
        id: json["id"]?.toString(),
        seatsBooked: json["seats_booked"]?.toString(),
        farePerSeat: json["fare_per_seat"]?.toString(),
        totalFare: json["total_fare"]?.toString(),
        status: json["status"]?.toString(),
        pickupStatus: json["pickup_status"]?.toString(),
        statusText: json["status_text"]?.toString(),
        note: json["note"]?.toString(),
        confirmedAt: json["confirmed_at"]?.toString(),
        createdAt: json["created_at"]?.toString(),
        pickupLocation: json["pickup_location"]?.toString(),
        pickupLatitude: json["pickup_latitude"]?.toString(),
        pickupLongitude: json["pickup_longitude"]?.toString(),
      );

  bool get isApproved => status == "1";
  bool get isPending => status == "0";
  bool get isCompleted => status == "2";
  bool get isPickedUp => pickupStatus != null && pickupStatus!.isNotEmpty;

  /// Check if passenger is actively part of an ongoing ride
  /// Returns true for any status that means passenger can track the ride
  /// Passenger statuses: 0=pending, 1=approved, 2=completed, 3=cancelled, 5=in_progress/on_way
  bool get isActivePassenger {
    // Active if approved (1) or in_progress/on_way (5) or any status > 0 that's not completed/cancelled
    int? statusInt = int.tryParse(status ?? '0');
    if (statusInt == null) return false;

    // Not active if: pending(0), completed(2), cancelled(3)
    // Active if: approved(1), in_progress(4, 5), etc.
    return statusInt == 1 || statusInt == 4 || statusInt == 5;
  }
}
