import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:loadr/constants.dart';
import 'package:loadr/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomerDetailsScreen extends StatefulWidget {
  const CustomerDetailsScreen({super.key});

  @override
  State<CustomerDetailsScreen> createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  double? _latitude;
  double? _longitude;
  bool _isGettingLocation = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCachedLocation();
  }

  Future<void> _loadCachedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _latitude = prefs.getDouble('customer_latitude');
      _longitude = prefs.getDouble('customer_longitude');
    });
  }

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
      throw Exception('Location permission is required to continue');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission is blocked. Enable it from app settings',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isGettingLocation = true);

    try {
      final position = await _determinePosition();
      await ApiService.cacheLocation(
        role: 'customer',
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location captured')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGettingLocation = false);
      }
    }
  }

  Future<void> _saveDetails() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final latitude = _latitude;
    final longitude = _longitude;
    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please allow location access')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final uid = await ApiService.getUid();
      if (uid == null) {
        throw Exception('User not authenticated');
      }

      await ApiService.updateUserProfile(
        uid,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        currentLocation: {
          'latitude': latitude,
          'longitude': longitude,
        },
      );

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/customer-home',
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationText = _latitude == null || _longitude == null
        ? 'Location not added'
        : '${_latitude!.toStringAsFixed(4)}, '
            '${_longitude!.toStringAsFixed(4)}';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 20),
              const Icon(
                Icons.person_pin_circle_outlined,
                color: kPrimaryOrange,
                size: 44,
              ),
              const SizedBox(height: 28),
              const Text(
                'Customer details',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add your contact details and location so drivers can quote accurately.',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 30),
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.name,
                decoration: _inputDecoration(
                  label: 'Full name',
                  icon: Icons.person_outline,
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'Please enter your name';
                  if (text.length < 2) return 'Name is too short';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                textInputAction: TextInputAction.done,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration(
                  label: 'Email address',
                  icon: Icons.email_outlined,
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'Please enter your email';
                  if (!text.contains('@') || !text.contains('.')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7F3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFD7C7)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.my_location, color: kPrimaryOrange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        locationText,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _isGettingLocation ? null : _useCurrentLocation,
                      child: _isGettingLocation
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Allow'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 34),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveDetails,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryOrange,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: kPrimaryOrange.withOpacity(0.6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : const Text(
                          'Save and Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kPrimaryOrange, width: 2),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}
