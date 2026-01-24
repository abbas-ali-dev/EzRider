import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovorideuser/core/utils/dimensions.dart';
import 'package:ovorideuser/core/utils/my_color.dart';
import 'package:ovorideuser/core/utils/style.dart';
import 'package:ovorideuser/data/controller/scheduled_ride/scheduled_ride_controller.dart';
import 'package:ovorideuser/data/model/scheduled_ride/scheduled_ride_model.dart';
import 'package:ovorideuser/presentation/components/divider/custom_spacer.dart';

void showPaymentBottomSheet(
  BuildContext context,
  ScheduledRideController controller,
  UserPassenger? userPassengerInfo,
  String? rideId,
) {
  Get.bottomSheet(
    Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          
          spaceDown(20),
          
          // Title
          Text(
            'Cash Payment',
            style: boldLarge.copyWith(
              fontSize: Dimensions.fontExtraLarge,
              color: MyColor.colorBlack,
            ),
          ),
          
          spaceDown(24),
          
          // Amount section
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: MyColor.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: MyColor.primaryColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Total Amount:',
                  style: regularDefault.copyWith(
                    color: Colors.grey[700],
                    fontSize: Dimensions.fontDefault,
                  ),
                ),
                spaceDown(8),
                Text(
                  '\$${userPassengerInfo?.totalFare ?? '0'}',
                  style: boldLarge.copyWith(
                    color: MyColor.primaryColor,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          spaceDown(24),
          
          // Message
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Please confirm that you have paid the driver in cash.',
              style: regularDefault.copyWith(
                color: Colors.grey[600],
                fontSize: Dimensions.fontDefault,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          spaceDown(32),
          
          // Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Get.back(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: boldDefault.copyWith(
                        color: Colors.grey[700],
                        fontSize: Dimensions.fontDefault,
                      ),
                    ),
                  ),
                ),
                spaceSide(12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      Get.back();
                      // Process payment using scheduled ride cash payment API
                      if (userPassengerInfo?.id != null && rideId != null) {
                        // Parse the total fare as double
                        double amount = double.tryParse(userPassengerInfo?.totalFare ?? '0') ?? 0;
                        controller.makeScheduledRideCashPayment(
                          rideId,
                          userPassengerInfo!.id!,
                          amount,
                          null, // No note for simple payment dialog
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MyColor.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Confirm Payment',
                      style: boldDefault.copyWith(
                        color: Colors.white,
                        fontSize: Dimensions.fontDefault,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          spaceDown(32),
        ],
      ),
    ),
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    enableDrag: true,
  );
}
