import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovorideuser/core/utils/dimensions.dart';
import 'package:ovorideuser/core/utils/my_color.dart';
import 'package:ovorideuser/core/utils/style.dart';
import 'package:ovorideuser/data/controller/scheduled_ride/scheduled_ride_controller.dart';
import 'package:ovorideuser/data/model/scheduled_ride/scheduled_ride_model.dart';
import 'package:ovorideuser/data/repo/scheduled_ride/scheduled_ride_repo.dart';
import 'package:ovorideuser/data/services/api_service.dart';
import 'package:ovorideuser/data/services/notification_handler_service.dart';
import 'package:ovorideuser/presentation/components/custom_loader/custom_loader.dart';
import 'package:ovorideuser/presentation/components/divider/custom_spacer.dart';
import 'package:ovorideuser/presentation/components/text/header_text.dart';
import 'package:ovorideuser/presentation/screens/scheduled_rides/join_ride_screen.dart';
import 'package:ovorideuser/presentation/screens/scheduled_rides/ride_detail_screen.dart';
import 'package:ovorideuser/presentation/screens/scheduled_rides/joined_rides_screen.dart';
import 'package:ovorideuser/presentation/screens/scheduled_rides/rider_ride_detail_screen.dart';
import 'package:ovorideuser/presentation/screens/scheduled_rides/active_scheduled_ride_screen.dart';

// SliverTabBarDelegate for pinned tab bar
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _SliverTabBarDelegate({required this.child});

  @override
  double get minExtent => 70.0;

  @override
  double get maxExtent => 70.0;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: MyColor.screenBgColor,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return false;
  }
}

class ScheduledRidesScreen extends StatefulWidget {
  const ScheduledRidesScreen({super.key});

  @override
  State<ScheduledRidesScreen> createState() => _ScheduledRidesScreenState();
}

