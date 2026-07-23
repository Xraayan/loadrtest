import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:loadr/constants.dart';
import 'package:loadr/models/place_suggestion.dart';
import 'package:loadr/models/ride_quote.dart';
import 'package:loadr/services/api_service.dart';
import 'package:loadr/widgets/skeleton.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RequestQuoteArgs {
  final String customerUid;
  final PlaceSuggestion pickup;
  final PlaceSuggestion drop;
  final String vehicleType;
  final String schedule;
  final RideEstimate estimate;

  const RequestQuoteArgs({
    required this.customerUid,
    required this.pickup,
    required this.drop,
    required this.vehicleType,
    required this.schedule,
    required this.estimate,
  });
}

class RequestQuoteScreen extends StatefulWidget {
  const RequestQuoteScreen({super.key});

  @override
  State<RequestQuoteScreen> createState() => _RequestQuoteScreenState();
}

class _RequestQuoteScreenState extends State<RequestQuoteScreen> {
  final _mapController = MapController();
  bool _isPosting = false;
  bool _loadedNearbyDrivers = false;
  List<Map<String, dynamic>> _nearbyDrivers = [];
  double _zoom = 13;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedNearbyDrivers) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! RequestQuoteArgs) return;
    _loadedNearbyDrivers = true;
    _loadNearbyDrivers(args.pickup);
  }

  Future<void> _loadNearbyDrivers(PlaceSuggestion pickup) async {
    final drivers = await ApiService.getNearbyDrivers(
      latitude: pickup.latitude,
      longitude: pickup.longitude,
    );
    if (!mounted) return;
    setState(() => _nearbyDrivers = drivers);
  }

  Future<void> _confirmRequest({
    required RequestQuoteArgs args,
    required VehicleQuote quote,
  }) async {
    setState(() => _isPosting = true);
    try {
      final response = await ApiService.createJob({
        'customer_uid': args.customerUid,
        'title': '${args.vehicleType} load request',
        'pickup_location': args.pickup.displayName,
        'dropoff_location': args.drop.displayName,
        'pickup_coords': {
          'latitude': args.pickup.latitude,
          'longitude': args.pickup.longitude,
        },
        'dropoff_coords': {
          'latitude': args.drop.latitude,
          'longitude': args.drop.longitude,
        },
        'vehicle_type': args.vehicleType,
        'amount': quote.amount,
        'city': args.estimate.city,
        'district': args.estimate.district,
        'state': args.estimate.state,
      });
      await _saveActiveBooking(
        args: args,
        quote: quote,
        response: response,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Load request posted')),
      );
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/customer-home',
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isPosting = false);
      }
    }
  }

  Future<void> _saveActiveBooking({
    required RequestQuoteArgs args,
    required VehicleQuote quote,
    required Map<String, dynamic> response,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'active_booking',
      jsonEncode({
        'job_id': '${response['job_id'] ?? ''}',
        'pickup_location': args.pickup.displayName,
        'dropoff_location': args.drop.displayName,
        'pickup_coords': {
          'latitude': args.pickup.latitude,
          'longitude': args.pickup.longitude,
        },
        'dropoff_coords': {
          'latitude': args.drop.latitude,
          'longitude': args.drop.longitude,
        },
        'vehicle_type': args.vehicleType,
        'schedule': args.schedule,
        'amount': quote.amount,
        'distance_km': args.estimate.distanceKm,
        'route_points': args.estimate.routePoints
            .map(
              (point) => {
                'latitude': point.latitude,
                'longitude': point.longitude,
              },
            )
            .toList(),
        'status': 'open',
        'city': args.estimate.city,
        'district': args.estimate.district,
        'state': args.estimate.state,
        'created_at': DateTime.now().toIso8601String(),
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    if (routeArgs is! RequestQuoteArgs) {
      return const Scaffold(
        body: Center(child: Text('Missing request details')),
      );
    }

    final distanceKm = routeArgs.estimate.distanceKm;
    final quote = routeArgs.estimate.quoteFor(routeArgs.vehicleType);
    final routePoints = routeArgs.estimate.routePoints;
    final pickupPoint = routePoints.isEmpty
        ? LatLng(routeArgs.pickup.latitude, routeArgs.pickup.longitude)
        : routePoints.first;
    final dropPoint = routePoints.isEmpty
        ? LatLng(routeArgs.drop.latitude, routeArgs.drop.longitude)
        : routePoints.last;
    final cameraPoints =
        routePoints.isEmpty ? [pickupPoint, dropPoint] : routePoints;
    final markerSize = routeMarkerSizeForZoom(_zoom);
    final nearbyDriverSize = nearbyDriverMarkerSizeForZoom(_zoom);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCameraFit: CameraFit.coordinates(
                  coordinates: cameraPoints,
                  padding: EdgeInsets.fromLTRB(
                    44,
                    150,
                    44,
                    MediaQuery.sizeOf(context).height * 0.47,
                  ),
                  maxZoom: 15,
                ),
                minZoom: 4,
                maxZoom: 20,
                onPositionChanged: (camera, _) {
                  if ((camera.zoom - _zoom).abs() >= 0.1) {
                    setState(() => _zoom = camera.zoom);
                  }
                },
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.drag |
                      InteractiveFlag.pinchZoom |
                      InteractiveFlag.doubleTapZoom,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: ApiService.mapTileUrlTemplate,
                  retinaMode: false,
                  userAgentPackageName: 'com.example.loadr',
                  panBuffer: 0,
                  maxNativeZoom: 20,
                  maxZoom: 20,
                ),
                PolylineLayer(
                  polylines: [
                    if (routePoints.length >= 2)
                      Polyline(
                        points: routePoints,
                        color: kPrimaryOrange,
                        strokeWidth: 6,
                        borderColor: Colors.white,
                        borderStrokeWidth: 3,
                      ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: pickupPoint,
                      width: markerSize,
                      height: markerSize,
                      child: _RouteMarker(
                        icon: Icons.trip_origin,
                        backgroundColor: Colors.white,
                        foregroundColor: kPrimaryOrange,
                        iconSize: markerSize * 0.48,
                      ),
                    ),
                    Marker(
                      point: dropPoint,
                      width: markerSize,
                      height: markerSize,
                      child: _RouteMarker(
                        icon: Icons.stop,
                        backgroundColor: Colors.black87,
                        foregroundColor: Colors.white,
                        iconSize: markerSize * 0.48,
                      ),
                    ),
                    ..._nearbyDrivers.map(_driverPoint).whereType<LatLng>().map(
                          (point) => Marker(
                            point: point,
                            width: nearbyDriverSize,
                            height: nearbyDriverSize,
                            child: _NearbyDriverMarker(
                              iconSize: nearbyDriverSize * 0.5,
                            ),
                          ),
                        ),
                  ],
                ),
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution(
                      'Geoapify | OpenStreetMap contributors',
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            right: 16,
            top: MediaQuery.paddingOf(context).top + 94,
            child: _MapZoomControls(
              onZoomIn: () => _zoomBy(1),
              onZoomOut: () => _zoomBy(-1),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _RouteHeader(
                pickup: _shortPlaceName(routeArgs.pickup.displayName),
                drop: _shortPlaceName(routeArgs.drop.displayName),
                onBack: () {
                  if (Navigator.canPop(context)) {
                    Navigator.maybePop(context);
                  } else {
                    Navigator.pushReplacementNamed(context, '/request-vehicle');
                  }
                },
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _ConfirmationPanel(
              posted: false,
              posting: _isPosting,
              args: routeArgs,
              quote: quote,
              distanceKm: distanceKm,
              nearbyDriverCount: _nearbyDrivers.length,
              onConfirm: () => _confirmRequest(args: routeArgs, quote: quote),
            ),
          ),
        ],
      ),
    );
  }

  void _zoomBy(double delta) {
    final camera = _mapController.camera;
    final nextZoom = (camera.zoom + delta).clamp(4.0, 18.0).toDouble();
    _mapController.move(camera.center, nextZoom);
  }

  LatLng? _driverPoint(Map<String, dynamic> driver) {
    final latitude = _toDouble(driver['latitude']);
    final longitude = _toDouble(driver['longitude']);
    if (latitude == 0 || longitude == 0) return null;
    return LatLng(latitude, longitude);
  }

  double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? 0;
  }

  static String _shortPlaceName(String value) {
    final parts = value
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return value;
    return parts.first;
  }
}

