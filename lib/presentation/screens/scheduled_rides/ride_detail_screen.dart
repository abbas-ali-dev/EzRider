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
import 'package:ovorideuser/presentation/screens/scheduled_rides/join_ride_screen.dart';

class RideDetailScreen extends StatefulWidget {
  final AvailableRideModel ride;
  const RideDetailScreen({super.key, required this.ride});

  @override
  State<RideDetailScreen> createState() => _RideDetailScreenState();
}

class _RideDetailScreenState extends State<RideDetailScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  ScheduledRideDetailsData? detailedRide;
  bool isLoadingDetails = false;

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

    // Load detailed ride information
    _loadDetailedRideInfo();
  }

  Future<void> _loadDetailedRideInfo() async {
    setState(() {
      isLoadingDetails = true;
    });

    try {
      final controller = Get.find<ScheduledRideController>();
      final details = await controller.getScheduledRideDetails(widget.ride.id!);

      setState(() {
        detailedRide = details;
        isLoadingDetails = false;
      });
    } catch (e) {
      setState(() {
        isLoadingDetails = false;
      });
    }
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
        title: 'Ride Details',
        isShowBackBtn: true,
        bgColor: MyColor.primaryColor,
        elevation: 0,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: isLoadingDetails
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(Dimensions.space15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ride Header Card
                      _buildRideHeaderCard(),
                      spaceDown(Dimensions.space20),

                      // Route Information
                      _buildRouteCard(),
                      spaceDown(Dimensions.space20),

                      // Ride Details
                      _buildRideDetailsCard(),
                      spaceDown(Dimensions.space20),

                      // Driver Information
                      if (widget.ride.driver != null) _buildDriverCard(),

                      if (widget.ride.driver != null)
                        spaceDown(Dimensions.space20),

                      // Service Information
                      _buildServiceCard(),
                      spaceDown(Dimensions.space20),

                      // Passengers Information
                      if (widget.ride.passengers != null &&
                          widget.ride.passengers!.isNotEmpty)
                        _buildPassengersCard(),

                      if (widget.ride.passengers != null &&
                          widget.ride.passengers!.isNotEmpty)
                        spaceDown(Dimensions.space20),

                      // Action Buttons
                      _buildActionButtons(),
                      spaceDown(Dimensions.space20),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildRideHeaderCard() {
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
        children: [
          // Service Icon and Name
          Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      MyColor.primaryColor.withValues(alpha: 0.1),
                      MyColor.primaryColor.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(Dimensions.largeRadius),
                ),
                child: widget.ride.service?.image != null
                    ? ClipRRect(
                        borderRadius:
                            BorderRadius.circular(Dimensions.largeRadius),
                        child: Image.network(
                          widget.ride.service!.image!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.directions_car,
                              color: MyColor.primaryColor,
                              size: 40,
                            );
                          },
                        ),
                      )
                    : Icon(
                        Icons.directions_car,
                        color: MyColor.primaryColor,
                        size: 40,
                      ),
              ),
              spaceSide(Dimensions.space20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.ride.service?.name ?? 'Unknown Service',
                      style: boldLarge.copyWith(
                        color: MyColor.colorBlack,
                        fontSize: Dimensions.fontOverLarge,
                      ),
                    ),
                    spaceDown(Dimensions.space8),
                    Text(
                      'Ride #${widget.ride.id}',
                      style: regularDefault.copyWith(
                        color: Colors.grey[600],
                        fontSize: Dimensions.fontMedium,
                      ),
                    ),
                    spaceDown(Dimensions.space8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Dimensions.space12,
                        vertical: Dimensions.space6,
                      ),
                      decoration: BoxDecoration(
                        color: _getRideStatusColor().withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(Dimensions.radiusHuge),
                        border: Border.all(
                          color: _getRideStatusColor().withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _getRideStatusColor(),
                              shape: BoxShape.circle,
                            ),
                          ),
                          spaceSide(Dimensions.space6),
                          Text(
                            _getRideStatusText(),
                            style: regularSmall.copyWith(
                              color: _getRideStatusColor(),
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

          // Quick Stats
          Row(
            children: [
              Expanded(
                child: _buildQuickStat(
                  Icons.attach_money,
                  'Total Fare',
                  '\$${widget.ride.estimatedFare ?? '0'}',
                  MyColor.primaryColor,
                ),
              ),
              Expanded(
                child: _buildQuickStat(
                  Icons.attach_money_outlined,
                  'Fare/Seat',
                  '\$${widget.ride.getFarePerSeat()}',
                  MyColor.primaryColor,
                ),
              ),
              Expanded(
                child: _buildQuickStat(
                  Icons.straighten,
                  'Distance',
                  '${widget.ride.distance ?? '0'} km',
                  Colors.blue,
                ),
              ),
            ],
          ),
          spaceDown(Dimensions.space15),
          Row(
            children: [
              Expanded(
                child: _buildQuickStat(
                  Icons.access_time,
                  'Duration',
                  widget.ride.duration ?? 'N/A',
                  Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(
      IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(Dimensions.space12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        spaceDown(Dimensions.space8),
        Text(
          label,
          style: regularSmall.copyWith(
            color: Colors.grey[600],
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
        ),
        spaceDown(Dimensions.space4),
        Text(
          value,
          style: regularDefault.copyWith(
            color: MyColor.colorBlack,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRouteCard() {
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
            text: 'Route Information',
            textStyle: boldLarge.copyWith(
              color: MyColor.getRideTitleColor(),
              fontWeight: FontWeight.w600,
              fontSize: Dimensions.fontLarge,
            ),
          ),
          spaceDown(Dimensions.space20),

          // Pickup Location
          _buildLocationRow(
            Icons.location_on,
            'Pickup Location',
            widget.ride.pickupLocation ?? 'Not specified',
            Colors.green,
          ),

          spaceDown(Dimensions.space20),

          // Route Line
          Container(
            margin: const EdgeInsets.only(left: 20),
            height: 30,
            width: 2,
            color: Colors.grey[300],
          ),

          spaceDown(Dimensions.space20),

          // Destination
          _buildLocationRow(
            Icons.location_on_outlined,
            'Destination',
            widget.ride.destination ?? 'Not specified',
            Colors.red,
          ),

          if (widget.ride.note != null && widget.ride.note!.isNotEmpty) ...[
            spaceDown(Dimensions.space20),
            Container(
              padding: const EdgeInsets.all(Dimensions.space15),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(Dimensions.mediumRadius),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.note, color: Colors.orange, size: 20),
                  spaceSide(Dimensions.space12),
                  Expanded(
                    child: Text(
                      widget.ride.note!,
                      style: regularDefault.copyWith(
                        color: Colors.orange[800],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
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
        spaceSide(Dimensions.space15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: regularDefault.copyWith(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              spaceDown(Dimensions.space8),
              Text(
                address,
                style: regularDefault.copyWith(
                  color: MyColor.colorBlack,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRideDetailsCard() {
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
            text: 'Ride Details',
            textStyle: boldLarge.copyWith(
              color: MyColor.getRideTitleColor(),
              fontWeight: FontWeight.w600,
              fontSize: Dimensions.fontLarge,
            ),
          ),
          spaceDown(Dimensions.space20),
          Row(
            children: [
              Expanded(
                child: _buildDetailItem(
                  Icons.schedule,
                  'Start Time',
                  _formatDateTime(widget.ride.scheduledDateTime),
                ),
              ),
              Expanded(
                child: _buildDetailItem(
                  Icons.people,
                  'Total Seats',
                  widget.ride.numberOfPassengers ?? '0',
                ),
              ),
              Expanded(
                child: _buildDetailItem(
                  Icons.event_seat,
                  'Available Seats',
                  '${_getAvailableSeats()}',
                ),
              ),
            ],
          ),
          spaceDown(Dimensions.space20),
          Row(
            children: [
              Expanded(
                child: _buildDetailItem(
                  Icons.payment,
                  'Payment Type',
                  _getPaymentTypeText(),
                ),
              ),
              Expanded(
                child: _buildDetailItem(
                  Icons.info,
                  'Status',
                  _getRideStatusText(),
                ),
              ),
              Expanded(
                child: _buildDetailItem(
                  Icons.calendar_today,
                  'Created',
                  _formatDateTime(widget.ride.createdAt),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.grey[600],
          size: 24,
        ),
        spaceDown(Dimensions.space8),
        Text(
          label,
          style: regularSmall.copyWith(
            color: Colors.grey[600],
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
        ),
        spaceDown(Dimensions.space4),
        Text(
          value,
          style: regularDefault.copyWith(
            color: MyColor.colorBlack,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildDriverCard() {
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
            text: 'Driver Information',
            textStyle: boldLarge.copyWith(
              color: MyColor.getRideTitleColor(),
              fontWeight: FontWeight.w600,
              fontSize: Dimensions.fontLarge,
            ),
          ),
          spaceDown(Dimensions.space20),
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.blue.withValues(alpha: 0.1),
                child: widget.ride.driver!.avatar != null
                    ? ClipOval(
                        child: Image.network(
                          widget.ride.driver!.avatar!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(Icons.person,
                                color: Colors.blue, size: 30);
                          },
                        ),
                      )
                    : Icon(Icons.person, color: Colors.blue, size: 30),
              ),
              spaceSide(Dimensions.space20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.ride.driver!.firstname} ${widget.ride.driver!.lastname}',
                      style: boldDefault.copyWith(
                        color: MyColor.colorBlack,
                        fontSize: Dimensions.fontLarge,
                      ),
                    ),
                    spaceDown(Dimensions.space8),
                    Text(
                      'Driver',
                      style: regularDefault.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    spaceDown(Dimensions.space8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Dimensions.space8,
                            vertical: Dimensions.space4,
                          ),
                          decoration: BoxDecoration(
                            color: widget.ride.driver!.onlineStatus == '1'
                                ? Colors.green
                                : Colors.grey,
                            borderRadius:
                                BorderRadius.circular(Dimensions.radiusHuge),
                          ),
                          child: Text(
                            widget.ride.driver!.onlineStatus == '1'
                                ? 'Online'
                                : 'Offline',
                            style: regularSmall.copyWith(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        spaceSide(Dimensions.space8),
                        if (widget.ride.driver!.avgRating != null)
                          Row(
                            children: [
                              Icon(Icons.star, color: Colors.amber, size: 16),
                              spaceSide(Dimensions.space4),
                              Text(
                                widget.ride.driver!.avgRating!,
                                style: regularSmall.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard() {
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
            text: 'Service Information',
            textStyle: boldLarge.copyWith(
              color: MyColor.getRideTitleColor(),
              fontWeight: FontWeight.w600,
              fontSize: Dimensions.fontLarge,
            ),
          ),
          spaceDown(Dimensions.space20),
          Row(
            children: [
              Expanded(
                child: _buildServiceDetailItem(
                  Icons.attach_money,
                  'Min Fare',
                  '\$${widget.ride.estimatedFare ?? '0'}',
                ),
              ),
              Expanded(
                child: _buildServiceDetailItem(
                  Icons.attach_money,
                  'Max Fare',
                  '\$${widget.ride.estimatedFare ?? '0'}',
                ),
              ),
              Expanded(
                child: _buildServiceDetailItem(
                  Icons.percent,
                  'Commission',
                  'N/A',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServiceDetailItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(
          icon,
          color: MyColor.primaryColor,
          size: 24,
        ),
        spaceDown(Dimensions.space8),
        Text(
          label,
          style: regularSmall.copyWith(
            color: Colors.grey[600],
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
        ),
        spaceDown(Dimensions.space4),
        Text(
          value,
          style: regularDefault.copyWith(
            color: MyColor.primaryColor,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPassengersCard() {
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
            text: 'Passengers (${widget.ride.passengers?.length ?? 0})',
            textStyle: boldLarge.copyWith(
              color: MyColor.getRideTitleColor(),
              fontWeight: FontWeight.w600,
              fontSize: Dimensions.fontLarge,
            ),
          ),
          spaceDown(Dimensions.space20),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.ride.passengers?.length ?? 0,
            itemBuilder: (context, index) {
              // var passenger = widget.ride.passengers![index];
              return Container(
                margin: const EdgeInsets.only(bottom: Dimensions.space15),
                padding: const EdgeInsets.all(Dimensions.space15),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(Dimensions.mediumRadius),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.blue.withValues(alpha: 0.1),
                      child: Icon(Icons.person, color: Colors.blue, size: 20),
                    ),
                    spaceSide(Dimensions.space15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Passenger ${index + 1}',
                            style: regularDefault.copyWith(
                              fontWeight: FontWeight.w600,
                              color: MyColor.colorBlack,
                            ),
                          ),
                          Text(
                            'Status: Active',
                            style: regularSmall.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              border: Border.all(color: MyColor.primaryColor),
              borderRadius: BorderRadius.circular(Dimensions.mediumRadius),
            ),
            child: TextButton.icon(
              onPressed: () {
                Get.back();
              },
              icon:
                  Icon(Icons.arrow_back, color: MyColor.primaryColor, size: 20),
              label: Text(
                'Back',
                style: regularDefault.copyWith(
                  color: MyColor.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        spaceSide(Dimensions.space15),
        Expanded(
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  MyColor.primaryColor,
                  MyColor.primaryColor.withValues(alpha: 0.8)
                ],
              ),
              borderRadius: BorderRadius.circular(Dimensions.mediumRadius),
            ),
            child: TextButton.icon(
              onPressed: () {
                Get.to(() => JoinRideScreen(ride: widget.ride));
              },
              icon: Icon(Icons.add, color: Colors.white, size: 20),
              label: Text(
                'Join Ride',
                style: regularDefault.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getRideStatusColor() {
    switch (widget.ride.status) {
      case '1':
        return Colors.blue;
      case '2':
        return Colors.orange;
      case '3':
        return Colors.green;
      case '4':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getRideStatusText() {
    switch (widget.ride.status) {
      case '1':
        return 'Scheduled';
      case '2':
        return 'Started';
      case '3':
        return 'Active';
      case '4':
        return 'Completed';
      default:
        return 'Unknown';
    }
  }

  String _getPaymentTypeText() {
    return 'Not specified';
  }

  String _formatDateTime(String? dateTime) {
    if (dateTime == null) return 'Not specified';
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
