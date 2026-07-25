import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:loadr/constants.dart';
import 'package:loadr/models/place_suggestion.dart';
import 'package:loadr/services/api_service.dart';
import 'package:loadr/services/supabase_realtime_service.dart';
import 'package:loadr/widgets/skeleton.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  bool _isCanceling = false;
  bool _isRefreshingRoute = false;
  bool _isRefreshingLiveDriverRoute = false;
  DateTime? _lastRouteRefreshAt;
  DateTime? _lastLiveDriverRouteRefreshAt;
  StreamSubscription<Map<String, dynamic>?>? _bookingSubscription;
  RealtimeChannel? _driverLocationChannel;
  String? _driverLocationUid;

  @override
  void initState() {
    super.initState();
    _loadBooking();
  }

  Future<void> _loadBooking() async {
    setState(() {
      _isLoading = true;
      _booking = null;
    });
    final cachedBooking = await _readLocalBooking();
    if (!mounted) return;

    if (cachedBooking != null) {
      setState(() {
        _booking = cachedBooking;
        _isLoading = false;
      });
      _syncDriverLocationChannel(cachedBooking);
      _refreshBadRoute(cachedBooking);
    }

    unawaited(_syncBookingFromBackend(cachedBooking));
  }

  Future<void> _syncBookingFromBackend(
    Map<String, dynamic>? cachedBooking,
  ) async {
    var booking = cachedBooking;
    String? uid;
    try {
      uid = await ApiService.getUid();
      if (uid != null) {
        final backendBooking = await ApiService.getCustomerActiveJob(
          uid,
          jobId: _jobIdFromBooking(booking),
        );
        if (backendBooking != null) {
          booking = booking == null
              ? backendBooking
              : _mergeJobIntoBooking(booking, backendBooking);
        } else {
          booking = null;
        }
      }
    } catch (_) {
      // Cached booking remains usable while the backend is unavailable.
    }
    if (!mounted) return;
    setState(() {
      _booking = booking;
      _isLoading = false;
    });
    _refreshBadRoute(booking);
    _syncDriverLocationChannel(booking);
    if (uid != null) _startBookingStream(uid, _jobIdFromBooking(booking));
  }

  Future<Map<String, dynamic>?> _readLocalBooking() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('active_booking');
    if (json == null || json.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(json);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      await prefs.remove('active_booking');
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
      if (!_isAccepted(merged)) {
        final pickup = _placeFromBooking(merged, 'pickup');
        if (pickup != null) {
          merged['nearby_drivers'] = await ApiService.getNearbyDrivers(
            latitude: pickup.latitude,
            longitude: pickup.longitude,
          );
        }
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_booking', jsonEncode(merged));

      if (!mounted) return;
      setState(() => _booking = merged);
      _syncDriverLocationChannel(merged);
      _refreshBadRoute(merged);
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

  void _startBookingStream(String uid, String? jobId) {
    _bookingSubscription?.cancel();
    _bookingSubscription = ApiService.streamCustomerActiveJob(
      uid,
      jobId: jobId,
    ).listen(
      (job) {
        if (!mounted) return;
        if (job == null) {
          final current = _booking;
          setState(() {
            _booking = current == null || !_isOnTrip(current)
                ? null
                : {...current, 'status': 'completed'};
          });
          _syncDriverLocationChannel(_booking);
          return;
        }

        final current = _booking;
        final next = current == null ? job : _mergeJobIntoBooking(current, job);
        setState(() => _booking = next);
        _syncDriverLocationChannel(next);
        _refreshBadRoute(next);
      },
      onError: (_) {
        // Cached/manual refresh keeps the screen usable if the stream drops.
      },
    );
  }

  void _syncDriverLocationChannel(Map<String, dynamic>? booking) {
    final driverUid = _driverUidFromBooking(booking);
    if (driverUid == _driverLocationUid) return;

    unawaited(SupabaseRealtimeService.removeChannel(_driverLocationChannel));
    _driverLocationChannel = null;
    _driverLocationUid = driverUid;
    if (driverUid == null) return;

    _driverLocationChannel = SupabaseRealtimeService.subscribeToDriverLocation(
      driverUid: driverUid,
      onLocation: _applyRealtimeDriverLocation,
    );
  }

  void _applyRealtimeDriverLocation(Map<String, dynamic> location) {
    if (!mounted) return;
    final booking = _booking;
    if (booking == null) return;

    final driver = booking['driver'];
    final driverMap =
        driver is Map ? Map<String, dynamic>.from(driver) : <String, dynamic>{};
    final next = {
      ...booking,
      'driver': {
        ...driverMap,
        'uid': _driverLocationUid,
        'current_location': location,
      },
    };
    setState(() => _booking = next);
    final point = _pointFromLocation(location);
    if (point != null) unawaited(_refreshLiveDriverRoute(next, point));
  }

  Future<void> _refreshLiveDriverRoute(
    Map<String, dynamic> booking,
    LatLng driverPoint,
  ) async {
    if (_isRefreshingLiveDriverRoute) return;
    final last = _lastLiveDriverRouteRefreshAt;
    if (last != null &&
        DateTime.now().difference(last) < const Duration(seconds: 5)) {
      return;
    }

    final pickedUp = _isOnTrip(booking);
    final target = _placeFromBooking(booking, pickedUp ? 'dropoff' : 'pickup');
    if (target == null) return;

    _isRefreshingLiveDriverRoute = true;
    _lastLiveDriverRouteRefreshAt = DateTime.now();
    try {
      final estimate = await ApiService.estimateRide(
        pickup: PlaceSuggestion(
          displayName: 'Driver current location',
          latitude: driverPoint.latitude,
          longitude: driverPoint.longitude,
        ),
        drop: target,
        vehicleType: _text(booking['vehicle_type']).isEmpty
            ? 'Tata Ace'
            : _text(booking['vehicle_type']),
        schedule: 'Now',
        useCache: false,
      );
      if (!mounted || estimate.routePoints.length < 2) return;

      final current = _booking;
      if (current == null) return;
      final routePoints = estimate.routePoints
          .map(
            (point) => {
              'latitude': point.latitude,
              'longitude': point.longitude,
            },
          )
          .toList();
      final next = {...current};
      if (pickedUp) {
        next['distance_km'] = estimate.distanceKm;
        next['route_points'] = routePoints;
      } else {
        next['driver_route_points'] = routePoints;
      }
      setState(() => _booking = next);
    } catch (_) {
      // Keep the last good live route until the next driver location tick.
    } finally {
      _isRefreshingLiveDriverRoute = false;
    }
  }

  Map<String, dynamic> _mergeJobIntoBooking(
    Map<String, dynamic> booking,
    Map<String, dynamic> job,
  ) {
    final driver = job['driver'];
    final routePoints =
        _betterRoutePoints(booking['route_points'], job['route_points']);
    return {
      ...booking,
      'status': job['status'] ?? booking['status'],
      'assigned_driver_uid':
          job['assigned_driver_uid'] ?? booking['assigned_driver_uid'],
      'assigned_trip_id':
          job['assigned_trip_id'] ?? booking['assigned_trip_id'],
      'assigned_at': job['assigned_at'] ?? booking['assigned_at'],
      'pickup_location': job['pickup_location'] ?? booking['pickup_location'],
      'dropoff_location':
          job['dropoff_location'] ?? booking['dropoff_location'],
      'pickup_coords': job['pickup_coords'] ?? booking['pickup_coords'],
      'dropoff_coords': job['dropoff_coords'] ?? booking['dropoff_coords'],
      'vehicle_type': job['vehicle_type'] ?? booking['vehicle_type'],
      'amount': job['amount'] ?? booking['amount'],
      'distance_km': job['distance_km'] ?? booking['distance_km'],
      if (routePoints != null) 'route_points': routePoints,
      'nearby_drivers': job['nearby_drivers'] ?? booking['nearby_drivers'],
      if (driver is Map) 'driver': Map<String, dynamic>.from(driver),
    };
  }

  Future<void> _refreshBadRoute(Map<String, dynamic>? booking) async {
    if (_isRefreshingRoute) return;
    if (booking == null) return;
    final pickup = _placeFromBooking(booking, 'pickup');
    final drop = _placeFromBooking(booking, 'dropoff');
    if (pickup == null || drop == null) return;

    final currentPoints = _routePointsFromBooking(booking);
    if (currentPoints.length > 2) return;

    final lastTry = _lastRouteRefreshAt;
    if (lastTry != null &&
        DateTime.now().difference(lastTry) < const Duration(seconds: 30)) {
      return;
    }
    _lastRouteRefreshAt = DateTime.now();
    _isRefreshingRoute = true;

    try {
      final estimate = await ApiService.estimateRide(
        pickup: pickup,
        drop: drop,
        vehicleType: _text(booking['vehicle_type']).isEmpty
            ? 'Tata Ace'
            : _text(booking['vehicle_type']),
        schedule: 'Now',
      );
      if (estimate.routePoints.length <= 2 || !mounted) return;

      final next = {
        ...booking,
        'distance_km': estimate.distanceKm,
        'route_points': estimate.routePoints
            .map(
              (point) => {
                'latitude': point.latitude,
                'longitude': point.longitude,
              },
            )
            .toList(),
      };
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_booking', jsonEncode(next));
      if (mounted) setState(() => _booking = next);
    } catch (_) {
      // Keep markers visible without drawing a fake straight road route.
    } finally {
      _isRefreshingRoute = false;
    }
  }

  Object? _betterRoutePoints(Object? current, Object? incoming) {
    if (_routePointCount(current) > 2 && _routePointCount(incoming) <= 2) {
      return current;
    }
    return incoming ?? current;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MapScreenSkeleton();
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
              routePoints: _routePointsFromBooking(booking),
              driverRoutePoints: _driverRoutePointsFromBooking(booking),
              driverPoint: _driverPointFromBooking(booking),
              nearbyDrivers: _nearbyDriverPoints(booking),
              pickedUp: _isOnTrip(booking),
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
          DraggableScrollableSheet(
            initialChildSize: 0.42,
            minChildSize: 0.18,
            maxChildSize: 0.72,
            snap: true,
            snapSizes: const [0.18, 0.42, 0.72],
            builder: (context, scrollController) => _BookingPanel(
              scrollController: scrollController,
              booking: booking,
              refreshing: _isRefreshing,
              canceling: _isCanceling,
              onCancel: _cancelPickup,
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

  Future<void> _cancelPickup() async {
    final jobId = '${_booking?['job_id'] ?? _booking?['id'] ?? ''}'.trim();
    if (jobId.isEmpty || _isCanceling) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel pickup?'),
        content:
            const Text('This will remove the booking for you and the driver.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep booking'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel pickup'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _isCanceling = true);
    try {
      await ApiService.cancelJob(jobId);
      if (!mounted) return;
      setState(() => _booking = null);
      _syncDriverLocationChannel(null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pickup cancelled')),
      );
      Navigator.pushReplacementNamed(context, '/customer-home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cancel failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isCanceling = false);
      }
    }
  }

  @override
  void dispose() {
    _bookingSubscription?.cancel();
    unawaited(SupabaseRealtimeService.removeChannel(_driverLocationChannel));
    super.dispose();
  }
}

class _RouteMap extends StatefulWidget {
  final MapController controller;
  final PlaceSuggestion pickup;
  final PlaceSuggestion drop;
  final List<LatLng> routePoints;
  final List<LatLng> driverRoutePoints;
  final LatLng? driverPoint;
  final List<LatLng> nearbyDrivers;
  final bool pickedUp;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const _RouteMap({
    required this.controller,
    required this.pickup,
    required this.drop,
    required this.routePoints,
    required this.driverRoutePoints,
    required this.driverPoint,
    required this.nearbyDrivers,
    required this.pickedUp,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  @override
  State<_RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<_RouteMap> {
  double _zoom = 13;

  @override
  Widget build(BuildContext context) {
    final routePoints = widget.pickedUp && widget.driverPoint != null
        ? _trimRouteFrom(widget.driverPoint!, widget.routePoints)
        : widget.routePoints;
    final driverRoutePoints =
        widget.pickedUp ? const <LatLng>[] : widget.driverRoutePoints;
    final pickupPoint = widget.routePoints.isEmpty
        ? LatLng(widget.pickup.latitude, widget.pickup.longitude)
        : widget.routePoints.first;
    final dropPoint = routePoints.isEmpty
        ? LatLng(widget.drop.latitude, widget.drop.longitude)
        : routePoints.last;
    final mapStart = widget.driverPoint ?? pickupPoint;
    final cameraPoints = [
      mapStart,
      ...driverRoutePoints,
      ...routePoints,
      dropPoint,
    ];
    final markerSize = routeMarkerSizeForZoom(_zoom);
    final driverSize = nearbyDriverMarkerSizeForZoom(_zoom);
    final nearbyDrivers = _zoom < 11
        ? const <LatLng>[]
        : widget.nearbyDrivers
            .take(_zoom < 13 ? 3 : widget.nearbyDrivers.length);
    return Stack(
      children: [
        FlutterMap(
          mapController: widget.controller,
          options: MapOptions(
            initialCameraFit: CameraFit.coordinates(
              coordinates: cameraPoints,
              padding: EdgeInsets.fromLTRB(
                44,
                150,
                44,
                MediaQuery.sizeOf(context).height * 0.53,
              ),
              maxZoom: 15,
            ),
            minZoom: 4,
            maxZoom: 20,
            onPositionChanged: (camera, _) {
              if ((camera.zoom - _zoom).abs() < 0.1) return;
              setState(() => _zoom = camera.zoom);
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
                if (driverRoutePoints.length >= 2)
                  Polyline(
                    points: driverRoutePoints,
                    color: const Color(0xFF333333),
                    strokeWidth: _zoom < 11 ? 3 : 5,
                    borderColor: Colors.white,
                    borderStrokeWidth: _zoom < 11 ? 1 : 2,
                  )
                else if (widget.driverPoint != null && !widget.pickedUp)
                  Polyline(
                    points: [widget.driverPoint!, pickupPoint],
                    color: const Color(0xFF333333),
                    strokeWidth: _zoom < 11 ? 3 : 5,
                    borderColor: Colors.white,
                    borderStrokeWidth: _zoom < 11 ? 1 : 2,
                  ),
                if (routePoints.length >= 2)
                  Polyline(
                    points: routePoints,
                    color: kPrimaryOrange,
                    strokeWidth: _zoom < 11 ? 4 : 6,
                    borderColor: Colors.white,
                    borderStrokeWidth: _zoom < 11 ? 2 : 3,
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
                for (final point in nearbyDrivers)
                  Marker(
                    point: point,
                    width: driverSize,
                    height: driverSize,
                    child: _DriverMapMarker(
                      nearby: true,
                      iconSize: driverSize * 0.48,
                    ),
                  ),
                if (widget.driverPoint != null)
                  Marker(
                    point: widget.driverPoint!,
                    width: markerSize,
                    height: markerSize,
                    child: _DriverMapMarker(iconSize: markerSize * 0.5),
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
        Positioned(
          right: 16,
          top: MediaQuery.paddingOf(context).top + 88,
          child: _MapZoomControls(
            onZoomIn: widget.onZoomIn,
            onZoomOut: widget.onZoomOut,
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
  final ScrollController scrollController;
  final Map<String, dynamic> booking;
  final bool refreshing;
  final bool canceling;
  final VoidCallback onCancel;

  const _BookingPanel({
    required this.scrollController,
    required this.booking,
    required this.refreshing,
    required this.canceling,
    required this.onCancel,
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
    final rawStatus = _text(booking['status']).toLowerCase();
    final canCancel = !{
      'completed',
      'cancelled',
      'in_progress',
      'started',
      'pickup',
      'loaded',
    }.contains(rawStatus);

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
                locationText: _driverLocationText(booking),
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
            if (canCancel) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: canceling ? null : onCancel,
                  icon: canceling
                      ? const SkeletonBox(width: 16, height: 16, radius: 4)
                      : const Icon(Icons.cancel_outlined),
                  label: Text(canceling ? 'Cancelling...' : 'Cancel pickup'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB3261E),
                    side: const BorderSide(color: Color(0xFFFFC4C4)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  final String name;
  final String vehicleNumber;
  final String locationText;

  const _DriverCard({
    required this.name,
    required this.vehicleNumber,
    required this.locationText,
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
                const SizedBox(height: 3),
                Text(
                  locationText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black45,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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
          SkeletonBox(width: 28, height: 28, radius: 8),
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
  final double iconSize;

  const _RouteMarker({
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    this.iconSize = 22,
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

class _DriverMapMarker extends StatelessWidget {
  final bool nearby;
  final double iconSize;

  const _DriverMapMarker({
    this.nearby = false,
    this.iconSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: nearby ? Colors.white : kPrimaryOrange,
        shape: BoxShape.circle,
        border: Border.all(color: kPrimaryOrange, width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0x26000000), blurRadius: 10),
        ],
      ),
      child: Icon(
        Icons.local_shipping,
        color: nearby ? kPrimaryOrange : Colors.white,
        size: nearby ? iconSize * 0.9 : iconSize,
      ),
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
  final rawStatus = _text(booking['status']).toLowerCase();
  if (rawStatus == 'completed') {
    return const _BookingStatus(
      title: 'Trip completed',
      subtitle: 'Your load has reached the drop-off location.',
      pill: 'Done',
    );
  }

  if (rawStatus == 'arriving') {
    return const _BookingStatus(
      title: 'Driver is reaching pickup',
      subtitle: 'Your driver is near the pickup location.',
      pill: 'Arriving',
    );
  }

  if (rawStatus == 'in_progress' ||
      rawStatus == 'started' ||
      rawStatus == 'pickup' ||
      rawStatus == 'loaded') {
    return const _BookingStatus(
      title: 'Pickup confirmed',
      subtitle: 'Your load is now on the way to drop-off.',
      pill: 'On trip',
    );
  }

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
      status == 'arriving' ||
      status == 'in_progress' ||
      status == 'completed' ||
      _text(booking['assigned_driver_uid']).isNotEmpty;
}

bool _isOnTrip(Map<String, dynamic> booking) {
  final status = _text(booking['status']).toLowerCase();
  return status == 'in_progress' ||
      status == 'started' ||
      status == 'pickup' ||
      status == 'loaded';
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

List<LatLng> _routePointsFromBooking(Map<String, dynamic> booking) {
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
    if (routePoints.length > 2) return routePoints;
  }

  return [];
}

List<LatLng> _driverRoutePointsFromBooking(Map<String, dynamic> booking) {
  final points = booking['driver_route_points'];
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

int _routePointCount(Object? value) {
  if (value is! List) return 0;
  return value.whereType<Map>().where((point) {
    final latitude = _asDouble(point['latitude']);
    final longitude = _asDouble(point['longitude']);
    return latitude != 0 && longitude != 0;
  }).length;
}

LatLng? _driverPointFromBooking(Map<String, dynamic> booking) {
  final driver = booking['driver'];
  final location = driver is Map ? driver['current_location'] : null;
  if (location is! Map) return null;
  final latitude = _asDouble(location['latitude']);
  final longitude = _asDouble(location['longitude']);
  if (latitude == 0 || longitude == 0) return null;
  return LatLng(latitude, longitude);
}

LatLng? _pointFromLocation(Map<String, dynamic> location) {
  final latitude = _asDouble(location['latitude']);
  final longitude = _asDouble(location['longitude']);
  if (latitude == 0 || longitude == 0) return null;
  return LatLng(latitude, longitude);
}

List<LatLng> _nearbyDriverPoints(Map<String, dynamic> booking) {
  final drivers = booking['nearby_drivers'];
  if (drivers is! List) return [];
  return drivers.whereType<Map>().map((driver) {
    return LatLng(
      _asDouble(driver['latitude']),
      _asDouble(driver['longitude']),
    );
  }).where((point) {
    return point.latitude != 0 && point.longitude != 0;
  }).toList();
}

String _driverLocationText(Map<String, dynamic> booking) {
  if (_text(booking['status']).toLowerCase() == 'completed') {
    return 'Trip completed';
  }

  final driver = _driverPointFromBooking(booking);
  final pickup = _placeFromBooking(booking, 'pickup');
  if (driver == null || pickup == null) return 'Live location unavailable';
  const distance = Distance();
  final km = distance.as(
    LengthUnit.Kilometer,
    driver,
    LatLng(pickup.latitude, pickup.longitude),
  );
  if (km <= 0.5) return 'Driver is reaching pickup';
  return '${km.toStringAsFixed(1)} km from pickup - live on map';
}

List<LatLng> _trimRouteFrom(LatLng current, List<LatLng> route) {
  if (route.length < 2) return route;

  const distance = Distance();
  var nearestIndex = 0;
  var nearestDistance = double.infinity;
  for (var i = 0; i < route.length; i++) {
    final km = distance.as(LengthUnit.Kilometer, current, route[i]);
    if (km < nearestDistance) {
      nearestDistance = km;
      nearestIndex = i;
    }
  }

  if (nearestIndex >= route.length - 1) return [current, route.last];
  return [current, ...route.skip(nearestIndex + 1)];
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

String? _jobIdFromBooking(Map<String, dynamic>? booking) {
  final jobId = _text(booking?['job_id'], fallback: _text(booking?['id']));
  return jobId.isEmpty ? null : jobId;
}

String? _driverUidFromBooking(Map<String, dynamic>? booking) {
  final assignedUid = _text(booking?['assigned_driver_uid']);
  if (assignedUid.isNotEmpty) return assignedUid;

  final driver = booking?['driver'];
  if (driver is Map) {
    final uid = _text(driver['uid'], fallback: _text(driver['firebase_uid']));
    if (uid.isNotEmpty) return uid;
  }
  return null;
}
