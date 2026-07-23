import 'package:flutter/material.dart';
import '../constants.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  String selectedLang = "English";

  final List<String> languages = [
    "English",
    "हिंदी (Hindi)",
    "മലയാളം (Malayalam)",
    "తెలుగు (Telugu)",
    "ಕನ್ನಡ (Kannada)",
    "বাংলা (Bengali)",
    "मराठी (Marathi)"
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLightBackground,
      body: SafeArea(
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
            decoration: BoxDecoration(
              color: kPrimaryOrange,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Hero(
                  tag: 'loadr_logo',
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.local_shipping,
                          color: Colors.white, size: 30),
                      const SizedBox(width: 8),
                      const Text("LOADR",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.none)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text("Select Language / भाषा चुने",
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                RadioGroup<String>(
                  groupValue: selectedLang,
                  onChanged: (value) => setState(() => selectedLang = value!),
                  child: Column(
                    children: languages
                        .map((lang) => RadioListTile<String>(
                              title: Text(lang,
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500)),
                              value: lang,
                              activeColor: Colors.black,
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/signin'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: kPrimaryOrange,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                  ),
                  child: const Text("Continue"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
