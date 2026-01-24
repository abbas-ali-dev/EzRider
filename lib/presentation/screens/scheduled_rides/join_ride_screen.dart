import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovorideuser/core/utils/dimensions.dart';
import 'package:ovorideuser/core/utils/my_color.dart';
import 'package:ovorideuser/core/utils/style.dart';
import 'package:ovorideuser/data/controller/scheduled_ride/scheduled_ride_controller.dart';
import 'package:ovorideuser/data/model/location/selected_location_info.dart';
import 'package:ovorideuser/data/model/scheduled_ride/scheduled_ride_model.dart';
import 'package:ovorideuser/presentation/components/app-bar/custom_appbar.dart';
import 'package:ovorideuser/presentation/components/divider/custom_spacer.dart';
import 'package:ovorideuser/presentation/components/text/header_text.dart';
import 'package:ovorideuser/presentation/components/text-form-field/custom_text_field.dart';
import 'package:ovorideuser/presentation/screens/scheduled_rides/pickup_location_picker_screen.dart';

class JoinRideScreen extends StatefulWidget {
  final AvailableRideModel ride;
  const JoinRideScreen({super.key, required this.ride});

  @override
  State<JoinRideScreen> createState() => _JoinRideScreenState();
}

class _JoinRideScreenState extends State<JoinRideScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Clear previous form data after the frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = Get.find<ScheduledRideController>();
      controller.clearJoinForm();
    });

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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyColor.screenBgColor,
      appBar: CustomAppBar(
        title: 'Join Ride',
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(Dimensions.space15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ride Summary Card
                    _buildRideSummaryCard(controller),
                    spaceDown(Dimensions.space25),

                    // Join Form
                    _buildJoinForm(controller),
                    spaceDown(Dimensions.space30),

                    // Submit Button
                    _buildSubmitButton(controller),
                    spaceDown(Dimensions.space20),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRideSummaryCard(ScheduledRideController controller) {
    return Container(
      padding: const EdgeInsets.all(Dimensions.space20),
      decoration: BoxDecoration(
        color: MyColor.colorWhite,
        borderRadius: BorderRadius.circular(Dimensions.largeRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            spreadRadius: 1,
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      MyColor.primaryColor.withValues(alpha: 0.1),
                      MyColor.primaryColor.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(Dimensions.mediumRadius),
                ),
                child: Icon(
                  Icons.directions_car,
                  color: MyColor.primaryColor,
                  size: 25,
                ),
              ),
              spaceSide(Dimensions.space15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.ride.service?.name ?? 'Unknown Service',
                      style: boldDefault.copyWith(
                        color: MyColor.colorBlack,
                        fontSize: Dimensions.fontLarge,
                      ),
                    ),
                    Text(
                      'Ride #${widget.ride.id}',
                      style: regularSmall.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          spaceDown(Dimensions.space20),

          // Route Information
          _buildRouteInfo(),

          spaceDown(Dimensions.space20),

          // Ride Details
          _buildRideDetails(),
        ],
      ),
    );
  }

  Widget _buildRouteInfo() {
    return Column(
      children: [
        _buildLocationRow(
          Icons.location_on,
          'Pickup',
          widget.ride.pickupLocation ?? 'Not specified',
          Colors.green,
        ),
        spaceDown(Dimensions.space15),
        Container(
          margin: const EdgeInsets.only(left: 20),
          height: 20,
          width: 2,
          color: Colors.grey[300],
        ),
        spaceDown(Dimensions.space15),
        _buildLocationRow(
          Icons.location_on_outlined,
          'Destination',
          widget.ride.destination ?? 'Not specified',
          Colors.red,
        ),
      ],
    );
  }

  Widget _buildLocationRow(
      IconData icon, String label, String address, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(Dimensions.space6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        spaceSide(Dimensions.space12),
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
              spaceDown(Dimensions.space4),
              Text(
                address,
                style: regularDefault.copyWith(
                  color: MyColor.colorBlack,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRideDetails() {
    return Container(
      padding: const EdgeInsets.all(Dimensions.space15),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(Dimensions.mediumRadius),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildDetailItem(
              Icons.schedule,
              'Start Time',
              widget.ride.scheduledDateTime != null
                  ? _formatDateTime(widget.ride.scheduledDateTime!)
                  : 'Not specified',
            ),
          ),
          Expanded(
            child: _buildDetailItem(
              Icons.people,
              'Available Seats',
              '${_getAvailableSeats()}',
            ),
          ),
          Expanded(
            child: _buildDetailItem(
              Icons.attach_money,
              'Fare/Seat',
              '\$${widget.ride.getFarePerSeat()}',
              isFare: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value,
      {bool isFare = false}) {
    return Column(
      children: [
        Icon(
          icon,
          color: isFare ? MyColor.primaryColor : Colors.grey[600],
          size: 20,
        ),
        spaceDown(Dimensions.space8),
        Text(
          label,
          style: regularSmall.copyWith(
            color: Colors.grey[600],
            fontSize: 10,
          ),
          textAlign: TextAlign.center,
        ),
        spaceDown(Dimensions.space4),
        Text(
          value,
          style: regularDefault.copyWith(
            color: isFare ? MyColor.primaryColor : MyColor.colorBlack,
            fontWeight: isFare ? FontWeight.w600 : FontWeight.normal,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildJoinForm(ScheduledRideController controller) {
    return Container(
      padding: const EdgeInsets.all(Dimensions.space20),
      decoration: BoxDecoration(
        color: MyColor.colorWhite,
        borderRadius: BorderRadius.circular(Dimensions.largeRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            spreadRadius: 1,
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HeaderText(
            text: 'Join Scheduled Ride',
            textStyle: boldLarge.copyWith(
              color: MyColor.getRideTitleColor(),
              fontWeight: FontWeight.w600,
              fontSize: Dimensions.fontOverLarge,
            ),
          ),
          spaceDown(Dimensions.space20),

          // Pickup Location Field
          _buildPickupLocationField(controller),

          spaceDown(Dimensions.space20),

          // Seats Booked Field
          _buildSeatsBookedField(controller),

          spaceDown(Dimensions.space20),

          // Note Field
          CustomTextField(
            controller: controller.noteController,
            labelText: 'Note (Optional)',
            hintText: 'Add any special requirements or notes...',
            maxLines: 3,
            onChanged: (value) {},
            prefixIcon: Icon(Icons.note, color: MyColor.primaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildPickupLocationField(ScheduledRideController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pickup Location *',
          style: boldDefault.copyWith(
            color: MyColor.colorBlack,
            fontSize: Dimensions.fontDefault,
          ),
        ),
        spaceDown(Dimensions.space8),
        InkWell(
          onTap: () async {
            // Navigate to the new pickup location picker
            var result = await Get.to(
              () => const PickupLocationPickerScreen(),
              transition: Transition.cupertino,
            );

            if (result != null && result is SelectedLocationInfo) {
              controller.pickupLocationInfo = result;
              controller.showLocationError = false;
              controller.update();
            }
          },
          child: Container(
            padding: const EdgeInsets.all(Dimensions.space15),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(Dimensions.defaultRadius),
              color: Colors.grey.shade50,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: controller.pickupLocationInfo != null
                      ? MyColor.primaryColor
                      : Colors.grey,
                ),
                spaceSide(Dimensions.space10),
                Expanded(
                  child: Text(
                    controller.pickupLocationInfo != null
                        ? controller.pickupLocationInfo!.getFullAddress(showFull: true)
                        : 'Tap to select pickup location',
                    style: regularDefault.copyWith(
                      color: controller.pickupLocationInfo != null
                          ? MyColor.colorBlack
                          : Colors.grey[600],
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
        if (controller.pickupLocationInfo == null && controller.showLocationError)
          Padding(
            padding: const EdgeInsets.only(top: Dimensions.space8),
            child: Text(
              'Please select a pickup location',
              style: regularSmall.copyWith(
                color: Colors.red,
                fontSize: Dimensions.fontSmall,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSeatsBookedField(ScheduledRideController controller) {
    int availableSeats = _getAvailableSeats();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Number of Seats',
          style: boldDefault.copyWith(
            color: MyColor.colorBlack,
            fontSize: Dimensions.fontDefault,
          ),
        ),
        spaceDown(Dimensions.space8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: Dimensions.space15),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(Dimensions.defaultRadius),
          ),
          child: DropdownButtonFormField<int>(
            value: controller.seatsBooked ?? 1,
            decoration: const InputDecoration(
              border: InputBorder.none,
              prefixIcon:
                  Icon(Icons.airline_seat_recline_normal, color: Colors.grey),
            ),
            items: List.generate(availableSeats, (index) {
              int seatCount = index + 1;
              return DropdownMenuItem<int>(
                value: seatCount,
                child: Text(
                  '$seatCount seat${seatCount > 1 ? 's' : ''}',
                  style: regularDefault.copyWith(color: MyColor.colorBlack),
                ),
              );
            }),
            onChanged: (value) {
              controller.seatsBooked = value;
              controller.update();
            },
          ),
        ),
        spaceDown(Dimensions.space8),
        Text(
          'Available seats: $availableSeats',
          style: regularSmall.copyWith(
            color: Colors.grey[600],
            fontSize: Dimensions.fontSmall,
          ),
        ),
        spaceDown(Dimensions.space12),
        // Show calculated fare for selected seats
        Container(
          padding: const EdgeInsets.all(Dimensions.space12),
          decoration: BoxDecoration(
            color: MyColor.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(Dimensions.defaultRadius),
            border: Border.all(
              color: MyColor.primaryColor.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Fare for ${controller.seatsBooked ?? 1} seat${(controller.seatsBooked ?? 1) > 1 ? 's' : ''}:',
                style: boldDefault.copyWith(
                  color: MyColor.colorBlack,
                  fontSize: Dimensions.fontDefault,
                ),
              ),
              Text(
                '\$${widget.ride.calculateFareForSeats(controller.seatsBooked ?? 1)}',
                style: boldLarge.copyWith(
                  color: MyColor.primaryColor,
                  fontSize: Dimensions.fontLarge,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildSubmitButton(ScheduledRideController controller) {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            MyColor.primaryColor,
            MyColor.primaryColor.withValues(alpha: 0.8)
          ],
        ),
        borderRadius: BorderRadius.circular(Dimensions.mediumRadius),
        boxShadow: [
          BoxShadow(
            color: MyColor.primaryColor.withValues(alpha: 0.3),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextButton(
        onPressed:
            controller.isJoining ? null : () => _joinScheduledRide(controller),
        child: controller.isJoining
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                'Join Scheduled Ride',
                style: boldDefault.copyWith(
                  color: Colors.white,
                  fontSize: Dimensions.fontLarge,
                ),
              ),
      ),
    );
  }

  void _joinScheduledRide(ScheduledRideController controller) {
    // Validate pickup location
    if (controller.pickupLocationInfo == null) {
      controller.showLocationError = true;
      controller.update();
      Get.snackbar(
        'Error',
        'Please select your pickup location',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    if (controller.seatsBooked == null) {
      Get.snackbar(
        'Error',
        'Please select number of seats',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    // Call the updated join method with pickup location
    controller.joinScheduledRideWithLocation(
      widget.ride.id!,
      '${controller.seatsBooked!}',
      controller.noteController.text.isNotEmpty
          ? controller.noteController.text
          : null,
    );
  }

  String _formatDateTime(String dateTime) {
    try {
      DateTime dt = DateTime.parse(dateTime);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTime;
    }
  }

  int _getAvailableSeats() {
    int totalSeats = int.tryParse(widget.ride.numberOfPassengers ?? '0') ?? 0;
    int occupiedSeats = widget.ride.passengers?.length ?? 0;
    return totalSeats - occupiedSeats;
  }
}
