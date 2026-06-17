import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:loadr/services/api_service.dart';
import 'package:loadr/widgets/bottom_nav.dart';
import 'package:loadr/widgets/online_toggle.dart';
import 'package:loadr/widgets/scrollable_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  bool _isOnline = true;
  bool _isLoading = true;
  String? _uid;
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _ledger;
  String? _locationLabel;
  List<dynamic> _jobs = [];
  List<dynamic> _trips = [];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('uid');
      if (uid == null) {
        throw Exception('User not authenticated');
      }

      final results = await Future.wait([
        ApiService.getDriverProfile(uid),
        ApiService.getTrips(uid),
        ApiService.getJobs(),
        ApiService.getLedger(uid),
      ]);

      if (!mounted) return;
      final profile = results[0] as Map<String, dynamic>;
      final currentLocation = _locationFromProfile(profile);
      final locationLabel = await _labelForLocation(currentLocation);
      if (!mounted) return;
      setState(() {
        _uid = uid;
        _profile = profile;
        _trips = results[1] as List<dynamic>;
        _jobs = results[2] as List<dynamic>;
        _ledger = results[3] as Map<String, dynamic>;
        _locationLabel = locationLabel;
        if (currentLocation?['is_active'] is bool) {
          _isOnline = currentLocation!['is_active'] as bool;
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dashboard error: $e')),
      );
    }
  }

  Future<void> _setOnline(bool value) async {
    final uid = _uid;
    if (uid == null) return;

    final location = _currentLocation;
    final latitude = _numValue(location?['latitude']);
    final longitude = _numValue(location?['longitude']);
    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Save your current location first')),
      );
      return;
    }

    final previousValue = _isOnline;
    setState(() => _isOnline = value);
    try {
      await ApiService.updateLocation(uid, {
        'latitude': latitude,
        'longitude': longitude,
        'is_active': value,
      });
      if (!mounted) return;
      setState(() {
        _profile = {
          ...?_profile,
          'current_location': {
            ...?location,
            'latitude': latitude,
            'longitude': longitude,
            'is_active': value,
          },
        };
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isOnline = previousValue);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status update failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final headerHeight = size.height * 0.42;
    final summary = (_ledger?['summary'] as Map<String, dynamic>?) ?? {};
    final name = (_profile?['name'] as String?)?.trim();
    final vehicle = (_profile?['vehicle_number'] as String?)?.trim();
    final locationText = _locationText;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F5),
      body: Stack(
        children: [
          SizedBox(
            height: headerHeight,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  'https://images.unsplash.com/photo-1601584115197-04ecc0da31d7?w=900&q=80',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFF1A3A5C),
                  ),
                ),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x55000000), Color(0xDD000000)],
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              onPressed: _loadDashboard,
                              icon: const Icon(Icons.refresh),
                              color: Colors.white,
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 180,
                                  ),
                                  child: Text(
                                    locationText,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.location_on,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Spacer(),
                        const Text(
                          'WELCOME',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        Container(height: 2, width: 60, color: Colors.white),
                        const SizedBox(height: 10),
                        Text(
                          name?.isNotEmpty == true ? name! : 'Driver',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Driver ID: ${_shortId(_uid)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'Vehicle: ${vehicle?.isNotEmpty == true ? vehicle! : 'Not selected'}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _MetricPill(
                              label: 'Open Jobs',
                              value: _isLoading ? '-' : '${_jobs.length}',
                            ),
                            _MetricPill(
                              label: 'Trips',
                              value: _isLoading ? '-' : '${_trips.length}',
                            ),
                            _MetricPill(
                              label: 'Pending',
                              value: '₹${_numText(summary['pending_amount'])}',
                            ),
                            OnlineToggle(
                              value: _isOnline,
                              onChanged: _setOnline,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          ScrollableScreen(headerHeight: headerHeight, size: size),
        ],
      ),
      bottomNavigationBar: const BottomNav(selectedIndex: 0),
    );
  }

  String _shortId(String? value) {
    if (value == null || value.isEmpty) return 'N/A';
    return value.length <= 8 ? value : value.substring(0, 8).toUpperCase();
  }

  Map<String, dynamic>? get _currentLocation => _locationFromProfile(_profile);

  Map<String, dynamic>? _locationFromProfile(Map<String, dynamic>? profile) {
    final location = profile?['current_location'];
    if (location is Map<String, dynamic>) return location;
    if (location is Map) return Map<String, dynamic>.from(location);
    return null;
  }

  num? _numValue(dynamic value) {
    if (value is num) return value;
    return num.tryParse('${value ?? ''}');
  }

  Future<String?> _labelForLocation(Map<String, dynamic>? location) async {
    final latitude = _numValue(location?['latitude']);
    final longitude = _numValue(location?['longitude']);
    if (latitude == null || longitude == null) return null;

    try {
      final places = await placemarkFromCoordinates(
        latitude.toDouble(),
        longitude.toDouble(),
      );
      if (places.isEmpty) return null;

      final place = places.first;
      final city = _firstText([
        place.locality,
        place.subAdministrativeArea,
        place.administrativeArea,
      ]);
      final state = _cleanText(place.administrativeArea);

      if (city == null) return null;
      if (state == null || city.toLowerCase() == state.toLowerCase()) {
        return city;
      }
      return '$city, $state';
    } catch (_) {
      return null;
    }
  }

  String? _firstText(List<String?> values) {
    for (final value in values) {
      final text = _cleanText(value);
      if (text != null) return text;
    }
    return null;
  }

  String? _cleanText(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  String get _locationText {
    if (_locationLabel?.isNotEmpty == true) return _locationLabel!;

    final location = _currentLocation;
    final latitude = _numValue(location?['latitude']);
    final longitude = _numValue(location?['longitude']);
    if (latitude == null || longitude == null) return 'Location not set';
    return '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
  }

  String _numText(dynamic value) {
    final number = num.tryParse('${value ?? 0}') ?? 0;
    return number.toStringAsFixed(number.truncateToDouble() == number ? 0 : 2);
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final String value;

  const _MetricPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
