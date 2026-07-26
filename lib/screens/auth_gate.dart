import 'package:flutter/material.dart';
import 'package:loadr/screens/customer_details_screen.dart';
import 'package:loadr/screens/customer_home_screen.dart';
import 'package:loadr/screens/dashboard_screen.dart';
import 'package:loadr/screens/driver_details_screen.dart';
import 'package:loadr/screens/landing_screen.dart';
import 'package:loadr/screens/location_screen.dart';
import 'package:loadr/screens/role_selection_screen.dart';
import 'package:loadr/services/api_service.dart';
import 'package:loadr/widgets/skeleton.dart';
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

        return const _AppLoadingSkeleton();
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

class _AppLoadingSkeleton extends StatelessWidget {
  const _AppLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF7F7F7),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 78, height: 14, radius: 4),
                        SizedBox(height: 8),
                        SkeletonBox(width: 164, height: 31, radius: 8),
                      ],
                    ),
                  ),
                  SkeletonBox(width: 48, height: 48, radius: 24),
                ],
              ),
              SizedBox(height: 24),
              SkeletonBox(height: 190, radius: 18),
              SizedBox(height: 20),
              SkeletonBox(width: 110, height: 18, radius: 5),
              SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: SkeletonBox(height: 96, radius: 16)),
                  SizedBox(width: 12),
                  Expanded(child: SkeletonBox(height: 96, radius: 16)),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: SkeletonBox(height: 96, radius: 16)),
                  SizedBox(width: 12),
                  Expanded(child: SkeletonBox(height: 96, radius: 16)),
                ],
              ),
              Spacer(),
              SkeletonBox(height: 64, radius: 18),
            ],
          ),
        ),
      ),
    );
  }
}
