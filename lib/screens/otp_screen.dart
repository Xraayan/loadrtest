import 'package:flutter/material.dart';
import '../constants.dart';

class OTPScreen extends StatelessWidget {
  const OTPScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 50),
            const Text("Enter OTP", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const Text("Please enter the 4 digit OTP Code sent on +91826*********.", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(4, (index) => _otpBox(context)),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/location'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryOrange,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("NEXT"),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text.rich(TextSpan(children: [
                const TextSpan(text: "Didn't receive the code? "),
                TextSpan(text: "Resend (30s)", style: TextStyle(color: kPrimaryOrange, fontWeight: FontWeight.bold)),
              ])),
            )
          ],
        ),
      ),
    );
  }

  Widget _otpBox(BuildContext context) {
    return Container(
      width: 65,
      height: 65,
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
      child: const TextField(
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        decoration: InputDecoration(border: InputBorder.none),
      ),
    );
  }
}