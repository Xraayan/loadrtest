import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:loadr/constants.dart';
import 'package:loadr/models/place_suggestion.dart';
import 'package:loadr/models/ride_quote.dart';
import 'package:loadr/services/api_service.dart';
import 'package:loadr/widgets/skeleton.dart';

class DriverLoadRequestScreen extends StatefulWidget {
  const DriverLoadRequestScreen({super.key});

  @override
  State<DriverLoadRequestScreen> createState() =>
      _DriverLoadRequestScreenState();
}

class _DriverLoadRequestScreenState extends State<DriverLoadRequestScreen> {
  final _mapController = MapController();
  Map<String, dynamic>? _job;
  RideEstimate? _estimate;
  bool _isLoading = true;
  bool _isAccepting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      _loadRequest(args is Map ? Map<String, dynamic>.from(args) : null);
    });
  }

  Future<void> _loadRequest(Map<String, dynamic>? job) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (job == null) throw Exception('Load request not found');
      final pickup = _placeFromJob(job, pickup: true);
      final drop = _placeFromJob(job, pickup: false);
      final estimate = await ApiService.estimateRide(
        pickup: pickup,
        drop: drop,
        vehicleType: _text(job['vehicle_type'], fallback: 'Tata Ace'),
        schedule: 'Now',
      );
      if (!mounted) return;
      setState(() {
        _job = job;
        _estimate = estimate;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _isLoading = false;
      });
    }
  }

  Future<void> _acceptLoad() async {
    final job = _job;
    if (job == null) return;

    setState(() => _isAccepting = true);
    try {
      final uid = await ApiService.getUid();
      if (uid == null) throw Exception('User not authenticated');

      final activeJob = await ApiService.getDriverActiveJob(uid);
      if (activeJob != null) {
        throw Exception('Finish your active load before accepting another one');
      }

      final jobId = '${job['job_id'] ?? job['id']}';
      final response = await ApiService.acceptJob(uid, jobId);
      final acceptedJob = response['job'] is Map
          ? Map<String, dynamic>.from(response['job'] as Map)
          : job;
      final activeLoad = {
        ...acceptedJob,
        'status': 'accepted',
        'trip_id': response['trip_id'],
      };
      await ApiService.cacheDriverActiveJob(activeLoad);

      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        '/driver-active-trip',
        arguments: activeLoad,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Accept failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isAccepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MapScreenSkeleton();
    }

    final job = _job;
    final estimate = _estimate;
    if (job == null || estimate == null || _error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F7F7),
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: const Text('Load request'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _goBack,
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _error ?? 'Load request not found',
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
    final routePoints = estimate.routePoints.isEmpty
        ? [pickupPoint, dropPoint]
        : estimate.routePoints;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCameraFit: CameraFit.coordinates(
                  coordinates: routePoints,
                  padding: EdgeInsets.fromLTRB(
                    44,
                    150,
                    44,
                    MediaQuery.sizeOf(context).height * 0.49,
                  ),
                  maxZoom: 15,
                ),
                minZoom: 4,
                maxZoom: 20,
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
                onBack: _goBack,
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _LoadRequestPanel(
              job: job,
              estimate: estimate,
              isAccepting: _isAccepting,
              onAccept: _acceptLoad,
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

  void _goBack() {
    if (Navigator.canPop(context)) {
      Navigator.maybePop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/new-trips');
    }
  }
}

class _LoadRequestPanel extends StatelessWidget {
  final Map<String, dynamic> job;
  final RideEstimate estimate;
  final bool isAccepting;
  final VoidCallback onAccept;

  const _LoadRequestPanel({
    required this.job,
    required this.estimate,
    required this.isAccepting,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final amount = _asDouble(job['amount']);
    final vehicleType = _text(job['vehicle_type'], fallback: 'Vehicle');
    final city = _text(job['city'], fallback: 'Any city');
    final district = _text(job['district'], fallback: 'Any district');
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Text(
                    'Load request',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  'Rs ${amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: kPrimaryOrange,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _RouteSummary(pickup: pickup, drop: drop),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                    icon: Icons.local_shipping_outlined, label: vehicleType),
                _InfoChip(
                  icon: Icons.route,
                  label: '${estimate.distanceKm.toStringAsFixed(1)} km',
                ),
                _InfoChip(icon: Icons.location_city_outlined, label: city),
                _InfoChip(icon: Icons.map_outlined, label: district),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: isAccepting ? null : onAccept,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryOrange,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: kPrimaryOrange.withOpacity(0.55),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: isAccepting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  isAccepting ? 'Accepting...' : 'Accept Load',
                  style: const TextStyle(fontWeight: FontWeight.w900),
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

PlaceSuggestion _placeFromJob(Map<String, dynamic> job,
    {required bool pickup}) {
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
  return parts.length <= 2 ? parts.join(', ') : parts.take(2).join(', ');
}
