import 'package:flutter/material.dart';
import 'package:loadr/constants.dart';
import 'package:loadr/services/api_service.dart';
import 'package:loadr/widgets/onboarding_stepper.dart';
import 'package:loadr/widgets/skeleton.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesStateScreen extends StatefulWidget {
  const PreferencesStateScreen({super.key});

  @override
  State<PreferencesStateScreen> createState() => _PreferencesStateScreenState();
}

class _PreferencesStateScreenState extends State<PreferencesStateScreen> {
  bool _isSaving = false;

  final Map<String, bool> states = {
    "Kerala": false,
    "Karnataka": false,
    "Tamil Nadu": false,
    "Telangana": false,
  };

  Future<void> _handleContinue() async {
    final selectedStates = states.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (selectedStates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one state')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('uid');
      if (uid == null) {
        throw Exception('User not authenticated');
      }

      await ApiService.updatePreferences(uid, selectedStates);

      if (mounted) {
        Navigator.pushNamed(context, '/upload-license');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const OnboardingStepper(currentStep: 2),
              const Text("Step 2 of 3", style: TextStyle(color: Colors.grey)),
              const Text(
                "Set Preferences",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                  "Choose the states where you want load opportunities."),
              const SizedBox(height: 20),
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
                onPressed: _isSaving ? null : _handleContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryOrange,
                  minimumSize: const Size(double.infinity, 55),
                ),
                child: _isSaving
                    ? const SkeletonButtonLabel(width: 72)
                    : const Text(
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
