import 'package:flutter/material.dart';
import 'package:loadr/constants.dart';
import 'package:loadr/screens/customer_details_screen.dart';
import 'package:loadr/screens/customer_home_screen.dart';
import 'package:loadr/screens/dashboard_screen.dart';
import 'package:loadr/screens/driver_details_screen.dart';
import 'package:loadr/screens/landing_screen.dart';
import 'package:loadr/screens/location_screen.dart';
import 'package:loadr/screens/role_selection_screen.dart';
import 'package:loadr/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _resolveStartScreen(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.data != null) {
          return snapshot.data!;
        }

        return const Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: CircularProgressIndicator(color: kPrimaryOrange),
          ),
        );
      },
    );
  }

  Future<Widget> _resolveStartScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final uid = prefs.getString('uid');
    if (token == null || token.isEmpty || uid == null || uid.isEmpty) {
      return const LandingScreen();
    }

    try {
      await ApiService.getUserState(uid);
    } catch (_) {
      // Keep using the locally cached session if the backend is unavailable.
    }

    final role = prefs.getString('selected_role');
    if (role == null || role.isEmpty) {
      return const RoleSelectionScreen();
    }

    if (role == 'user') {
      final hasProfile = (prefs.getString('customer_name') ?? '').isNotEmpty;
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
