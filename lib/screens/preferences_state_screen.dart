import 'package:flutter/material.dart';
import '../widgets/onboarding_stepper.dart';
import '../constants.dart';

class PreferencesStateScreen extends StatelessWidget {
  const PreferencesStateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const OnboardingStepper(currentStep: 1),
              const Text("Driver's Oasis", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              const Text("Preferences State", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              TextField(
                decoration: InputDecoration(
                  hintText: "Search your State...",
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  children: ["Kerala", "Karnataka", "Tamil Nadu", "Hyderabad"].map((s) => CheckboxListTile(
                      title: Text(s), value: false, onChanged: (v) {}
                  )).toList(),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/upload-license'),
                style: ElevatedButton.styleFrom(backgroundColor: kPrimaryOrange, minimumSize: const Size(double.infinity, 55)),
                child: const Text("Continue", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}