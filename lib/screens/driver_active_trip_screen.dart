import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:loadr/constants.dart';
import 'package:loadr/models/place_suggestion.dart';
import 'package:loadr/models/ride_quote.dart';
import 'package:loadr/services/api_service.dart';

class DriverActiveTripScreen extends StatefulWidget {
  const DriverActiveTripScreen({super.key});

  @override
  State<DriverActiveTripScreen> createState() => _DriverActiveTripScreenState();
}

class _DriverActiveTripScreenState extends State<DriverActiveTripScreen> {
  final _mapController = MapController();
  Map<String, dynamic>? _job;
  RideEstimate? _estimate;
  RideEstimate? _approachEstimate;
  LatLng? _currentPoint;
  StreamSubscription<Position>? _positionSubscription;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      _loadTrip(args is Map ? Map<String, dynamic>.from(args) : null);
    });
  }

  Future<void> _loadTrip(Map<String, dynamic>? initialJob) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final uid = await ApiService.getUid();
      if (uid == null) {
        throw Exception('User not authenticated');
      }

      final backendJob = await ApiService.getDriverActiveJob(uid);
      final job = backendJob ?? initialJob;
      if (job == null) {
        throw Exception('No active load found');
      }

      final pickup = _placeFromJob(job, pickup: true);
      final drop = _placeFromJob(job, pickup: false);
      final currentPoint = await _currentDriverPoint(uid, pickup);
      final currentPlace = PlaceSuggestion(
        displayName: 'Your current location',
        latitude: currentPoint.latitude,
        longitude: currentPoint.longitude,
      );
      final approachEstimate = await ApiService.estimateRide(
        pickup: currentPlace,
        drop: pickup,
        vehicleType: _text(job['vehicle_type'], fallback: 'Pickup'),
        schedule: 'Now',
      );
      final estimate = await ApiService.estimateRide(
        pickup: pickup,
        drop: drop,
        vehicleType: _text(job['vehicle_type'], fallback: 'Pickup'),
        schedule: 'Now',
      );

      if (!mounted) return;
      setState(() {
        _job = job;
        _estimate = estimate;
        _approachEstimate = approachEstimate;
        _currentPoint = currentPoint;
        _isLoading = false;
      });
      _startLocationUpdates(uid);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: kPrimaryOrange)),
      );
    }

    final job = _job;
    final estimate = _estimate;
    final approachEstimate = _approachEstimate;
    final currentPoint = _currentPoint;
    if (job == null ||
        estimate == null ||
        approachEstimate == null ||
        currentPoint == null ||
        _error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F7F7),
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: const Text('Active trip'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _goBack(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _error ?? 'No active load found',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }

    final pickup = _placeFromJob(job, pickup: true);
    final drop = _placeFromJob(job, pickup: false);
    final pickupPoint = LatLng(pickup.latitude, pickup.longitude);
    final dropPoint = LatLng(drop.latitude, drop.longitude);
    final loadRoutePoints =
        estimate.routePoints.isEmpty ? [pickupPoint, dropPoint] : estimate.routePoints;
    final approachRoutePoints = approachEstimate.routePoints.isEmpty
        ? [currentPoint, pickupPoint]
        : [currentPoint, ...approachEstimate.routePoints.skip(1)];
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCameraFit: CameraFit.coordinates(
                  coordinates: [...approachRoutePoints, ...loadRoutePoints],
                  padding: EdgeInsets.fromLTRB(
                    44,
                    150,
                    44,
                    MediaQuery.sizeOf(context).height * 0.52,
                  ),
                  maxZoom: 15,
                ),
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
                  panBuffer: 0,
                  maxZoom: 19,
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: approachRoutePoints,
                      color: const Color(0xFF333333),
                      strokeWidth: 5,
                      borderColor: Colors.white,
                      borderStrokeWidth: 3,
                    ),
                    Polyline(
                      points: loadRoutePoints,
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
                      point: currentPoint,
                      width: 46,
                      height: 46,
                      child: const _RouteMarker(
                        icon: Icons.local_shipping,
                        backgroundColor: kPrimaryOrange,
                        foregroundColor: Colors.white,
                      ),
                    ),
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
          ),
          Positioned(
            right: 16,
            top: MediaQuery.paddingOf(context).top + 88,
            child: _MapZoomControls(
              onZoomIn: () => _zoomBy(1),
              onZoomOut: () => _zoomBy(-1),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _TopBar(
                pickup: _shortLocation(pickup.displayName),
                drop: _shortLocation(drop.displayName),
                onBack: () => _goBack(context),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _TripPanel(
              job: job,
              estimate: estimate,
              approachDistanceKm: approachEstimate.distanceKm,
              onRefresh: () => _loadTrip(null),
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

  Future<LatLng> _currentDriverPoint(
    String uid,
    PlaceSuggestion pickup,
  ) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
        ),
      );
      await ApiService.updateLocation(uid, {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'is_active': true,
      });
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      try {
        final location = await ApiService.getDriverLocation(uid);
        final latitude = _asDouble(location['latitude']);
        final longitude = _asDouble(location['longitude']);
        if (latitude != 0 && longitude != 0) {
          return LatLng(latitude, longitude);
        }
      } catch (_) {}
      return LatLng(pickup.latitude, pickup.longitude);
    }
  }

  void _startLocationUpdates(String uid) {
    if (_positionSubscription != null) return;
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50,
      ),
    ).listen((position) async {
      if (mounted) {
        setState(() {
          _currentPoint = LatLng(position.latitude, position.longitude);
        });
      }
      try {
        await ApiService.updateLocation(uid, {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'is_active': true,
        });
      } catch (_) {
        // The next movement update retries automatically.
      }
    }, onError: (_) {});
  }

  void _goBack(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.maybePop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }
}

