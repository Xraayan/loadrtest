import 'package:flutter/material.dart';
import '../constants.dart';

class OnboardingStepper extends StatelessWidget {
  final int currentStep;
  const OnboardingStepper({super.key, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildStep(1, currentStep >= 1),
          _buildLine(currentStep > 1),
          _buildStep(2, currentStep >= 2),
          _buildLine(currentStep > 2),
          _buildStep(3, currentStep >= 3),
        ],
      ),
    );
  }

  Widget _buildStep(int step, bool isActive) {
    return Container(
      width: 35,
      height: 35,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? kPrimaryOrange : Colors.white,
        border: Border.all(color: kPrimaryOrange, width: 2),
      ),
      child: Center(
        child: isActive && step < currentStep
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : Text("$step", style: TextStyle(color: isActive ? Colors.white : kPrimaryOrange, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildLine(bool isActive) {
    return Container(width: 80, height: 2, color: kPrimaryOrange);
  }
}