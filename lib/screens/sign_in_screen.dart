import 'package:flutter/material.dart';
import '../constants.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 50),
            const Icon(Icons.local_shipping, color: kPrimaryOrange, size: 40),
            const Text("Welcome LoadR", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const Text("Please enter your sign in details.", style: TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 50),
            TextField(
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: "Phone Number",
                hintText: "Enter Phone Number",
                suffixIcon: const Icon(Icons.phone_outlined, color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const Spacer(),
            const Center(
              child: Text.rich(
                TextSpan(
                  text: "By clicking Next, you agree with our\n",
                  children: [
                    TextSpan(text: "Terms and Conditions", style: TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: " and "),
                    TextSpan(text: "Privacy Policy", style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/otp'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryOrange,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: const Text("Sign In", style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}