class _TripPanel extends StatelessWidget {
  final Map<String, dynamic> job;
  final RideEstimate estimate;
  final double approachDistanceKm;
  final VoidCallback onRefresh;

  const _TripPanel({
    required this.job,
    required this.estimate,
    required this.approachDistanceKm,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final amount = _asDouble(job['amount']);
    final status = _text(job['status'], fallback: 'accepted');
    final vehicleType = _text(job['vehicle_type'], fallback: 'Vehicle');
    final pickup = _shortLocation(_text(job['pickup_location']));
    final drop = _shortLocation(_text(job['dropoff_location']));

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
                const Expanded(
                  child: Text(
                    'Accepted load',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _StatusPill(label: status),
              ],
            ),
            const SizedBox(height: 14),
            _RouteSummary(pickup: pickup, drop: drop),
            const SizedBox(height: 14),
            Row(
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
                      _InfoChip(
                        icon: Icons.near_me_outlined,
                        label: '${approachDistanceKm.toStringAsFixed(1)} km to pickup',
                      ),
                      _InfoChip(
                        icon: Icons.route,
                        label: '${estimate.distanceKm.toStringAsFixed(1)} km load trip',
                      ),
                      _InfoChip(
                        icon: Icons.straighten,
                        label:
                            '${(approachDistanceKm + estimate.distanceKm).toStringAsFixed(1)} km total',
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
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: onRefresh,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryOrange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.refresh),
                label: const Text(
                  'Refresh trip',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String pickup;
  final String drop;
  final VoidCallback onBack;

  const _TopBar({
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
          _RouteLine(icon: Icons.trip_origin, label: 'Pickup', value: pickup),
          const Divider(height: 22),
          _RouteLine(icon: Icons.stop, label: 'Drop', value: drop),
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

  const _StatusPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.replaceAll('_', ' ').toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF2E7D32),
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

PlaceSuggestion _placeFromJob(Map<String, dynamic> job, {required bool pickup}) {
  final prefix = pickup ? 'pickup' : 'dropoff';
  final coords = job['${prefix}_coords'];
  if (coords is! Map) {
    throw Exception('Missing ${pickup ? 'pickup' : 'drop'} coordinates');
  }

  return PlaceSuggestion(
    displayName: _text(job['${prefix}_location']),
    latitude: _asDouble(coords['latitude']),
    longitude: _asDouble(coords['longitude']),
    city: _text(job['city']),
    district: _text(job['district']),
    state: _text(job['state']),
  );
}

double _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}') ?? 0;
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
