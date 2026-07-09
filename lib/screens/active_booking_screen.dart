import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:loadr/constants.dart';
import 'package:loadr/models/place_suggestion.dart';
import 'package:loadr/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ActiveBookingScreen extends StatefulWidget {
  const ActiveBookingScreen({super.key});

  @override
  State<ActiveBookingScreen> createState() => _ActiveBookingScreenState();
}

class _ActiveBookingScreenState extends State<ActiveBookingScreen> {
  final _mapController = MapController();
  Map<String, dynamic>? _booking;
  bool _isLoading = true;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadBooking();
  }

  Future<void> _loadBooking() async {
    setState(() => _isLoading = true);
    final booking = await _readLocalBooking();
    if (!mounted) return;
    setState(() {
      _booking = booking;
      _isLoading = false;
    });
    await _refreshJobStatus(showErrors: false);
  }

  Future<Map<String, dynamic>?> _readLocalBooking() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('active_booking');
    if (json == null || json.trim().isEmpty) return null;

    final decoded = jsonDecode(json);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    return null;
  }

  Future<void> _refreshJobStatus({bool showErrors = true}) async {
    final booking = _booking;
    final jobId = '${booking?['job_id'] ?? ''}'.trim();
    if (booking == null || jobId.isEmpty) return;

    setState(() => _isRefreshing = true);
    try {
      final job = await ApiService.getJob(jobId);
      final merged = _mergeJobIntoBooking(booking, job);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_booking', jsonEncode(merged));

      if (!mounted) return;
      setState(() => _booking = merged);
    } catch (e) {
      if (mounted && showErrors) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status refresh failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Map<String, dynamic> _mergeJobIntoBooking(
    Map<String, dynamic> booking,
    Map<String, dynamic> job,
  ) {
    final driver = job['driver'];
    return {
      ...booking,
      'status': job['status'] ?? booking['status'],
      'assigned_driver_uid':
          job['assigned_driver_uid'] ?? booking['assigned_driver_uid'],
      'assigned_trip_id': job['assigned_trip_id'] ?? booking['assigned_trip_id'],
      'assigned_at': job['assigned_at'] ?? booking['assigned_at'],
      'pickup_location': job['pickup_location'] ?? booking['pickup_location'],
      'dropoff_location': job['dropoff_location'] ?? booking['dropoff_location'],
      'pickup_coords': job['pickup_coords'] ?? booking['pickup_coords'],
      'dropoff_coords': job['dropoff_coords'] ?? booking['dropoff_coords'],
      'vehicle_type': job['vehicle_type'] ?? booking['vehicle_type'],
      'amount': job['amount'] ?? booking['amount'],
      if (driver is Map) 'driver': Map<String, dynamic>.from(driver),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final booking = _booking;
    if (booking == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F7F7),
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: const Text('Active booking'),
        ),
        body: const Center(
          child: Text('No active booking found'),
        ),
      );
    }

    final pickup = _placeFromBooking(booking, 'pickup');
    final drop = _placeFromBooking(booking, 'dropoff');

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: Stack(
        children: [
          if (pickup != null && drop != null)
            _RouteMap(
              controller: _mapController,
              pickup: pickup,
              drop: drop,
              routePoints: _routePointsFromBooking(booking, pickup, drop),
              onZoomIn: () => _zoomBy(1),
              onZoomOut: () => _zoomBy(-1),
            )
          else
            const _MissingMap(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _TopBar(
                onBack: () {
                  if (Navigator.canPop(context)) {
                    Navigator.maybePop(context);
                  } else {
                    Navigator.pushReplacementNamed(context, '/customer-home');
                  }
                },
                onRefresh: _isRefreshing
                    ? null
                    : () => _refreshJobStatus(showErrors: true),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _BookingPanel(
              booking: booking,
              refreshing: _isRefreshing,
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
}

class _RouteMap extends StatelessWidget {
  final MapController controller;
  final PlaceSuggestion pickup;
  final PlaceSuggestion drop;
  final List<LatLng> routePoints;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const _RouteMap({
    required this.controller,
    required this.pickup,
    required this.drop,
    required this.routePoints,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  @override
  Widget build(BuildContext context) {
    final pickupPoint = LatLng(pickup.latitude, pickup.longitude);
    final dropPoint = LatLng(drop.latitude, drop.longitude);
    final center = LatLng(
      (pickup.latitude + drop.latitude) / 2,
      (pickup.longitude + drop.longitude) / 2,
    );
    return Stack(
      children: [
        FlutterMap(
          mapController: controller,
          options: MapOptions(
            initialCenter: center,
            initialZoom: _initialZoom(pickupPoint, dropPoint),
            minZoom: 4,
            maxZoom: 18,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.drag |
                  InteractiveFlag.pinchZoom |
                  InteractiveFlag.doubleTapZoom,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: ApiService.mapTileUrlTemplate,
              userAgentPackageName: 'com.loadr.app',
              tileSize: 512,
              maxZoom: 19,
            ),
            PolylineLayer(
              polylines: [
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
                  width: 46,
                  height: 46,
                  child: const _RouteMarker(
                    icon: Icons.trip_origin,
                    backgroundColor: Colors.white,
                    foregroundColor: kPrimaryOrange,
                  ),
                ),
                Marker(
                  point: dropPoint,
                  width: 46,
                  height: 46,
                  child: const _RouteMarker(
                    icon: Icons.stop,
                    backgroundColor: Colors.black87,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
        Positioned(
          right: 16,
          top: MediaQuery.paddingOf(context).top + 88,
          child: _MapZoomControls(
            onZoomIn: onZoomIn,
            onZoomOut: onZoomOut,
          ),
        ),
      ],
    );
  }
}

class _MissingMap extends StatelessWidget {
  const _MissingMap();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEFEFEF),
      alignment: Alignment.topCenter,
      padding: const EdgeInsets.only(top: 140),
      child: const Text(
        'Map will appear for bookings with coordinates',
        style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback? onRefresh;

  const _TopBar({
    required this.onBack,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 18,
            offset: Offset(0, 8),
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
          const Expanded(
            child: Text(
              'Active booking',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.black87,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Refresh status',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}

class _BookingPanel extends StatelessWidget {
  final Map<String, dynamic> booking;
  final bool refreshing;

  const _BookingPanel({
    required this.booking,
    required this.refreshing,
  });

  @override
  Widget build(BuildContext context) {
    final status = _bookingStatus(booking);
    final accepted = _isAccepted(booking);
    final driver = booking['driver'];
    final driverMap =
        driver is Map ? Map<String, dynamic>.from(driver) : <String, dynamic>{};
    final driverName = _text(driverMap['name'], fallback: 'Driver');
    final vehicleNumber = _text(
      driverMap['vehicle_number'],
      fallback: _text(booking['vehicle_number'], fallback: 'Vehicle pending'),
    );
    final pickup = _shortLocation(_text(booking['pickup_location']));
    final drop = _shortLocation(_text(booking['dropoff_location']));
    final vehicleType = _text(booking['vehicle_type'], fallback: 'Vehicle');
    final amount = _asDouble(booking['amount']);
    final distanceKm = _asDouble(booking['distance_km']);

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3E3E3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      status.title,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _StatusPill(label: status.pill, active: accepted),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                status.subtitle,
                style: const TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (refreshing) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(minHeight: 3),
              ],
              const SizedBox(height: 16),
              if (accepted)
                _DriverCard(
                  name: driverName,
                  vehicleNumber: vehicleNumber,
                )
              else
                const _WaitingDriverCard(),
              const SizedBox(height: 16),
              _RouteSummary(
                pickup: pickup,
                drop: drop,
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _InfoChip(
                          icon: Icons.local_shipping_outlined,
                          label: vehicleType,
                        ),
                        if (distanceKm > 0)
                          _InfoChip(
                            icon: Icons.route,
                            label: '${distanceKm.toStringAsFixed(1)} km',
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Rs ${amount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
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
}

class _DriverCard extends StatelessWidget {
  final String name;
  final String vehicleNumber;

  const _DriverCard({
    required this.name,
    required this.vehicleNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFD7CA)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: kPrimaryOrange),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
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
                  vehicleNumber,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.verified, color: kPrimaryOrange),
        ],
      ),
    );
  }
}

class _WaitingDriverCard extends StatelessWidget {
  const _WaitingDriverCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Waiting for a nearby driver to accept your load',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteSummary extends StatelessWidget {
  final String pickup;
  final String drop;

  const _RouteSummary({
    required this.pickup,
    required this.drop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEAEAEA)),
      ),
      child: Column(
        children: [
          _RouteLine(
            icon: Icons.trip_origin,
            label: 'Pickup',
            value: pickup,
          ),
          const Divider(height: 22),
          _RouteLine(
            icon: Icons.stop,
            label: 'Drop',
            value: drop,
          ),
        ],
      ),
    );
  }
}

class _RouteLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _RouteLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: kPrimaryOrange),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.black45,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value.isEmpty ? '-' : value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.black54),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final bool active;

  const _StatusPill({
    required this.label,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE8F5E9) : const Color(0xFFFFF0EA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? const Color(0xFF2E7D32) : kPrimaryOrange,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _RouteMarker extends StatelessWidget {
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;

  const _RouteMarker({
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
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
      child: Icon(icon, color: foregroundColor, size: 22),
    );
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

class _BookingStatus {
  final String title;
  final String subtitle;
  final String pill;

  const _BookingStatus({
    required this.title,
    required this.subtitle,
    required this.pill,
  });
}

_BookingStatus _bookingStatus(Map<String, dynamic> booking) {
  if (_isAccepted(booking)) {
    return const _BookingStatus(
      title: 'Driver accepted',
      subtitle: 'Your assigned driver is preparing for pickup.',
      pill: 'Accepted',
    );
  }

  return const _BookingStatus(
    title: 'Finding driver',
    subtitle: 'Your load is visible to available drivers.',
    pill: 'Open',
  );
}

bool _isAccepted(Map<String, dynamic> booking) {
  final status = _text(booking['status']).toLowerCase();
  return status == 'assigned' ||
      status == 'accepted' ||
      _text(booking['assigned_driver_uid']).isNotEmpty;
}

PlaceSuggestion? _placeFromBooking(
  Map<String, dynamic> booking,
  String prefix,
) {
  final coords = booking['${prefix}_coords'];
  if (coords is! Map) return null;

  final latitude = _asDouble(coords['latitude']);
  final longitude = _asDouble(coords['longitude']);
  if (latitude == 0 || longitude == 0) return null;

  return PlaceSuggestion(
    displayName: _text(booking['${prefix}_location']),
    latitude: latitude,
    longitude: longitude,
  );
}

List<LatLng> _routePointsFromBooking(
  Map<String, dynamic> booking,
  PlaceSuggestion pickup,
  PlaceSuggestion drop,
) {
  final points = booking['route_points'];
  if (points is List) {
    final routePoints = points.whereType<Map>().map((point) {
      final map = Map<String, dynamic>.from(point);
      return LatLng(
        _asDouble(map['latitude']),
        _asDouble(map['longitude']),
      );
    }).where((point) {
      return point.latitude != 0 && point.longitude != 0;
    }).toList();
    if (routePoints.isNotEmpty) return routePoints;
  }

  return [
    LatLng(pickup.latitude, pickup.longitude),
    LatLng(drop.latitude, drop.longitude),
  ];
}

double _initialZoom(LatLng pickup, LatLng drop) {
  const distance = Distance();
  final km = distance.as(LengthUnit.Kilometer, pickup, drop);
  if (km < 5) return 13.5;
  if (km < 15) return 12;
  if (km < 35) return 10.8;
  if (km < 80) return 9.4;
  return 8;
}

double _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

String _text(Object? value, {String fallback = ''}) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty ? fallback : text;
}

String _shortLocation(String value) {
  final parts = value
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return value;
  return parts.first;
}
