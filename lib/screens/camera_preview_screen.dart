import 'package:flutter/material.dart';
import '../constants.dart';
import '../widgets/onboarding_stepper.dart';

class CameraPreviewScreen extends StatelessWidget {
  const CameraPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const OnboardingStepper(currentStep: 2),
            ),
            Expanded(
              child: Stack(
                children: [
                  // Simulated Camera View
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: NetworkImage("https://via.placeholder.com/800x1200"), // Replace with actual camera preview
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  // Camera Overlays (Flash, Capture Grid)
                  Positioned(
                    right: 20,
                    top: 100,
                    child: Column(
                      children: const [
                        Icon(Icons.flashlight_on, color: Colors.white, size: 30),
                        SizedBox(height: 20),
                        Icon(Icons.camera_alt, color: Colors.white, size: 30),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              color: Colors.white,
              child: Column(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.camera_enhance_outlined),
                    label: const Text("RETAKE IMAGE"),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 55),
                      side: const BorderSide(color: Colors.orangeAccent),
                      foregroundColor: Colors.orangeAccent,
                    ),
                  ),
                  const SizedBox(height: 15),
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/success'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryOrange,
                      minimumSize: const Size(double.infinity, 55),
                    ),
                    child: const Text("Verify License", style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}