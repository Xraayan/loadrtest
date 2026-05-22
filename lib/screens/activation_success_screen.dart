import 'package:flutter/material.dart';
import '../constants.dart';
import '../widgets/onboarding_stepper.dart';

class ActivationSuccessScreen extends StatefulWidget {
  const ActivationSuccessScreen({super.key});

  @override
  State<ActivationSuccessScreen> createState() => _ActivationSuccessScreenState();
}

class _ActivationSuccessScreenState extends State<ActivationSuccessScreen> {
  bool isAccepted = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const OnboardingStepper(currentStep: 3),
            const Text("Step 3 of 3", style: TextStyle(color: Colors.grey)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text("Your are Ready to Drive",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),

            // Success Image/Banner
            Container(
              height: 200,
              width: double.infinity,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage("https://via.placeholder.com/600x300"), // Replace with image_58cda4 content
                  fit: BoxFit.cover,
                ),
              ),
            ),

            const Padding(
              padding: EdgeInsets.all(25),
              child: Text(
                "Your account is now activated. Let's book your load.",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
            ),

            const Spacer(),

            // Terms and Conditions Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Checkbox(
                    value: isAccepted,
                    onChanged: (val) => setState(() => isAccepted = val!),
                    activeColor: kPrimaryOrange,
                  ),
                  const Text("I Accept this "),
                  const Text("Terms and Conditions",
                      style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton(
                onPressed: isAccepted ? () {} : null, // Disable if not accepted
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAccepted ? kPrimaryOrange : kPrimaryOrange.withOpacity(0.5),
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text("Continue",
                    style: TextStyle(color: Colors.white, fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}