class _MapZoomControls extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const _MapZoomControls({
    required this.onZoomIn,
    required this.onZoomOut,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 4,
      shadowColor: const Color(0x22000000),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Zoom in',
            onPressed: onZoomIn,
            icon: const Icon(Icons.add, color: Colors.black87),
          ),
          Container(
            width: 26,
            height: 1,
            color: const Color(0xFFE6E6E6),
          ),
          IconButton(
            tooltip: 'Zoom out',
            onPressed: onZoomOut,
            icon: const Icon(Icons.remove, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}

class _RouteHeader extends StatelessWidget {
  final String pickup;
  final String drop;
  final VoidCallback onBack;

  const _RouteHeader({
    required this.pickup,
    required this.drop,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
          ),
          Expanded(
            child: Text(
              '$pickup  >  $drop',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _RouteMarker extends StatelessWidget {
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final double iconSize;

  const _RouteMarker({
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, color: foregroundColor, size: iconSize),
    );
  }
}

class _NearbyDriverMarker extends StatelessWidget {
  final double iconSize;

  const _NearbyDriverMarker({required this.iconSize});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: kPrimaryOrange, width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0x26000000), blurRadius: 10),
        ],
      ),
      child: Icon(
        Icons.local_shipping,
        color: kPrimaryOrange,
        size: iconSize,
      ),
    );
  }
}

