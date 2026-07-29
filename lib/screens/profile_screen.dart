import 'package:flutter/material.dart';
import 'package:loadr/constants.dart';
import 'package:loadr/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  final bool showBackButton;

  const ProfileScreen({
    super.key,
    this.showBackButton = true,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _role = '';
  String _name = 'Profile';
  String _subtitle = '';
  String _locationSubtitle = 'Saved on this device';
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('selected_role') ?? '';
    final name = role == 'driver'
        ? prefs.getString('driver_name')
        : prefs.getString('customer_name');
    final subtitle = role == 'driver'
        ? prefs.getString('driver_vehicle_number')
        : prefs.getString('customer_email');
    final locationRole = role == 'driver' ? 'driver' : 'customer';
    final locationLabel =
        _cleanText(prefs.getString('${locationRole}_location_label'));
    final latitude = prefs.getDouble('${locationRole}_latitude');
    final longitude = prefs.getDouble('${locationRole}_longitude');

    if (!mounted) return;
    setState(() {
      _role = role;
      _name = (name == null || name.trim().isEmpty) ? 'Profile' : name.trim();
      _subtitle = (subtitle == null || subtitle.trim().isEmpty)
          ? role
          : subtitle.trim();
      _locationSubtitle = locationLabel ??
          ((latitude != null && longitude != null)
              ? '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}'
              : 'Set your loading area');
    });

    if (locationLabel == null && latitude != null && longitude != null) {
      _setCityFromCoordinates(locationRole, latitude, longitude);
    }
  }

  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/signin',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: widget.showBackButton,
        leading: widget.showBackButton
            ? IconButton(
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.maybePop(context);
                  } else {
                    Navigator.pushReplacementNamed(context, '/dashboard');
                  }
                },
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
              )
            : null,
        title: const Text(
          'Profile',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEAEAEA)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: kPrimaryOrange.withValues(alpha: 0.12),
                    child: Icon(
                      _role == 'driver'
                          ? Icons.badge_outlined
                          : Icons.person_outline,
                      color: kPrimaryOrange,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _ProfileTile(
              icon: Icons.location_on_outlined,
              title: 'Location',
              subtitle: _locationSubtitle,
              onTap: () => Navigator.pushNamed(context, '/location'),
            ),
            const SizedBox(height: 10),
            _ProfileTile(
              icon: Icons.logout,
              title: _isLoggingOut ? 'Logging out...' : 'Logout',
              subtitle: 'Clear this session',
              destructive: true,
              onTap: _isLoggingOut ? null : _logout,
            ),
          ],
        ),
      ),
    );
  }

  String? _cleanText(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  Future<void> _setCityFromCoordinates(
    String role,
    double latitude,
    double longitude,
  ) async {
    try {
      final place = await ApiService.reverseGeocode(
        latitude: latitude,
        longitude: longitude,
      );
      final label = _cleanText(place.shortLabel);
      if (label == null || !mounted) return;
      await ApiService.cacheLocation(
        role: role,
        latitude: latitude,
        longitude: longitude,
        label: label,
      );
      if (mounted) setState(() => _locationSubtitle = label);
    } catch (_) {
      // Keep cached coordinates if reverse lookup is unavailable.
    }
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool destructive;
  final VoidCallback? onTap;

  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.destructive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Colors.redAccent : kPrimaryOrange;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEAEAEA)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: destructive ? Colors.redAccent : Colors.black87,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
}