class _ScheduledRidesScreenState extends State<ScheduledRidesScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    Get.put(ApiClient(sharedPreferences: Get.find()));
    Get.put(ScheduledRideRepo(apiClient: Get.find()));
    Get.put(ScheduledRideController(repo: Get.find()));

    // Set default tab to 'available' for scheduled rides screen
    Future.delayed(Duration.zero, () {
      final controller = Get.find<ScheduledRideController>();
      controller.selectedTab = 'available';
      controller.update();
    });

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
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
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();

    // Initialize notification handler
    _initializeNotificationHandler();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data when screen is focused
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = Get.find<ScheduledRideController>();
      if (controller.availableRides.isEmpty && controller.joinedRides.isEmpty) {
        controller.refreshAllRides();
      }
    });
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
      body: GetBuilder<ScheduledRideController>(
        builder: (controller) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: RefreshIndicator(
                onRefresh: () async {
                  await controller.refreshAllRides();
                },
                color: MyColor.primaryColor,
                backgroundColor: MyColor.colorWhite,
                strokeWidth: 3.0,
                child: CustomScrollView(
                  slivers: [
                    // Collapsible App Bar
                    SliverAppBar(
                      expandedHeight: 180.0,
                      floating: false,
                      pinned: true,
                      backgroundColor: MyColor.primaryColor,
                      elevation: 0,
                      leading: IconButton(
                        icon: Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Get.back(),
                      ),
                      title: Text(
                        'Scheduled Rides',
                        style: boldDefault.copyWith(color: Colors.white),
                      ),
                      flexibleSpace: FlexibleSpaceBar(
                        background: Container(
                          color: MyColor.primaryColor,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // Enhanced Search and Filter Section
                              _buildEnhancedSearchSection(controller),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Tab Bar (Pinned)
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _SliverTabBarDelegate(
                        child: _buildTabBar(controller),
                      ),
                    ),

                    // Last refresh indicator
                    SliverToBoxAdapter(
                      child: _buildLastRefreshIndicator(controller),
                    ),

                    // Current ride card (if rider has active ride)
                    (controller.currentScheduledRide != null ||
                            controller.currentAvailableScheduledRide != null)
                        ? SliverToBoxAdapter(
                            child: _buildCurrentRideCard(controller),
                          )
                        : const SliverToBoxAdapter(child: SizedBox.shrink()),

                    // Content based on selected tab
                    controller.selectedTab == 'available'
                        ? _buildAvailableRidesSliver(controller)
                        : _buildJoinedRidesSliver(controller),

                    // Bottom padding for better scrolling
                    SliverToBoxAdapter(
                      child: SizedBox(height: Dimensions.space20),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEnhancedSearchSection(ScheduledRideController controller) {
    return Container(
      margin: const EdgeInsets.all(Dimensions.space10),
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
        padding: const EdgeInsets.all(Dimensions.space12),
        child: Column(
          children: [
            // Search Bar
            TextField(
              onChanged: (value) {
                controller.searchQuery = value;
                controller.update();
              },
              decoration: InputDecoration(
                hintText: 'Search by destination or pickup location...',
                prefixIcon: Icon(Icons.search, color: MyColor.primaryColor),
                suffixIcon: controller.searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          controller.searchQuery = '';
                          controller.update();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Dimensions.mediumRadius),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Dimensions.mediumRadius),
                  borderSide: BorderSide(color: MyColor.primaryColor, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.space12,
                  vertical: Dimensions.space10,
                ),
              ),
            ),

            spaceDown(Dimensions.space12),

            // Quick Actions
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Get.to(() => const JoinedRidesScreen()),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Dimensions.space12,
                        vertical: Dimensions.space10,
                      ),
                      decoration: BoxDecoration(
                        color: MyColor.primaryColor.withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(Dimensions.mediumRadius),
                        border: Border.all(
                          color: MyColor.primaryColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history,
                            color: MyColor.primaryColor,
                            size: 18,
                          ),
                          spaceSide(Dimensions.space6),
                          Text(
                            'My Rides',
                            style: regularSmall.copyWith(
                              color: MyColor.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                spaceSide(Dimensions.space10),
                // Refresh Button
                GestureDetector(
                  onTap: controller.isRefreshing
                      ? null
                      : () => controller.refreshAllRides(),
                  child: Container(
                    padding: const EdgeInsets.all(Dimensions.space10),
                    decoration: BoxDecoration(
                      color: controller.isRefreshing
                          ? Colors.grey
                          : MyColor.primaryColor,
                      borderRadius:
                          BorderRadius.circular(Dimensions.mediumRadius),
                      boxShadow: [
                        BoxShadow(
                          color: controller.isRefreshing
                              ? Colors.grey.withValues(alpha: 0.3)
                              : MyColor.primaryColor.withValues(alpha: 0.3),
                          spreadRadius: 1,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: controller.isRefreshing
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(
                            Icons.refresh,
                            color: Colors.white,
                            size: 18,
                          ),
                  ),
                ),
                spaceSide(Dimensions.space8),
                // Auto-refresh Toggle
                GestureDetector(
                  onTap: () => controller.toggleAutoRefresh(),
                  child: Container(
                    padding: const EdgeInsets.all(Dimensions.space10),
                    decoration: BoxDecoration(
                      color: controller.isAutoRefreshEnabled
                          ? Colors.green
                          : Colors.grey,
                      borderRadius:
                          BorderRadius.circular(Dimensions.mediumRadius),
                      boxShadow: [
                        BoxShadow(
                          color: (controller.isAutoRefreshEnabled
                                  ? Colors.green
                                  : Colors.grey)
                              .withValues(alpha: 0.3),
                          spreadRadius: 1,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      controller.isAutoRefreshEnabled
                          ? Icons.timer
                          : Icons.timer_off,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar(ScheduledRideController controller) {
    return GetBuilder<ScheduledRideController>(
      builder: (controller) {
        return Container(
          margin: const EdgeInsets.symmetric(
              horizontal: Dimensions.space12, vertical: Dimensions.space8),
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
                _buildTab(controller, 'Available Rides', 'available',
                    Icons.directions_car),
                _buildTab(controller, 'Joined Rides', 'joined',
                    Icons.check_circle_outline),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTab(ScheduledRideController controller, String title,
      String status, IconData icon) {
    bool isSelected = controller.selectedTab == status;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            controller.switchTab(status);
          },
          borderRadius: BorderRadius.circular(Dimensions.mediumRadius),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            transform: Matrix4.identity()..scale(isSelected ? 1.02 : 1.0),
            padding: const EdgeInsets.symmetric(
                vertical: Dimensions.space6, horizontal: Dimensions.space6),
            decoration: BoxDecoration(
              color: isSelected ? MyColor.primaryColor : Colors.transparent,
              borderRadius: BorderRadius.circular(Dimensions.mediumRadius),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: MyColor.primaryColor.withValues(alpha: 0.3),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      color: isSelected ? Colors.white : Colors.grey[600],
                      size: 18,
                    ),
                    if (isSelected) ...[
                      spaceSide(Dimensions.space6),
                      GestureDetector(
                        onTap: controller.isRefreshing
                            ? null
                            : () => controller.refreshCurrentTab(),
                        child: Container(
                          padding: const EdgeInsets.all(Dimensions.space3),
                          decoration: BoxDecoration(
                            color: controller.isRefreshing
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.white.withValues(alpha: 0.2),
                            borderRadius:
                                BorderRadius.circular(Dimensions.radiusHuge),
                          ),
                          child: controller.isRefreshing
                              ? SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : Icon(
                                  Icons.refresh,
                                  color: Colors.white,
                                  size: 14,
                                ),
                        ),
                      ),
                    ],
                  ],
                ),
                // spaceDown(Dimensions.space3),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: regularSmall.copyWith(
                    color: isSelected ? Colors.white : MyColor.colorBlack,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLastRefreshIndicator(ScheduledRideController controller) {
    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: Dimensions.space12, vertical: Dimensions.space8),
      padding: const EdgeInsets.all(Dimensions.space8),
      decoration: BoxDecoration(
        color: MyColor.colorWhite,
        borderRadius: BorderRadius.circular(Dimensions.mediumRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.refresh, color: MyColor.primaryColor, size: 18),
          spaceSide(Dimensions.space8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.getLastRefreshTime(),
                  style: regularSmall.copyWith(
                    color: MyColor.colorBlack,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
                spaceDown(Dimensions.space2),
                Text(
                  controller.isAutoRefreshEnabled
                      ? 'Auto-refresh every 5 minutes'
                      : 'Auto-refresh disabled',
                  style: regularSmall.copyWith(
                    color: Colors.grey[600],
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          // Quick refresh button
          GestureDetector(
            onTap: controller.isRefreshing
                ? null
                : () => controller.refreshCurrentTab(),
            child: Container(
              padding: const EdgeInsets.all(Dimensions.space5),
              decoration: BoxDecoration(
                color: controller.isRefreshing
                    ? Colors.grey.withValues(alpha: 0.2)
                    : MyColor.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(Dimensions.radiusHuge),
              ),
              child: controller.isRefreshing
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(MyColor.primaryColor),
                      ),
                    )
                  : Icon(
                      Icons.refresh,
                      color: MyColor.primaryColor,
                      size: 14,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableRidesSliver(ScheduledRideController controller) {
    if (controller.isLoading && controller.availableRides.isEmpty) {
      return SliverToBoxAdapter(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: const Center(child: CustomLoader()),
        ),
      );
    }

    if (controller.getFilteredRides().isEmpty) {
      return SliverToBoxAdapter(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: _buildEmptyState(controller),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(Dimensions.space12)+ EdgeInsets.only(bottom: 40),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index == controller.getFilteredRides().length) {
              if (controller.hasNextPage) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(Dimensions.space15),
                    child: CustomLoader(isPagination: true),
                  ),
                );
              }
              return const SizedBox.shrink();
            }
            AvailableRideModel ride = controller.getFilteredRides()[index];
            return _buildAvailableRideCard(controller, ride, index);
          },
          childCount: controller.getFilteredRides().length +
              (controller.hasNextPage ? 1 : 0),
        ),
      ),
    );
  }

  Widget _buildJoinedRidesSliver(ScheduledRideController controller) {
    if (controller.isLoadingJoinedRides && controller.joinedRides.isEmpty) {
      return SliverToBoxAdapter(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: const Center(child: CustomLoader()),
        ),
      );
    }

    if (controller.joinedRides.isEmpty) {
      return SliverToBoxAdapter(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: _buildEmptyJoinedRidesState(),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(Dimensions.space12),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            JoinedRideModel joinedRide =
                controller.getFilteredJoinedRides()[index];
            return _buildJoinedRideCard(controller, joinedRide, index);
          },
          childCount: controller.getFilteredJoinedRides().length,
        ),
      ),
    );
  }

  Widget _buildEmptyState(ScheduledRideController controller) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(Dimensions.space30),
            decoration: BoxDecoration(
              color: MyColor.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.directions_car_outlined,
              size: 80,
              color: MyColor.primaryColor.withValues(alpha: 0.7),
            ),
          ),
          spaceDown(Dimensions.space25),
          HeaderText(
            text: controller.searchQuery.isNotEmpty
                ? 'No Rides Found'
                : 'No Available Rides',
            textStyle: boldLarge.copyWith(
              color: MyColor.colorBlack,
              fontSize: Dimensions.fontOverLarge,
            ),
          ),
          spaceDown(Dimensions.space15),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Dimensions.space30),
            child: Text(
              controller.searchQuery.isNotEmpty
                  ? 'Try adjusting your search terms or check back later for new rides.'
                  : 'There are currently no scheduled rides available.\nCheck back later for new opportunities to join rides.',
              textAlign: TextAlign.center,
              style: regularDefault.copyWith(
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyJoinedRidesState() {
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
        ],
      ),
    );
  }

  Widget _buildAvailableRideCard(
      ScheduledRideController controller, AvailableRideModel ride, int index) {
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
      child: InkWell(
        onTap: () {
          Get.to(() => RideDetailScreen(ride: ride));
        },
        borderRadius: BorderRadius.circular(Dimensions.largeRadius),
        child: Padding(
          padding: const EdgeInsets.all(Dimensions.space20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with service and status
              Row(
                children: [
                  // Service icon
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
                      borderRadius:
                          BorderRadius.circular(Dimensions.mediumRadius),
                    ),
                    child: ride.service?.image != null
                        ? ClipRRect(
                            borderRadius:
                                BorderRadius.circular(Dimensions.mediumRadius),
                            child: Image.network(
                              ride.service!.image!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.directions_car,
                                  color: MyColor.primaryColor,
                                  size: 30,
                                );
                              },
                            ),
                          )
                        : Icon(
                            Icons.directions_car,
                            color: MyColor.primaryColor,
                            size: 30,
                          ),
                  ),
                  spaceSide(Dimensions.space15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ride.service?.name ?? 'Unknown Service',
                          style: boldDefault.copyWith(
                            color: MyColor.colorBlack,
                            fontSize: Dimensions.fontLarge,
                          ),
                        ),
                        spaceDown(Dimensions.space8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Dimensions.space12,
                            vertical: Dimensions.space6,
                          ),
                          decoration: BoxDecoration(
                            color: controller
                                .getRideStatusColor(ride.status ?? '')
                                .withValues(alpha: 0.1),
                            borderRadius:
                                BorderRadius.circular(Dimensions.radiusHuge),
                            border: Border.all(
                              color: controller
                                  .getRideStatusColor(ride.status ?? '')
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
                                      .getRideStatusColor(ride.status ?? ''),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              spaceSide(Dimensions.space6),
                              Text(
                                controller.getRideStatusText(ride.status ?? ''),
                                style: regularSmall.copyWith(
                                  color: controller
                                      .getRideStatusColor(ride.status ?? ''),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              spaceDown(Dimensions.space20),

              // Location details
              _buildLocationRow(
                Icons.location_on,
                'Pickup',
                ride.pickupLocation ?? 'Not specified',
                Colors.green,
              ),
              spaceDown(Dimensions.space12),
              _buildLocationRow(
                Icons.location_on_outlined,
                'Destination',
                ride.destination ?? 'Not specified',
                Colors.red,
              ),

              spaceDown(Dimensions.space20),

              // Ride details grid
              Container(
                padding: const EdgeInsets.all(Dimensions.space15),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(Dimensions.mediumRadius),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildDetailItem(
                            Icons.schedule,
                            'Start Time',
                            controller.formatDateTime(ride.scheduledDateTime),
                          ),
                        ),
                        Expanded(
                          child: _buildDetailItem(
                            Icons.people,
                            'Available Seats',
                            '${controller.getAvailableSeats(ride)}',
                          ),
                        ),
                      ],
                    ),
                    spaceDown(Dimensions.space15),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDetailItem(
                            Icons.straighten,
                            'Distance',
                            '${ride.distance ?? '0'} km',
                          ),
                        ),
                        Expanded(
                          child: _buildDetailItem(
                            Icons.attach_money,
                            'Fare/Seat',
                            '\$${ride.getFarePerSeat()}',
                            isFare: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Driver information
              if (ride.driver != null)
                Container(
                  margin: const EdgeInsets.only(top: Dimensions.space20),
                  padding: const EdgeInsets.all(Dimensions.space15),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.05),
                    borderRadius:
                        BorderRadius.circular(Dimensions.mediumRadius),
                    border:
                        Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.blue.withValues(alpha: 0.1),
                        child: ride.driver!.avatar != null
                            ? ClipOval(
                                child: Image.network(
                                  ride.driver!.avatar!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(Icons.person,
                                        color: Colors.blue);
                                  },
                                ),
                              )
                            : Icon(Icons.person, color: Colors.blue),
                      ),
                      spaceSide(Dimensions.space12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${ride.driver!.firstname} ${ride.driver!.lastname}',
                              style: regularDefault.copyWith(
                                fontWeight: FontWeight.w600,
                                color: MyColor.colorBlack,
                              ),
                            ),
                            Text(
                              'Driver',
                              style: regularSmall.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Dimensions.space8,
                          vertical: Dimensions.space4,
                        ),
                        decoration: BoxDecoration(
                          color: ride.driver!.onlineStatus == '1'
                              ? Colors.green
                              : Colors.grey,
                          borderRadius:
                              BorderRadius.circular(Dimensions.radiusHuge),
                        ),
                        child: Text(
                          ride.driver!.onlineStatus == '1'
                              ? 'Online'
                              : 'Offline',
                          style: regularSmall.copyWith(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Action buttons
              spaceDown(Dimensions.space20),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 45,
                      decoration: BoxDecoration(
                        border: Border.all(color: MyColor.primaryColor),
                        borderRadius:
                            BorderRadius.circular(Dimensions.mediumRadius),
                      ),
                      child: TextButton.icon(
                        onPressed: () {
                          Get.to(() => RideDetailScreen(ride: ride));
                        },
                        icon: Icon(Icons.info_outline,
                            color: MyColor.primaryColor, size: 20),
                        label: Text(
                          'View Details',
                          style: regularDefault.copyWith(
                            color: MyColor.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  spaceSide(Dimensions.space12),
                  Expanded(
                    child: controller.hasUserJoinedRide(ride.id!)
                        ? Container(
                            height: 45,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.red),
                              borderRadius: BorderRadius.circular(
                                  Dimensions.mediumRadius),
                            ),
                            child: TextButton.icon(
                              onPressed: controller.isLeaving
                                  ? null
                                  : () {
                                      _showLeaveConfirmationDialog(
                                          controller, ride.id!);
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
                                  : Icon(Icons.exit_to_app,
                                      color: Colors.red, size: 20),
                              label: Text(
                                controller.isLeaving
                                    ? 'Leaving...'
                                    : 'Leave Ride',
                                style: regularDefault.copyWith(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                        : Container(
                            height: 45,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: controller.isRideFull(ride)
                                    ? [Colors.grey, Colors.grey.shade600]
                                    : [
                                        MyColor.primaryColor,
                                        MyColor.primaryColor
                                            .withValues(alpha: 0.8)
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(
                                  Dimensions.mediumRadius),
                            ),
                            child: TextButton.icon(
                              onPressed: controller.isRideFull(ride)
                                  ? null
                                  : () {
                                      Get.to(() => JoinRideScreen(ride: ride));
                                    },
                              icon: Icon(Icons.add,
                                  color: Colors.white, size: 20),
                              label: Text(
                                controller.isRideFull(ride)
                                    ? 'Full'
                                    : 'Join Ride',
                                style: regularDefault.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
            // Status header
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
                spaceSide(Dimensions.space8),
                // Ride Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Dimensions.space10,
                    vertical: Dimensions.space6,
                  ),
                  decoration: BoxDecoration(
                    color: controller
                        .getRideStatusColor(joinedRide.status ?? '')
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(Dimensions.radiusHuge),
                    border: Border.all(
                      color: controller
                          .getRideStatusColor(joinedRide.status ?? '')
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    controller.getRideStatusText(joinedRide.status ?? ''),
                    style: regularSmall.copyWith(
                      color: controller
                          .getRideStatusColor(joinedRide.status ?? ''),
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            
            spaceDown(Dimensions.space12),
            
            // Fare display
            Row(
              children: [
                Icon(Icons.payments_outlined, 
                  color: MyColor.primaryColor, 
                  size: 18
                ),
                spaceSide(Dimensions.space6),
                Text(
                  'Fare: ',
                  style: regularDefault.copyWith(
                    color: Colors.grey[600],
                    fontSize: Dimensions.fontDefault,
                  ),
                ),
                Text(
                  '\$${joinedRide.fare ?? '0'}',
                  style: boldDefault.copyWith(
                    color: MyColor.primaryColor,
                    fontSize: Dimensions.fontMedium,
                  ),
                ),
              ],
            ),

            spaceDown(Dimensions.space20),

            // Location details
            _buildLocationRow(
              Icons.location_on,
              'Pickup',
              joinedRide.pickupLocation ?? 'Not specified',
              Colors.green,
            ),
            spaceDown(Dimensions.space12),
            _buildLocationRow(
              Icons.location_on_outlined,
              'Destination',
              joinedRide.destination ?? 'Not specified',
              Colors.red,
            ),

            spaceDown(Dimensions.space20),

            // Ride details
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
                ],
              ),
            ),

            spaceDown(Dimensions.space15),

            // Action buttons row
            Row(
              children: [
                // View Details Button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _showJoinedRideDetailsDialog(controller, joinedRide);
                    },
                    icon: Icon(
                      Icons.info_outline,
                      color: MyColor.primaryColor,
                      size: 18,
                    ),
                    label: Text(
                      'View Details',
                      style: regularDefault.copyWith(
                        color: MyColor.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: MyColor.primaryColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Dimensions.mediumRadius),
                      ),
                    ),
                  ),
                ),
                
                // Payment button if approved
                if (joinedRide.passengerStatus == '1') ...[
                  spaceSide(Dimensions.space10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: controller.isProcessingCashPayment
                          ? null
                          : () {
                              _showPaymentConfirmationDialog(controller, joinedRide);
                            },
                      icon: Icon(Icons.payment, color: Colors.white, size: 18),
                      label: Text(
                        'Pay',
                        style: regularDefault.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Dimensions.mediumRadius),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow(
      IconData icon, String label, String address, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(Dimensions.space8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
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

  // Build current ride card
  Widget _buildCurrentRideCard(ScheduledRideController controller) {
    // Use currentAvailableScheduledRide (from available rides API) if available,
    // otherwise use currentScheduledRide (from joined rides API)
    // Both models have the same fields for the properties we're using
    dynamic ride = controller.currentAvailableScheduledRide ?? controller.currentScheduledRide;

    if (ride == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(
          Dimensions.space15, 0, Dimensions.space15, Dimensions.space15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue, Colors.blue.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(Dimensions.largeRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.3),
            spreadRadius: 2,
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          // Check if user has joined and is active for this ride
          // Use isActivePassenger which checks for status 1 (approved), 4, or 5 (in_progress/on_way)
          if (controller.userPassengerInfo != null && controller.userPassengerInfo!.isActivePassenger) {
            // User is active passenger, navigate to the active ride screen
            Get.to(() => ActiveScheduledRideScreen(
              ride: ride,
              userPassengerInfo: controller.userPassengerInfo,
            ));
          } else if (controller.userPassengerInfo != null && controller.userPassengerInfo!.isPending) {
            // User is pending approval
            Get.snackbar(
              'Pending Approval',
              'Your request to join this ride is pending driver approval.',
              backgroundColor: Colors.orange,
              colorText: Colors.white,
              snackPosition: SnackPosition.BOTTOM,
            );
          } else if (ride is JoinedRideModel) {
            // Legacy support for JoinedRideModel
            Get.to(() => RiderRideDetailScreen(ride: ride));
          } else {
            // User hasn't joined this ride yet
            Get.snackbar(
              'Info',
              'This is a scheduled ride. You need to join it first to see tracking details.',
              backgroundColor: MyColor.primaryColor,
              colorText: Colors.white,
              snackPosition: SnackPosition.BOTTOM,
            );
          }
        },
        borderRadius: BorderRadius.circular(Dimensions.largeRadius),
        child: Padding(
          padding: const EdgeInsets.all(Dimensions.space15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with status indicator
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(Dimensions.space8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius:
                          BorderRadius.circular(Dimensions.mediumRadius),
                    ),
                    child: const Icon(
                      Icons.directions_car,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  spaceSide(Dimensions.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Current Ride',
                                style: boldDefault.copyWith(
                                  color: Colors.white,
                                  fontSize: Dimensions.fontLarge,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Dimensions.space10,
                                vertical: Dimensions.space6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(
                                    Dimensions.radiusHuge),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  spaceSide(Dimensions.space6),
                                  Text(
                                    'Active',
                                    style: regularSmall.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        spaceDown(Dimensions.space6),
                        Text(
                          'Ride #${ride.id}',
                          style: regularDefault.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              spaceDown(Dimensions.space15),

              // Location details
              _buildCurrentRideLocationRow(
                Icons.location_on,
                'From',
                ride.pickupLocation ?? 'Not specified',
                Colors.white,
              ),
              spaceDown(Dimensions.space10),
              _buildCurrentRideLocationRow(
                Icons.location_on_outlined,
                'To',
                ride.destination ?? 'Not specified',
                Colors.white.withValues(alpha: 0.8),
              ),

              spaceDown(Dimensions.space15),

              // Driver info and status
              Container(
                padding: const EdgeInsets.all(Dimensions.space12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(Dimensions.mediumRadius),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Driver: ${ride.driver?.firstname ?? 'Unknown'}',
                            style: regularDefault.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          spaceDown(Dimensions.space4),
                          Text(
                            'Vehicle: ${ride.service?.name ?? 'Unknown'}',
                            style: regularSmall.copyWith(
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),




                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Dimensions.space8,
                        vertical: Dimensions.space4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius:
                            BorderRadius.circular(Dimensions.mediumRadius),
                      ),
                      child: Text(
                        _getCardActionText(controller, ride),
                        style: regularSmall.copyWith(
                          color: Colors.white,
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
      ),
    );
  }

  // Build location row for current ride card
  Widget _buildCurrentRideLocationRow(
      IconData icon, String label, String address, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        spaceSide(Dimensions.space8),
        Expanded(
          child: Text(
            '$label: $address',
            style: regularDefault.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // Initialize notification handler
  void _initializeNotificationHandler() {
    // This would typically be called when you receive a notification
    // For example, in your Firebase messaging handler or push notification service
    // Example usage:
    // NotificationHandlerService().handleScheduledRideNotification(notificationPayload);
  }

  // Method to handle incoming notifications
  void handleNotification(Map<String, dynamic> payload) {
    NotificationHandlerService().handleScheduledRideNotification(payload);
  }

  // Method to refresh data when notification is received
  void refreshDataOnNotification() {
    final controller = Get.find<ScheduledRideController>();
    if (controller.selectedTab == 'available') {
      controller.loadAvailableScheduledRides(refresh: true);
    } else {
      controller.loadJoinedRides(refresh: true);
    }
  }

  // Helper method to get the appropriate action text for the current ride card
  String _getCardActionText(ScheduledRideController controller, dynamic ride) {
    if (controller.userPassengerInfo != null) {
      // Use isActivePassenger to check for status 1 (approved), 4, or 5 (in_progress/on_way)
      if (controller.userPassengerInfo!.isActivePassenger) {
        return 'Tap to Track';
      } else if (controller.userPassengerInfo!.isPending) {
        return 'Pending Approval';
      }
    }
    if (ride is JoinedRideModel) {
      return 'Tap to Track';
    }
    return 'Tap for Info';
  }

  // Show payment confirmation dialog
  void _showPaymentConfirmationDialog(
      ScheduledRideController controller, JoinedRideModel joinedRide) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dimensions.mediumRadius),
        ),
        title: Row(
          children: [
            Icon(Icons.payment, color: MyColor.primaryColor, size: 24),
            spaceSide(Dimensions.space8),
            const Text('Confirm Cash Payment'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total Fare:',
              style: regularDefault.copyWith(
                color: Colors.grey[600],
              ),
            ),
            spaceDown(Dimensions.space8),
            Text(
              '\$${joinedRide.fare ?? '0'}',
              style: boldLarge.copyWith(
                color: MyColor.primaryColor,
                fontSize: Dimensions.fontOverLarge,
              ),
            ),
            spaceDown(Dimensions.space15),
            Container(
              padding: const EdgeInsets.all(Dimensions.space12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(Dimensions.defaultRadius),
                border: Border.all(
                  color: Colors.blue.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue, size: 20),
                  spaceSide(Dimensions.space8),
                  Expanded(
                    child: Text(
                      'Please confirm that you have paid the driver in cash.',
                      style: regularSmall.copyWith(
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Cancel',
              style: regularDefault.copyWith(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: controller.isProcessingCashPayment
                ? null
                : () {
                    Get.back();
                    // Use scheduled ride cash payment API with correct parameters
                    if (joinedRide.id != null && joinedRide.passengerId != null) {
                      double amount = double.tryParse(joinedRide.fare ?? '0') ?? 0;
                      controller.makeScheduledRideCashPayment(
                        joinedRide.id!,
                        joinedRide.passengerId!,
                        amount,
                        null,
                      );
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: MyColor.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Dimensions.defaultRadius),
              ),
            ),
            child: controller.isProcessingCashPayment
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Confirm Payment',
                    style: TextStyle(color: Colors.white),
                  ),
          ),
        ],
      ),
    );
  }

  // Show joined ride details dialog
  void _showJoinedRideDetailsDialog(
      ScheduledRideController controller, JoinedRideModel joinedRide) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dimensions.largeRadius),
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(Get.context!).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(Dimensions.space20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [MyColor.primaryColor, MyColor.primaryColor.withValues(alpha: 0.8)],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(Dimensions.largeRadius),
                    topRight: Radius.circular(Dimensions.largeRadius),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.white, size: 28),
                    spaceSide(Dimensions.space12),
                    Expanded(
                      child: Text(
                        'Ride Details',
                        style: boldLarge.copyWith(
                          color: Colors.white,
                          fontSize: Dimensions.fontLarge,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(Dimensions.space20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Section
                      _buildDetailSection(
                        'Status Information',
                        Icons.info,
                        [
                          _buildDetailRow('Passenger Status', 
                            controller.getStatusText(joinedRide.passengerStatus ?? ''),
                            color: controller.getStatusColor(joinedRide.passengerStatus ?? '')),
                          _buildDetailRow('Ride Status', 
                            controller.getRideStatusText(joinedRide.status ?? ''),
                            color: controller.getRideStatusColor(joinedRide.status ?? '')),
                        ],
                      ),

                      spaceDown(Dimensions.space20),

                      // Location Section
                      _buildDetailSection(
                        'Location Details',
                        Icons.location_on,
                        [
                          _buildDetailRow('Pickup Location', 
                            joinedRide.pickupLocation ?? 'Not specified'),
                          _buildDetailRow('Destination', 
                            joinedRide.destination ?? 'Not specified'),
                        ],
                      ),

                      spaceDown(Dimensions.space20),

                      // Ride Information Section
                      _buildDetailSection(
                        'Ride Information',
                        Icons.directions_car,
                        [
                          _buildDetailRow('Distance', 
                            '${joinedRide.distance ?? '0'} km'),
                          _buildDetailRow('Duration', 
                            joinedRide.duration ?? 'Not specified'),
                          _buildDetailRow('Service', 
                            joinedRide.service?.name ?? 'Not specified'),
                          _buildDetailRow('Seats Booked', 
                            joinedRide.seatsBooked ?? '0'),
                          _buildDetailRow('Available Seats', 
                            joinedRide.availableSeats ?? '0'),
                        ],
                      ),

                      spaceDown(Dimensions.space20),

                      // Driver Information Section
                      if (joinedRide.driver != null)
                        _buildDetailSection(
                          'Driver Information',
                          Icons.person,
                          [
                            _buildDetailRow('Name', 
                              '${joinedRide.driver!.firstname ?? ''} ${joinedRide.driver!.lastname ?? ''}'),
                            if (joinedRide.driver!.mobile != null)
                              _buildDetailRow('Mobile', 
                                joinedRide.driver!.mobile!),
                          ],
                        ),

                      spaceDown(Dimensions.space20),

                      // Payment Section
                      _buildDetailSection(
                        'Payment Information',
                        Icons.payment,
                        [
                          _buildDetailRow('Fare', 
                            '\$${joinedRide.fare ?? '0'}',
                            color: MyColor.primaryColor,
                            isBold: true),
                          _buildDetailRow('Estimated Fare', 
                            '\$${joinedRide.estimatedFare ?? '0'}'),
                        ],
                      ),

                      spaceDown(Dimensions.space20),

                      // Dates Section
                      _buildDetailSection(
                        'Dates',
                        Icons.calendar_today,
                        [
                          _buildDetailRow('Scheduled Date', 
                            controller.formatDateTime(joinedRide.scheduledDateTime)),
                          _buildDetailRow('Joined On', 
                            controller.formatDateTime(joinedRide.createdAt)),
                        ],
                      ),

                      // Note Section
                      if (joinedRide.note != null && joinedRide.note!.isNotEmpty) ...[
                        spaceDown(Dimensions.space20),
                        _buildDetailSection(
                          'Note',
                          Icons.note,
                          [
                            Text(
                              joinedRide.note!,
                              style: regularDefault.copyWith(
                                color: Colors.grey[700],
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(Dimensions.space15),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(Dimensions.mediumRadius),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: MyColor.primaryColor, size: 20),
              spaceSide(Dimensions.space8),
              Text(
                title,
                style: boldDefault.copyWith(
                  color: MyColor.colorBlack,
                  fontSize: Dimensions.fontDefault,
                ),
              ),
            ],
          ),
          spaceDown(Dimensions.space12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Dimensions.space8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: regularDefault.copyWith(
                color: Colors.grey[600],
                fontSize: Dimensions.fontSmall,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: (isBold ? boldDefault : regularDefault).copyWith(
                color: color ?? MyColor.colorBlack,
                fontSize: Dimensions.fontDefault,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
