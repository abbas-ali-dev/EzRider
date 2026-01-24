import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ovorideuser/core/helper/shared_preference_helper.dart';
import 'package:ovorideuser/core/helper/string_format_helper.dart';
import 'package:ovorideuser/core/utils/dimensions.dart';
import 'package:ovorideuser/core/utils/my_color.dart';
import 'package:ovorideuser/core/utils/style.dart';
import 'package:ovorideuser/data/controller/scheduled_ride/scheduled_ride_controller.dart';
import 'package:ovorideuser/data/model/scheduled_ride/scheduled_ride_model.dart';
import 'package:ovorideuser/presentation/components/app-bar/custom_appbar.dart';
import 'package:ovorideuser/presentation/components/divider/custom_spacer.dart';
import 'package:ovorideuser/presentation/components/text/header_text.dart';
import 'package:ovorideuser/presentation/components/text-form-field/custom_text_field.dart';
import 'package:ovorideuser/presentation/components/snack_bar/show_custom_snackbar.dart';

class PaymentScreen extends StatefulWidget {
  final JoinedRideModel passenger;
  final AvailableRideModel ride;

  const PaymentScreen({
    super.key,
    required this.passenger,
    required this.ride,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final TextEditingController amountController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // Set default amount
    amountController.text = widget.passenger.fare ?? '0';

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
    amountController.dispose();
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyColor.screenBgColor,
      appBar: CustomAppBar(
        title: 'Payment',
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

                    // Payment Details (Cash Only)
                    _buildPaymentDetails(controller),
                    spaceDown(Dimensions.space30),

                    // Payment Button
                    _buildPaymentButton(controller),
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
          HeaderText(
            text: 'Ride Summary',
            textStyle: boldLarge.copyWith(
              color: MyColor.getRideTitleColor(),
              fontWeight: FontWeight.w600,
              fontSize: Dimensions.fontOverLarge,
            ),
          ),
          spaceDown(Dimensions.space20),

          // Route Information
          _buildLocationRow(
            Icons.location_on,
            'Pickup',
            widget.ride.pickupLocation ?? 'Not specified',
            Colors.green,
          ),
          spaceDown(Dimensions.space15),
          _buildLocationRow(
            Icons.location_on_outlined,
            'Destination',
            widget.ride.destination ?? 'Not specified',
            Colors.red,
          ),

          spaceDown(Dimensions.space20),

          // Ride Details
          Container(
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
                    'Date & Time',
                    controller.formatDateTime(widget.ride.scheduledDateTime),
                  ),
                ),
                Expanded(
                  child: _buildDetailItem(
                    Icons.attach_money,
                    'Total Fare',
                    '\$${widget.passenger.fare ?? '0'}',
                    isFare: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentDetails(ScheduledRideController controller) {
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
            text: 'Cash Payment',
            textStyle: boldLarge.copyWith(
              color: MyColor.getRideTitleColor(),
              fontWeight: FontWeight.w600,
              fontSize: Dimensions.fontOverLarge,
            ),
          ),
          spaceDown(Dimensions.space15),

          // Cash payment info
          Container(
            padding: const EdgeInsets.all(Dimensions.space12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(Dimensions.mediumRadius),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.green, size: 20),
                spaceSide(Dimensions.space10),
                Expanded(
                  child: Text(
                    'Please pay the fare amount in cash to the driver',
                    style: regularSmall.copyWith(color: Colors.green[700]),
                  ),
                ),
              ],
            ),
          ),
          spaceDown(Dimensions.space20),

          // Amount Field
          CustomTextField(
            controller: amountController,
            labelText: 'Amount to Pay',
            hintText: 'Enter amount',
            onChanged: (value) {},
            prefixIcon: Icon(Icons.attach_money, color: MyColor.primaryColor),
          ),
          spaceDown(Dimensions.space15),

          // Note Field
          CustomTextField(
            controller: noteController,
            labelText: 'Payment Note (Optional)',
            hintText: 'Add any notes about the payment...',
            maxLines: 3,
            onChanged: (value) {},
            prefixIcon: Icon(Icons.note, color: MyColor.primaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentButton(ScheduledRideController controller) {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green,
            Colors.green.withValues(alpha: 0.8)
          ],
        ),
        borderRadius: BorderRadius.circular(Dimensions.mediumRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.3),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextButton(
        onPressed: controller.isProcessingCashPayment
            ? null
            : () => _processPayment(controller),
        child: controller.isProcessingCashPayment
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.money, color: Colors.white, size: 22),
                  spaceSide(Dimensions.space10),
                  Text(
                    'Confirm Cash Payment',
                    style: boldDefault.copyWith(
                      color: Colors.white,
                      fontSize: Dimensions.fontLarge,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _processPayment(ScheduledRideController controller) {
    final amount = double.tryParse(amountController.text) ?? 0.0;
    if (amount <= 0) {
      CustomSnackBar.error(errorList: ['Please enter a valid amount']);
      return;
    }

    // Find the correct passenger pivot ID from the passengers array
    String? passengerPivotId = _findCurrentUserPassengerId();

    passengerPivotId ??= widget.passenger.passengerId;

    if (passengerPivotId == null || passengerPivotId.isEmpty) {
      CustomSnackBar.error(errorList: ['Unable to find passenger information. Please try again.']);
      printX('Error: Could not find passenger pivot ID');
      printX('passengerId from model: ${widget.passenger.passengerId}');
      printX('passengers array length: ${widget.passenger.passengers?.length ?? 0}');
      return;
    }

    printX('Processing payment with:');
    printX('  Ride ID: ${widget.ride.id}');
    printX('  Passenger Pivot ID: $passengerPivotId');
    printX('  Amount: $amount');

    controller.makeScheduledRideCashPayment(
      widget.ride.id!,
      passengerPivotId,
      amount,
      noteController.text.isNotEmpty ? noteController.text : null,
    );
  }

  /// Find the current user's passenger pivot table ID from the passengers array
  String? _findCurrentUserPassengerId() {
    try {
      // Get current user ID from SharedPreferences
      final prefs = Get.find<SharedPreferences>();
      final currentUserId = prefs.getString(SharedPreferenceHelper.userIdKey);

      printX('Looking for current user passenger. User ID: $currentUserId');
      printX('Passengers in ride: ${widget.passenger.passengers?.length ?? 0}');

      if (currentUserId == null || currentUserId.isEmpty) {
        printX('Warning: Current user ID is null or empty');
        return null;
      }

      // Check if passengers array exists and has data
      if (widget.passenger.passengers == null || widget.passenger.passengers!.isEmpty) {
        printX('Warning: No passengers array in ride data');
        return null;
      }

      // Find the passenger that matches the current user
      for (var passenger in widget.passenger.passengers!) {
        printX('Checking passenger - ID: ${passenger.id}, UserID: ${passenger.userId}, User.ID: ${passenger.user?.id}');

        // Check both userId field and nested user.id
        if (passenger.userId == currentUserId || passenger.user?.id == currentUserId) {
          printX('Found matching passenger! Pivot ID: ${passenger.id}');
          return passenger.id;
        }
      }

      printX('Warning: Current user not found in passengers array');
      return null;
    } catch (e) {
      printX('Error finding passenger ID: $e');
      return null;
    }
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
            fontSize: 11,
          ),
        ),
        spaceDown(Dimensions.space4),
        Text(
          value,
          style: regularDefault.copyWith(
            color: isFare ? MyColor.primaryColor : MyColor.colorBlack,
            fontWeight: isFare ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
