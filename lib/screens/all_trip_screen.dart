import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:loadr/screens/dashboard_screen.dart';
import 'package:loadr/screens/new_trip_screen.dart';

class AllTripScreen extends StatefulWidget {
  const AllTripScreen({super.key});

  @override
  State<AllTripScreen> createState() => _AllTripScreenState();
}

class _AllTripScreenState extends State<AllTripScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            onPressed: () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const DashboardScreen(),
                ),
                (route) => false),
            icon: const Icon(Icons.arrow_back)),
        backgroundColor: Colors.white,
        title: Text("All Trips"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "You have no ride history yet",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
                letterSpacing: 0.35,
                fontSize: 20,
              ),
            ),
            Text(
              "Go for your first ride",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w300,
                color: Colors.grey,
                fontSize: 18,
              ),
            ),
            SizedBox(
              height: 40,
            ),
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NewTripScreen(),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                elevation: 0,
                side: const BorderSide(
                  color: Colors.deepOrangeAccent,
                  width: 2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                "Ride Now!",
                style: GoogleFonts.poppins(
                  color: Colors.deepOrangeAccent,
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