class _ConfirmationPanel extends StatelessWidget {
  final bool posted;
  final bool posting;
  final RequestQuoteArgs args;
  final VehicleQuote quote;
  final double distanceKm;
  final int nearbyDriverCount;
  final VoidCallback onConfirm;

  const _ConfirmationPanel({
    required this.posted,
    required this.posting,
    required this.args,
    required this.quote,
    required this.distanceKm,
    required this.nearbyDriverCount,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 24,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE3E3E3),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              posted ? 'Request posted' : 'Choose a vehicle',
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (nearbyDriverCount > 0) ...[
              const SizedBox(height: 6),
              Text(
                '$nearbyDriverCount active ${nearbyDriverCount == 1 ? 'driver' : 'drivers'} near pickup',
                style: const TextStyle(
                  color: Color(0xFF2E7D32),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            const SizedBox(height: 16),
            _VehicleChoiceCard(
              vehicleType: args.vehicleType,
              schedule: args.schedule,
              distanceKm: distanceKm,
              amount: quote.amount,
            ),
            const SizedBox(height: 12),
            _PaymentRow(posted: posted),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: posting ? null : onConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryOrange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: posting
                    ? const SkeletonButtonLabel(width: 152)
                    : Text(
                        posted ? 'Done' : 'Confirm ${args.vehicleType}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleChoiceCard extends StatelessWidget {
  final String vehicleType;
  final String schedule;
  final double distanceKm;
  final double amount;

  const _VehicleChoiceCard({
    required this.vehicleType,
    required this.schedule,
    required this.distanceKm,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kPrimaryOrange, width: 1.4),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.local_shipping_outlined,
              color: kPrimaryOrange,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vehicleType,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$schedule pickup - ${distanceKm.toStringAsFixed(1)} km',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                const _FasterBadge(),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Rs ${amount.toStringAsFixed(0)}',
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _FasterBadge extends StatelessWidget {
  const _FasterBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE9F1FF),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'Best available',
        style: TextStyle(
          color: Color(0xFF2457A6),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final bool posted;

  const _PaymentRow({required this.posted});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            posted ? Icons.check_circle : Icons.route,
            color: posted ? Colors.green : const Color(0xA3000000),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              posted
                  ? 'Drivers can now see this load'
                  : 'Pay after driver accepts',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.black38),
        ],
      ),
    );
  }
}
