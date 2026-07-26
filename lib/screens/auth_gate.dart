import 'package:flutter/material.dart';
import 'package:loadr/screens/customer_details_screen.dart';
import 'package:loadr/screens/customer_home_screen.dart';
import 'package:loadr/screens/dashboard_screen.dart';
import 'package:loadr/screens/driver_details_screen.dart';
import 'package:loadr/screens/landing_screen.dart';
import 'package:loadr/screens/location_screen.dart';
import 'package:loadr/screens/role_selection_screen.dart';
import 'package:loadr/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Future<Widget> _startScreen;

  @override
  void initState() {
    super.initState();
    _startScreen = _resolveStartScreen();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _startScreen,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.data != null) {
          return snapshot.data!;
        }

        return const _BrandLoadingScreen();
      },
    );
  }

  Future<Widget> _resolveStartScreen() async {
    final prefs = await SharedPreferences.getInstance();
    String? token;
    try {
      token = await ApiService.getAuthToken();
    } catch (_) {
      return const LandingScreen();
    }
    final uid = prefs.getString('uid');
    if (token == null || token.isEmpty || uid == null || uid.isEmpty) {
      return const LandingScreen();
    }

    try {
      await ApiService.getUserState(uid);
    } on ApiUnauthorizedException {
      try {
        await ApiService.logout();
      } catch (_) {}
      return const LandingScreen();
    } catch (_) {
      // Keep using the locally cached session if the backend is unavailable.
    }

    final role = prefs.getString('selected_role');
    if (role == null || role.isEmpty) {
      return const RoleSelectionScreen();
    }

    if (role == 'user') {
      final hasProfile =
          (prefs.getString('customer_name') ?? '').isNotEmpty &&
              !(prefs.getBool('customer_profile_sync_pending') ?? false);
      if (hasProfile) return const CustomerHomeScreen();
      return const CustomerDetailsScreen();
    }

    final hasDriverProfile = (prefs.getString('driver_name') ?? '').isNotEmpty &&
        (prefs.getString('driver_vehicle_number') ?? '').isNotEmpty;
    if (hasDriverProfile) return const DashboardScreen();

    final hasDriverLocation = prefs.getDouble('driver_latitude') != null &&
        prefs.getDouble('driver_longitude') != null;
    return hasDriverLocation ? const DriverDetailsScreen() : const LocationScreen();
  }
}

class _BrandLoadingScreen extends StatelessWidget {
  const _BrandLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image(
              image: AssetImage('assets/loadr_logo.png'),
              width: 92,
              height: 92,
            ),
            SizedBox(height: 18),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ],
        ),
      ),
    );
  }
}
