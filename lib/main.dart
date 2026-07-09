import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:loadr/screens/active_booking_screen.dart';
import 'package:loadr/screens/auth_gate.dart';
import 'package:loadr/screens/dashboard_screen.dart';
import 'package:loadr/screens/driver_details_screen.dart';
import 'package:loadr/screens/all_trip_screen.dart';
import 'package:loadr/screens/customer_details_screen.dart';
import 'package:loadr/screens/customer_home_screen.dart';
import 'package:loadr/screens/driver_active_trip_screen.dart';
import 'package:loadr/screens/new_trip_screen.dart';
import 'package:loadr/screens/driver_load_request_screen.dart';
import 'package:loadr/screens/profile_screen.dart';
import 'package:loadr/screens/request_quote_screen.dart';
import 'package:loadr/screens/request_vehicle_screen.dart';
import 'package:loadr/screens/wallet_deposit_screen.dart';
import 'constants.dart';
import 'screens/activation_success_screen.dart';
import 'screens/document_upload_screen.dart';
import 'screens/language_screen.dart';
import 'screens/preferences_state_screen.dart';
import 'screens/role_selection_screen.dart';
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

      home: const AuthGate(),

      // home: const LocationScreen(), // For Testing purposes

      // Define named routes for cleaner navigation
      routes: {
        '/language': (context) => const LanguageScreen(),
        '/signin': (context) => const SignInScreen(),
        '/otp': (context) => const OTPScreen(),
        '/role-selection': (context) => const RoleSelectionScreen(),
        '/customer-details': (context) => const CustomerDetailsScreen(),
        '/customer-home': (context) => const CustomerHomeScreen(),
        '/active-booking': (context) => const ActiveBookingScreen(),
        '/request-vehicle': (context) => const RequestVehicleScreen(),
        '/request-quote': (context) => const RequestQuoteScreen(),
        '/location': (context) => const LocationScreen(),
        '/vehicles': (context) => const VehicleSelectionScreen(),
        '/preferences': (context) => const PreferencesStateScreen(),
        '/upload-license': (context) => const DocumentUploadScreen(),
        '/success': (context) => const ActivationSuccessScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/driver-active-trip': (context) => const DriverActiveTripScreen(),
        '/driver-load-request': (context) => const DriverLoadRequestScreen(),
        '/all-trips': (context) => const AllTripScreen(),
        '/new-trips': (context) => const NewTripScreen(),
        '/driver-details': (context) => const DriverDetailsScreen(),
        '/wallet-deposit': (context) => const WalletDepositScreen(),
        '/profile': (context) => const ProfileScreen(),
      },
    );
  }
}
