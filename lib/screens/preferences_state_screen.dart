import 'package:flutter/material.dart';
import 'package:loadr/constants.dart';
import 'package:loadr/widgets/onboarding_stepper.dart';

class PreferencesStateScreen extends StatefulWidget {
  const PreferencesStateScreen({super.key});

  @override
  State<PreferencesStateScreen> createState() => _PreferencesStateScreenState();
}

class _PreferencesStateScreenState extends State<PreferencesStateScreen> {
  final Map<String, bool> states = {
    "Kerala": false,
    "Karnataka": false,
    "Tamil Nadu": false,
    "Hyderabad": false,
  };

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
              const Text(
                "Driver's Oasis",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                "Preferences State",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                decoration: InputDecoration(
                  hintText: "Search your State...",
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  children: states.entries.map((entry) {
                    return CheckboxListTile(
                      title: Text(entry.key),
                      value: entry.value,
                      onChanged: (value) {
                        setState(() {
                          states[entry.key] = value ?? false;
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              ElevatedButton(
                onPressed: () =>
                    Navigator.pushNamed(context, '/upload-license'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryOrange,
                  minimumSize: const Size(double.infinity, 55),
                ),
                child: const Text(
                  "Continue",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
