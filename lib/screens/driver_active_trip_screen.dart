import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:loadr/constants.dart';
import 'package:loadr/models/place_suggestion.dart';
import 'package:loadr/models/ride_quote.dart';
import 'package:loadr/services/api_service.dart';
import 'package:loadr/widgets/skeleton.dart';

class DriverActiveTripScreen extends StatefulWidget {
  const DriverActiveTripScreen({super.key});

  @override
  State<DriverActiveTripScreen> createState() => _DriverActiveTripScreenState();
}

class _DriverActiveTripScreenState extends State<DriverActiveTripScreen>
    with WidgetsBindingObserver {
  final _mapController = MapController();
  Map<String, dynamic>? _job;
  RideEstimate? _estimate;
  RideEstimate? _approachEstimate;
  LatLng? _currentPoint;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<Map<String, dynamic>?>? _tripSubscription;
  String? _driverUid;
  bool _isLoading = true;
  bool _isUpdatingStatus = false;
  String? _error;
  double _zoom = 13;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      _driverUid = uid;

      final backendJob = await ApiService.getDriverActiveJob(uid);
      final job = backendJob ?? initialJob;
      if (job == null) {
        throw Exception('No active load found');
      }

      final pickup = _placeFromJob(job, pickup: true);
      final drop = _placeFromJob(job, pickup: false);
      final pickedUp = _isPickedUp(job);
      final currentPoint = await _currentDriverPoint(uid, pickup);
      final currentPlace = PlaceSuggestion(
        displayName: 'Your current location',
        latitude: currentPoint.latitude,
        longitude: currentPoint.longitude,
      );
      final approachFuture = ApiService.estimateRide(
        pickup: currentPlace,
        drop: pickedUp ? drop : pickup,
        vehicleType: _text(job['vehicle_type'], fallback: 'Tata Ace'),
        schedule: 'Now',
      );
      final estimates = pickedUp
          ? [await approachFuture]
          : await Future.wait([
              approachFuture,
              ApiService.estimateRide(
                pickup: pickup,
                drop: drop,
                vehicleType: _text(job['vehicle_type'], fallback: 'Tata Ace'),
                schedule: 'Now',
              ),
            ]);
      final approachEstimate = estimates.first;
      final estimate = pickedUp ? approachEstimate : estimates.last;

      if (!mounted) return;
      setState(() {
        _job = job;
        _estimate = estimate;
        _approachEstimate = approachEstimate;
        _currentPoint = currentPoint;
        _isLoading = false;
      });
      _startLocationUpdates(uid);
      _startTripStream(uid);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _isLoading = false;
      });
    }
  }

  void _startTripStream(String uid) {
    _tripSubscription?.cancel();
    _tripSubscription = ApiService.streamDriverActiveJob(uid).listen(
      (job) async {
        if (!mounted) return;
        if (job == null) {
          await ApiService.clearDriverActiveJob();
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/dashboard');
          return;
        }

        final current = _job;
        final next = current == null ? job : _mergeJob(current, job);
        await ApiService.cacheDriverActiveJob(next);
        if (!mounted) return;
        setState(() => _job = next);
      },
      onError: (_) {
        // Manual refresh keeps the screen usable if the stream drops.
      },
    );
  }

  Map<String, dynamic> _mergeJob(
    Map<String, dynamic> current,
    Map<String, dynamic> incoming,
  ) {
    return {
      ...current,
      ...incoming,
      'route_points': incoming['route_points'] ?? current['route_points'],
      'pickup_coords': incoming['pickup_coords'] ?? current['pickup_coords'],
      'dropoff_coords': incoming['dropoff_coords'] ?? current['dropoff_coords'],
      'trip_id': incoming['trip_id'] ??
          current['trip_id'] ??
          incoming['assigned_trip_id'] ??
          current['assigned_trip_id'],
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MapScreenSkeleton();
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
    final rawPickupPoint = LatLng(pickup.latitude, pickup.longitude);
    final rawDropPoint = LatLng(drop.latitude, drop.longitude);
    final pickedUp = _isPickedUp(job);
    final savedLoadRoutePoints = _routePointsFromJob(job);
    final loadRoutePoints = !pickedUp && savedLoadRoutePoints.isNotEmpty
        ? savedLoadRoutePoints
        : estimate.routePoints;
    final approachRoutePoints = approachEstimate.routePoints;
    final pickupPoint = approachRoutePoints.isEmpty
        ? (loadRoutePoints.isEmpty ? rawPickupPoint : loadRoutePoints.first)
        : approachRoutePoints.last;
    final dropPoint =
        loadRoutePoints.isEmpty ? rawDropPoint : loadRoutePoints.last;
    final activeRoutePoints = pickedUp ? loadRoutePoints : approachRoutePoints;
    final routedCameraPoints = pickedUp
        ? activeRoutePoints
        : [...approachRoutePoints, ...loadRoutePoints];
    final cameraPoints = routedCameraPoints.isEmpty
        ? [currentPoint, pickupPoint, dropPoint]
        : routedCameraPoints;
    final distanceToPickupKm = _distanceKm(currentPoint, pickupPoint);
    final distanceToDropKm = _distanceKm(currentPoint, dropPoint);
    final canConfirmPickup = !pickedUp &&
        (distanceToPickupKm <= _pickupConfirmRadiusKm ||
            _text(job['status']).toLowerCase() == 'arriving');
    final canConfirmDropoff =
        pickedUp && distanceToDropKm <= _dropoffConfirmRadiusKm;
    final markerSize = routeMarkerSizeForZoom(_zoom);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
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
                    MediaQuery.sizeOf(context).height * 0.52,
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
                    if (!pickedUp && approachRoutePoints.length >= 2)
                      Polyline(
                        points: approachRoutePoints,
                        color: const Color(0xFF333333),
                        strokeWidth: 5,
                        borderColor: Colors.white,
                        borderStrokeWidth: 3,
                      ),
                    if ((pickedUp ? activeRoutePoints : loadRoutePoints)
                            .length >=
                        2)
                      Polyline(
                        points: pickedUp ? activeRoutePoints : loadRoutePoints,
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
                      width: markerSize,
                      height: markerSize,
                      child: _RouteMarker(
                        icon: Icons.local_shipping,
                        backgroundColor: kPrimaryOrange,
                        foregroundColor: Colors.white,
                        iconSize: markerSize * 0.5,
                      ),
                    ),
                    if (!pickedUp)
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
                onBack: () => _goBack(context),
              ),
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.42,
            minChildSize: 0.18,
            maxChildSize: 0.72,
            snap: true,
            snapSizes: const [0.18, 0.42, 0.72],
            builder: (context, scrollController) => _TripPanel(
              scrollController: scrollController,
              job: job,
              estimate: estimate,
              distanceToNextKm:
                  pickedUp ? estimate.distanceKm : approachEstimate.distanceKm,
              pickedUp: pickedUp,
              canConfirmPickup: canConfirmPickup,
              canConfirmDropoff: canConfirmDropoff,
              isUpdatingStatus: _isUpdatingStatus,
              onConfirmPickup: _confirmPickup,
              onConfirmDropoff: _confirmDropoff,
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
    unawaited(_pushCurrentLocation(uid));
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
        intervalDuration: const Duration(seconds: 5),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'LoadR active trip',
          notificationText: 'Sharing your live location with the customer.',
          notificationChannelName: 'Driver location',
          enableWakeLock: true,
          setOngoing: true,
        ),
      ),
    ).listen((position) async {
      final point = LatLng(position.latitude, position.longitude);
      if (mounted) {
        final job = _job;
        setState(() {
          _currentPoint = point;
          if (job != null && !_isPickedUp(job)) {
            final pickup = _placeFromJob(job, pickup: true);
            final pickupPoint = LatLng(pickup.latitude, pickup.longitude);
            if (_distanceKm(point, pickupPoint) <= _pickupConfirmRadiusKm) {
              _job = {...job, 'status': 'arriving'};
            }
          }
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

  Future<void> _pushCurrentLocation(String uid) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
        ),
      );
      final point = LatLng(position.latitude, position.longitude);
      if (mounted) setState(() => _currentPoint = point);
      await ApiService.updateLocation(uid, {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'is_active': true,
      });
    } catch (_) {}
  }

  void _stopLocationUpdates() {
    final subscription = _positionSubscription;
    _positionSubscription = null;
    subscription?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final uid = _driverUid;
    if (uid != null && _job != null) _startLocationUpdates(uid);
  }

  Future<void> _confirmPickup() async {
    final job = _job;
    if (job == null) return;

    final tripId =
        _text(job['trip_id'], fallback: _text(job['assigned_trip_id']));
    if (tripId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip ID is missing')),
      );
      return;
    }

    setState(() => _isUpdatingStatus = true);
    try {
      await ApiService.updateTripStatus(tripId, 'in_progress');
      final updatedJob = {...job, 'status': 'in_progress', 'trip_id': tripId};
      await ApiService.cacheDriverActiveJob(updatedJob);
      if (!mounted) return;
      setState(() => _job = updatedJob);
      await _loadTrip(updatedJob);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pickup update failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
      }
    }
  }

  Future<void> _confirmDropoff() async {
    final job = _job;
    if (job == null) return;

    final tripId =
        _text(job['trip_id'], fallback: _text(job['assigned_trip_id']));
    if (tripId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip ID is missing')),
      );
      return;
    }

    setState(() => _isUpdatingStatus = true);
    try {
      await ApiService.updateTripStatus(tripId, 'completed');
      await ApiService.clearDriverActiveJob();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip completed')),
      );
      Navigator.pushReplacementNamed(context, '/dashboard');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Drop-off update failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
      }
    }
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
    WidgetsBinding.instance.removeObserver(this);
    _tripSubscription?.cancel();
    _stopLocationUpdates();
    super.dispose();
  }
}

