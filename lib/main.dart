import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:loadr/screens/dashboard_screen.dart';
import 'package:loadr/screens/ledger_screen.dart';
import 'package:loadr/screens/all_trip_screen.dart';
import 'package:loadr/screens/new_trip_screen.dart';
import 'constants.dart';
import 'screens/activation_success_screen.dart';
import 'screens/document_upload_screen.dart';
import 'screens/landing_screen.dart';
import 'screens/language_screen.dart';
import 'screens/preferences_state_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/location_screen.dart';
import 'screens/vehicle_selection_screen.dart';

void main() {
  runApp(const LoadRApp());
}

class LoadRApp extends StatelessWidget {
  const LoadRApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LoadR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: kPrimaryOrange,
        scaffoldBackgroundColor: Colors.white,
        textTheme: GoogleFonts.poppinsTextTheme(), // Matching the clean UI font
        useMaterial3: true,
      ),
      // Set the initial screen
      home: const LandingScreen(),

      // Define named routes for cleaner navigation
      routes: {
        '/language': (context) => const LanguageScreen(),
        '/signin': (context) => const SignInScreen(),
        '/otp': (context) => const OTPScreen(),
        '/location': (context) => const LocationScreen(),
        '/vehicles': (context) => const VehicleSelectionScreen(),
        '/preferences': (context) => const PreferencesStateScreen(),
        '/upload-license': (context) => const DocumentUploadScreen(),
        '/success': (context) => const ActivationSuccessScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/ledger': (context) => const LedgerScreen(),
        '/all-trips': (context) => const AllTripScreen(),
        '/new-trips': (context) => const NewTripScreen(),
      },
    );
  }
}
