import 'package:flutter/material.dart';
import '../constants.dart';

class LocationScreen extends StatelessWidget {
  const LocationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ensure you have this asset or use an Icon as a placeholder
            const Icon(Icons.location_on, size: 150, color: kPrimaryOrange),
            const SizedBox(height: 40),
            const Text(
                "Enable Your Location",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 10),
            const Text(
                "To search for the best nearby driver, we want to know your current location",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey)
            ),
            const SizedBox(height: 50),
            ElevatedButton(
              // UPDATED: Navigates to the first step of the onboarding sequence
              onPressed: () => Navigator.pushNamed(context, '/vehicles'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryOrange,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: const Text("Use current location"),
            ),
            TextButton(
              // UPDATED: Also navigates forward if they skip
              onPressed: () => Navigator.pushNamed(context, '/vehicles'),
              child: const Text("Skip for now", style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }
}