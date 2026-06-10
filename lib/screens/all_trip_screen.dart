import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
        backgroundColor: Colors.black,
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
              onPressed: () => print("All Trips Screen"),
              child: Text(
                "Ride Now!",
                style: GoogleFonts.poppins(
                    color: Colors.deepOrangeAccent, fontSize: 20),
              ),
            )
          ],
        ),
      ),
    );
  }
}
