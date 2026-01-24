import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovorideuser/core/utils/dimensions.dart';
import 'package:ovorideuser/core/utils/my_color.dart';
import 'package:ovorideuser/core/utils/style.dart';
import 'package:ovorideuser/data/controller/scheduled_ride/scheduled_ride_controller.dart';
import 'package:ovorideuser/data/model/scheduled_ride/scheduled_ride_model.dart';
import 'package:ovorideuser/presentation/components/app-bar/custom_appbar.dart';
import 'package:ovorideuser/presentation/components/divider/custom_spacer.dart';
import 'package:ovorideuser/presentation/components/text/header_text.dart';
import 'package:ovorideuser/presentation/screens/scheduled_rides/payment_screen.dart';

class JoinedRidesScreen extends StatefulWidget {
  const JoinedRidesScreen({super.key});

  @override
  State<JoinedRidesScreen> createState() => _JoinedRidesScreenState();
}

class _JoinedRidesScreenState extends State<JoinedRidesScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Set default filter to 'all' for joined rides screen
    Future.delayed(Duration.zero, () {
      final controller = Get.find<ScheduledRideController>();
      controller.selectedFilter = 'all';
      controller.update();
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
        title: 'My Joined Rides',
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
                  // Filter Tabs
                  _buildFilterTabs(controller),

                  // Joined Rides List
                  Expanded(
                    child: controller.joinedRides.isEmpty
                        ? _buildEmptyState()
                        : _buildJoinedRidesList(controller),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterTabs(ScheduledRideController controller) {
    return Container(
      margin: const EdgeInsets.all(Dimensions.space15),
      decoration: BoxDecoration(
        color: MyColor.colorWhite,
        borderRadius: BorderRadius.circular(Dimensions.largeRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(Dimensions.space4),
        child: Row(
          children: [
            _buildFilterTab(controller, 'All', 'all', Icons.list_alt),
            _buildFilterTab(controller, 'Pending', 'pending', Icons.schedule),
            _buildFilterTab(
                controller, 'Approved', 'approved', Icons.check_circle_outline),
            _buildFilterTab(
                controller, 'Completed', 'completed', Icons.done_all),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTab(ScheduledRideController controller, String title,
      String status, IconData icon) {
    bool isSelected = controller.selectedFilter == status;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          controller.selectedFilter = status;
          controller.update();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(
              vertical: Dimensions.space12, horizontal: Dimensions.space8),
          decoration: BoxDecoration(
            color: isSelected ? MyColor.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(Dimensions.mediumRadius),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey[600],
                size: 20,
              ),
              spaceDown(Dimensions.space4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: regularSmall.copyWith(
                  color: isSelected ? Colors.white : MyColor.colorBlack,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(Dimensions.space30),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_outline,
              size: 80,
              color: Colors.blue.withValues(alpha: 0.7),
            ),
          ),
          spaceDown(Dimensions.space25),
          HeaderText(
            text: 'No Joined Rides',
            textStyle: boldLarge.copyWith(
              color: MyColor.colorBlack,
              fontSize: Dimensions.fontOverLarge,
            ),
          ),
          spaceDown(Dimensions.space15),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Dimensions.space30),
            child: Text(
              'You haven\'t joined any rides yet.\nBrowse available rides and join them to start your journey.',
              textAlign: TextAlign.center,
              style: regularDefault.copyWith(
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
          ),
          spaceDown(Dimensions.space30),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.space20,
              vertical: Dimensions.space10,
            ),
            decoration: BoxDecoration(
              color: MyColor.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(Dimensions.mediumRadius),
              border: Border.all(
                color: MyColor.primaryColor.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.info_outline,
                  color: MyColor.primaryColor,
                  size: 20,
                ),
                spaceSide(Dimensions.space8),
                Text(
                  'Join rides to save money and travel together',
                  style: regularDefault.copyWith(
                    color: MyColor.primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinedRidesList(ScheduledRideController controller) {
    return RefreshIndicator(
      onRefresh: () => controller.loadJoinedRides(refresh: true),
      color: MyColor.primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(Dimensions.space15),
        itemCount: controller.getFilteredJoinedRides().length,
        itemBuilder: (context, index) {
          JoinedRideModel joinedRide =
              controller.getFilteredJoinedRides()[index];
          return _buildJoinedRideCard(controller, joinedRide, index);
        },
      ),
    );
  }

  Widget _buildJoinedRideCard(ScheduledRideController controller,
      JoinedRideModel joinedRide, int index) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300 + (index * 100)),
      margin: const EdgeInsets.only(bottom: Dimensions.space15),
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
      child: Padding(
        padding: const EdgeInsets.all(Dimensions.space20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Dimensions.space12,
                    vertical: Dimensions.space6,
                  ),
                  decoration: BoxDecoration(
                    color: controller
                        .getStatusColor(joinedRide.passengerStatus ?? '')
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(Dimensions.radiusHuge),
                    border: Border.all(
                      color: controller
                          .getStatusColor(joinedRide.passengerStatus ?? '')
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: controller
                              .getStatusColor(joinedRide.passengerStatus ?? ''),
                          shape: BoxShape.circle,
                        ),
                      ),
                      spaceSide(Dimensions.space6),
                      Text(
                        controller
                            .getStatusText(joinedRide.passengerStatus ?? ''),
                        style: regularSmall.copyWith(
                          color: controller
                              .getStatusColor(joinedRide.passengerStatus ?? ''),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Fare',
                      style: regularSmall.copyWith(
                        color: Colors.grey[600],
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      '\$${joinedRide.fare ?? '0'}',
                      style: boldDefault.copyWith(
                        color: MyColor.primaryColor,
                        fontSize: Dimensions.fontLarge,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            spaceDown(Dimensions.space20),

            // Route Information
            _buildRouteInfo(joinedRide),

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
                      Icons.straighten,
                      'Distance',
                      '${joinedRide.distance ?? '0'} km',
                    ),
                  ),
                  Expanded(
                    child: _buildDetailItem(
                      Icons.access_time,
                      'Joined',
                      controller.formatDateTime(joinedRide.createdAt),
                    ),
                  ),
                  Expanded(
                    child: _buildDetailItem(
                      Icons.check_circle,
                      'Driver Approved',
                      joinedRide.passengerStatus == '1' ? 'Yes' : 'No',
                    ),
                  ),
                ],
              ),
            ),

            // Status-specific actions
            if (joinedRide.passengerStatus == '0') // Pending
              Container(
                margin: const EdgeInsets.only(top: Dimensions.space20),
                width: double.infinity,
                height: 45,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(Dimensions.mediumRadius),
                ),
                child: TextButton.icon(
                  onPressed: controller.isLeaving
                      ? null
                      : () {
                          _showLeaveConfirmationDialog(
                              controller, joinedRide.id!);
                        },
                  icon: controller.isLeaving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.red,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(Icons.exit_to_app, color: Colors.red, size: 20),
                  label: Text(
                    controller.isLeaving ? 'Leaving...' : 'Leave Ride',
                    style: regularDefault.copyWith(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

            if (joinedRide.passengerStatus == '1') // Approved - use passengerStatus instead of status
              Container(
                margin: const EdgeInsets.only(top: Dimensions.space20),
                width: double.infinity,
                height: 45,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green, Colors.green.shade600],
                  ),
                  borderRadius: BorderRadius.circular(Dimensions.mediumRadius),
                ),
                child: TextButton.icon(
                  onPressed: () {
                    // Navigate to payment screen - pass passengers array for finding correct pivot ID
                    Get.to(() => PaymentScreen(
                          passenger: joinedRide,
                          ride: AvailableRideModel(
                            id: joinedRide.id,
                            pickupLocation: joinedRide.pickupLocation,
                            destination: joinedRide.destination,
                            scheduledDateTime: joinedRide.scheduledDateTime,
                            estimatedFare: joinedRide.fare,
                            passengers: joinedRide.passengers, // Include passengers array for payment lookup
                          ),
                        ));
                  },
                  icon: Icon(Icons.payment, color: Colors.white, size: 20),
                  label: Text(
                    'Make Payment',
                    style: regularDefault.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

            if (joinedRide.passengerStatus == '2') // Completed
              Container(
                margin: const EdgeInsets.only(top: Dimensions.space20),
                padding: const EdgeInsets.all(Dimensions.space15),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(Dimensions.mediumRadius),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.blue, size: 20),
                    spaceSide(Dimensions.space12),
                    Expanded(
                      child: Text(
                        'Ride completed successfully!',
                        style: regularDefault.copyWith(
                          color: Colors.blue[800],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteInfo(JoinedRideModel joinedRide) {
    return Column(
      children: [
        _buildLocationRow(
          Icons.location_on,
          'Pickup',
          joinedRide.pickupLocation ?? 'Not specified',
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
          joinedRide.destination ?? 'Not specified',
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

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.grey[600],
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
            color: MyColor.colorBlack,
            fontWeight: FontWeight.w500,
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void _showLeaveConfirmationDialog(
      ScheduledRideController controller, String rideId) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dimensions.mediumRadius),
        ),
        title: Row(
          children: [
            Icon(Icons.exit_to_app, color: Colors.red, size: 24),
            spaceSide(Dimensions.space8),
            const Text('Leave Ride'),
          ],
        ),
        content: const Text(
            'Are you sure you want to leave this scheduled ride? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Cancel',
              style: regularDefault.copyWith(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              controller.leaveScheduledRide(rideId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Dimensions.defaultRadius),
              ),
            ),
            child: const Text(
              'Leave Ride',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
