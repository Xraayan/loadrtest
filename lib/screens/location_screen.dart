import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../services/api_service.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  bool _isLoading = false;

  Future<Position> _determinePosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Please turn on location services and try again');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Location permission is required to save your position');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
          'Location permission is blocked. Enable it from app settings');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
      ),
    );
  }

  Future<void> _handleUseLocation() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('uid');
      final role = prefs.getString('selected_role') ?? 'driver';

      if (uid == null) {
        throw Exception('User not authenticated');
      }

      final position = await _determinePosition();
      final label = await _labelForLocation(position);
      final location = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'is_active': true,
      };

      if (role == 'user') {
        await ApiService.cacheLocation(
          role: 'customer',
          latitude: position.latitude,
          longitude: position.longitude,
          label: label,
        );
      } else {
        await ApiService.updateLocation(uid, location);
        await ApiService.cacheLocation(
          role: 'driver',
          latitude: position.latitude,
          longitude: position.longitude,
          isActive: true,
          label: label,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location saved')),
        );
        Navigator.pushReplacementNamed(
          context,
          _nextRoute(role, prefs),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleSkip() {
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      final role = prefs.getString('selected_role') ?? 'driver';
      Navigator.pushReplacementNamed(
        context,
        _nextRoute(role, prefs),
      );
    });
  }

  String _nextRoute(String role, SharedPreferences prefs) {
    if (role == 'user') {
      final hasProfile = (prefs.getString('customer_name') ?? '').isNotEmpty;
      return hasProfile ? '/customer-home' : '/customer-details';
    }

    final hasProfile = (prefs.getString('driver_name') ?? '').isNotEmpty &&
        (prefs.getString('driver_vehicle_number') ?? '').isNotEmpty;
    return hasProfile ? '/dashboard' : '/driver-details';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_on, size: 112, color: kPrimaryOrange),
            const SizedBox(height: 40),
            const Text("Enable Your Location",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text(
                "LoadR uses your saved location for nearby loads, pickups, and dashboard status.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 50),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleUseLocation,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryOrange,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : const Text("Use current location"),
            ),
            TextButton(
              onPressed: _isLoading ? null : _handleSkip,
              child: const Text("Skip for now",
                  style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _labelForLocation(Position position) async {
    try {
      final place = await ApiService.reverseGeocode(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      final city = place.city.trim().isNotEmpty
          ? place.city.trim()
          : place.district.trim();
      final state = place.state.trim();
      if (city.isEmpty) {
        return place.displayName.trim().isEmpty ? null : place.displayName;
      }
      if (state.isEmpty || city.toLowerCase() == state.toLowerCase()) return city;
      return '$city, $state';
    } catch (_) {
      return null;
    }
  }
}
