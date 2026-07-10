import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:loadr/constants.dart';
import 'package:loadr/services/api_service.dart';
import 'package:loadr/widgets/bottom_nav.dart';
import 'package:loadr/widgets/online_toggle.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  Timer? _statusTimer;
  StreamSubscription<Position>? _locationSubscription;
  bool _isOnline = true;
  String? _uid;
  String _driverName = 'Driver';
  String _vehicleNumber = 'KL 33 G 3532';
  String _locationText = 'Kottayam, Kerala';
  Map<String, dynamic>? _activeJob;
  int? _openLoadCount;

  @override
  void initState() {
    super.initState();
    _loadCachedDriverData();
    _statusTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _syncDriverDataFromBackend(),
    );
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _locationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadCachedDriverData() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('driver_name');
    final vehicleNumber = prefs.getString('driver_vehicle_number');
    final locationLabel = prefs.getString('driver_location_label');
    final latitude = prefs.getDouble('driver_latitude');
    final longitude = prefs.getDouble('driver_longitude');
    final activeJobJson = prefs.getString('driver_active_job');
    Map<String, dynamic>? activeJob;
    if (activeJobJson != null && activeJobJson.trim().isNotEmpty) {
      final decoded = jsonDecode(activeJobJson);
      if (decoded is Map) {
        activeJob = Map<String, dynamic>.from(decoded);
      }
    }

    if (!mounted) return;
    setState(() {
      _uid = prefs.getString('uid');
      _driverName = _cleanText(name) ?? 'Driver';
      _vehicleNumber = _cleanText(vehicleNumber) ?? 'KL 33 G 3532';
      _isOnline = prefs.getBool('driver_is_active') ?? true;
      _activeJob = activeJob;
      _locationText = _cleanText(locationLabel) ??
          ((latitude != null && longitude != null)
              ? '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}'
              : 'Kottayam, Kerala');
    });
    _syncLocationTracking();
    _syncDriverDataFromBackend();
  }

  Future<void> _setOnline(bool value) async {
    final previous = _isOnline;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('driver_is_active', value);
    if (!mounted) return;
    setState(() => _isOnline = value);
    _syncLocationTracking();
    final uid = _uid ?? prefs.getString('uid');
    if (uid == null) return;

    try {
      await ApiService.updateDriverStatus(uid, value);
    } catch (e) {
      await prefs.setBool('driver_is_active', previous);
      if (!mounted) return;
      setState(() => _isOnline = previous);
      _syncLocationTracking();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status update failed: $e')),
      );
    }
  }

  Future<void> _syncDriverDataFromBackend() async {
    final uid = _uid ?? await ApiService.getUid();
    if (uid == null) return;

    try {
      final location = await ApiService.getDriverLocation(uid);
      final active = location['is_active'];
      if (mounted && active is bool) {
        setState(() {
          _uid = uid;
          _isOnline = active;
        });
        _syncLocationTracking();
      }
    } catch (_) {
      // Keep cached status if realtime location is temporarily unavailable.
    }

    try {
      final activeJob = await ApiService.getDriverActiveJob(uid);
      if (!mounted) return;
      setState(() {
        _uid = uid;
        _activeJob = activeJob;
      });
    } catch (_) {
      // Keep cached active job if the backend is temporarily unavailable.
    }

    if (_activeJob == null) {
      try {
        final jobs = await ApiService.getJobs();
        if (!mounted) return;
        setState(() => _openLoadCount = jobs.length);
      } catch (_) {
        // Keep the last known count if jobs cannot be refreshed right now.
      }
    } else if (mounted) {
      setState(() => _openLoadCount = null);
    }
  }

  void _syncLocationTracking() {
    final uid = _uid;
    if (!_isOnline || uid == null) {
      _locationSubscription?.cancel();
      _locationSubscription = null;
      return;
    }
    if (_locationSubscription != null) return;

    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 100,
      ),
    ).listen((position) async {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          children: [
            _DashboardHeader(
              greeting: '${_greeting()}, $_driverName',
              onProfileTap: () async {
                await Navigator.pushNamed(context, '/profile');
                if (mounted) _loadCachedDriverData();
              },
            ),
            const SizedBox(height: 18),
            _AvailabilityCard(
              isOnline: _isOnline,
              vehicleNumber: _vehicleNumber,
              locationText: _locationText,
              onToggle: _setOnline,
            ),
            const SizedBox(height: 22),
            const Text(
              'Quick actions',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            _PrimaryActionCard(
              job: _activeJob,
              openLoadCount: _openLoadCount,
              onTap: () async {
                await Navigator.pushNamed(
                  context,
                  _activeJob == null ? '/new-trips' : '/driver-active-trip',
                  arguments: _activeJob,
                );
                if (mounted) _syncDriverDataFromBackend();
              },
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.55,
              children: const [
                _DriverActionCard(
                  title: 'All Trips',
                  subtitle: 'Manage accepted trips',
                  icon: Icons.route_outlined,
                  route: '/all-trips',
                ),
                _DriverActionCard(
                  title: 'Wallet',
                  subtitle: 'View payouts',
                  icon: Icons.account_balance_wallet_outlined,
                  route: '/wallet-deposit',
                ),
                _DriverActionCard(
                  title: 'Support',
                  subtitle: 'Get help quickly',
                  icon: Icons.support_agent,
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNav(selectedIndex: 0),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String? _cleanText(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }
}

class _DashboardHeader extends StatelessWidget {
  final String greeting;
  final VoidCallback onProfileTap;

  const _DashboardHeader({
    required this.greeting,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            greeting,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Material(
          color: kPrimaryOrange.withOpacity(0.11),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onProfileTap,
            customBorder: const CircleBorder(),
            child: const SizedBox(
              width: 48,
              height: 48,
              child: Icon(
                Icons.person_outline,
                color: kPrimaryOrange,
                size: 25,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AvailabilityCard extends StatelessWidget {
  final bool isOnline;
  final String vehicleNumber;
  final String locationText;
  final ValueChanged<bool> onToggle;

  const _AvailabilityCard({
    required this.isOnline,
    required this.vehicleNumber,
    required this.locationText,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDEDED)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 5,
              decoration: const BoxDecoration(
                color: kPrimaryOrange,
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(16),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _StatusDot(active: isOnline),
                                  const SizedBox(width: 8),
                                  Text(
                                    isOnline ? 'Online' : 'Offline',
                                    style: TextStyle(
                                      color: isOnline
                                          ? const Color(0xFF2E7D32)
                                          : Colors.black45,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Ready for loads',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        OnlineToggle(value: isOnline, onChanged: onToggle),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _StatusInfoRow(
                      icon: Icons.local_shipping_outlined,
                      label: 'Vehicle number',
                      value: vehicleNumber,
                    ),
                    const SizedBox(height: 10),
                    _StatusInfoRow(
                      icon: Icons.location_on_outlined,
                      label: 'Location',
                      value: locationText,
                    ),
                    const SizedBox(height: 10),
                    const _StatusInfoRow(
                      icon: Icons.radar_outlined,
                      label: 'Coverage',
                      value: 'Available within 25 km',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final bool active;

  const _StatusDot({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: active ? const Color(0xFF2E7D32) : Colors.black26,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _StatusInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatusInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0EA),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: kPrimaryOrange, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.black45,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 13,
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

class _PrimaryActionCard extends StatelessWidget {
  final Map<String, dynamic>? job;
  final int? openLoadCount;
  final VoidCallback onTap;

  const _PrimaryActionCard({
    required this.job,
    required this.openLoadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeJob = job;
    final hasJob = activeJob != null;
    final title = hasJob ? 'Accepted load' : 'New Trips';
    final subtitle = hasJob
        ? _routeSummary(activeJob)
        : _openLoadSubtitle(openLoadCount);
    final cta = hasJob ? 'View trip' : 'View loads';
    final amount = hasJob ? _amountText(activeJob) : null;

    return Material(
      color: kPrimaryOrange,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1FE64A19),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.local_shipping_outlined,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: amount == null
                        ? const SizedBox.shrink()
                        : Text(
                            amount,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      cta,
                      style: const TextStyle(
                        color: kPrimaryOrange,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
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

  String _openLoadSubtitle(int? count) {
    if (count == null) return 'Checking open loads';
    if (count == 0) return 'No open loads right now';
    if (count == 1) return '1 open load available';
    return '$count open loads available';
  }

  String _routeSummary(Map<String, dynamic> job) {
    final pickup = _shortLocation('${job['pickup_location'] ?? 'Pickup'}');
    final drop = _shortLocation('${job['dropoff_location'] ?? 'Drop'}');
    return '$pickup to $drop';
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

  String? _amountText(Map<String, dynamic> job) {
    final amount = num.tryParse('${job['amount'] ?? ''}');
    if (amount == null) return null;
    return 'Rs ${amount.toStringAsFixed(0)}';
  }
}

class _DriverActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? route;

  const _DriverActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.route,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: route == null ? null : () => Navigator.pushNamed(context, route!),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFEAEAEA)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0EA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: kPrimaryOrange, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 11,
                        height: 1.2,
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
}