class _TripPanel extends StatelessWidget {
  final ScrollController scrollController;
  final Map<String, dynamic> job;
  final RideEstimate estimate;
  final double distanceToNextKm;
  final bool pickedUp;
  final bool canConfirmPickup;
  final bool canConfirmDropoff;
  final bool isUpdatingStatus;
  final VoidCallback onConfirmPickup;
  final VoidCallback onConfirmDropoff;
  final VoidCallback onRefresh;

  const _TripPanel({
    required this.scrollController,
    required this.job,
    required this.estimate,
    required this.distanceToNextKm,
    required this.pickedUp,
    required this.canConfirmPickup,
    required this.canConfirmDropoff,
    required this.isUpdatingStatus,
    required this.onConfirmPickup,
    required this.onConfirmDropoff,
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
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
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
                    pickedUp ? 'On the way to drop-off' : 'Accepted load',
                    style: const TextStyle(
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
                        label:
                            '${distanceToNextKm.toStringAsFixed(1)} km to ${pickedUp ? 'drop' : 'pickup'}',
                      ),
                      _InfoChip(
                        icon: Icons.route,
                        label:
                            '${estimate.distanceKm.toStringAsFixed(1)} km load trip',
                      ),
                      if (!pickedUp)
                        _InfoChip(
                          icon: Icons.straighten,
                          label:
                              '${(distanceToNextKm + estimate.distanceKm).toStringAsFixed(1)} km total',
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
                onPressed: isUpdatingStatus
                    ? null
                    : pickedUp
                        ? canConfirmDropoff
                            ? onConfirmDropoff
                            : onRefresh
                        : canConfirmPickup
                            ? onConfirmPickup
                            : onRefresh,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryOrange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: Icon(
                  pickedUp
                      ? canConfirmDropoff
                          ? Icons.flag_outlined
                          : Icons.near_me_outlined
                      : canConfirmPickup
                          ? Icons.inventory_2_outlined
                          : Icons.near_me_outlined,
                ),
                label: Text(
                  isUpdatingStatus
                      ? 'Updating...'
                      : pickedUp
                          ? canConfirmDropoff
                              ? 'Confirm drop-off'
                              : 'Refresh drop-off route'
                          : canConfirmPickup
                              ? 'Confirm pickup'
                              : 'Refresh pickup route',
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

const _pickupConfirmRadiusKm = 0.5;
const _dropoffConfirmRadiusKm = 0.5;

bool _isPickedUp(Map<String, dynamic> job) {
  final status = _text(job['status']).toLowerCase();
  return status == 'in_progress' ||
      status == 'started' ||
      status == 'pickup' ||
      status == 'loaded' ||
      status == 'completed';
}

double _distanceKm(LatLng from, LatLng to) {
  const distance = Distance();
  return distance.as(LengthUnit.Kilometer, from, to);
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

List<LatLng> _routePointsFromJob(Map<String, dynamic> job) {
  final points = job['route_points'];
  if (points is! List) return [];
  final routePoints = points.whereType<Map>().map((point) {
    return LatLng(
      _asDouble(point['latitude']),
      _asDouble(point['longitude']),
    );
  }).where((point) {
    return point.latitude != 0 && point.longitude != 0;
  }).toList();
  return routePoints.length > 2 ? routePoints : [];
}
