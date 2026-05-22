import 'package:flutter/material.dart';
import '../constants.dart';
import '../widgets/onboarding_stepper.dart';

class DocumentUploadScreen extends StatelessWidget {
  const DocumentUploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const OnboardingStepper(currentStep: 2),
              const Text("Step 2 of 3", style: TextStyle(color: Colors.grey)),
              const Text("Let’s Verify your driver license",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text("Upload a legible picture of your driver license to verify it",
                  style: TextStyle(color: Colors.black87)),
              const SizedBox(height: 40),

              // Dashed Upload Area
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/camera-preview'),
                child: Container(
                  width: double.infinity,
                  height: 250,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.5),
                      width: 2,
                      style: BorderStyle.solid, // Note: For true dashes, use 'dotted_border' package
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_done_outlined, size: 80, color: Colors.grey[700]),
                      const SizedBox(height: 10),
                      const Text("Choose a image or Capture image",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),

              const Spacer(),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/success'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryOrange,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("NEXT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}