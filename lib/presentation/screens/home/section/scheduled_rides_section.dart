import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovorideuser/core/utils/dimensions.dart';
import 'package:ovorideuser/core/utils/my_color.dart';
import 'package:ovorideuser/core/utils/style.dart';
import 'package:ovorideuser/presentation/screens/scheduled_rides/scheduled_rides_screen.dart';

class ScheduledRidesSection extends StatelessWidget {
  const ScheduledRidesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: Dimensions.space15, vertical: Dimensions.space10),
      decoration: BoxDecoration(
        color: MyColor.colorWhite,
        borderRadius: BorderRadius.circular(Dimensions.space12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => Get.to(() => const ScheduledRidesScreen()),
        borderRadius: BorderRadius.circular(Dimensions.space12),
        child: Padding(
          padding: const EdgeInsets.all(Dimensions.space20),
          child: Row(
            children: [
              // Icon Container
              Container(
                width: 60,
                height: 60,
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
                  Icons.schedule,
                  color: MyColor.primaryColor,
                  size: 30,
                ),
              ),

              const SizedBox(width: Dimensions.space20),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scheduled Rides',
                      style: boldDefault.copyWith(
                        color: MyColor.getRideTitleColor(),
                        fontSize: Dimensions.fontLarge,
                      ),
                    ),
                    const SizedBox(height: Dimensions.space8),
                    Text(
                      'Join scheduled rides and save money',
                      style: regularDefault.copyWith(
                        color: Colors.grey[600],
                        fontSize: Dimensions.fontMedium,
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow Icon
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[400],
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
