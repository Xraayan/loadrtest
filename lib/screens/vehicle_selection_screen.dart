import 'package:flutter/material.dart';
import '../constants.dart';
import '../widgets/onboarding_stepper.dart';

class VehicleSelectionScreen extends StatefulWidget {
  const VehicleSelectionScreen({super.key});

  @override
  State<VehicleSelectionScreen> createState() => _VehicleSelectionScreenState();
}

class _VehicleSelectionScreenState extends State<VehicleSelectionScreen> {
  String? selectedVehicle;

  final List<Map<String, String>> vehicles = [
    {"name": "Construction Excavator", "color": "0xFF78909C"},
    {"name": "Backhoe Loader", "color": "0xFFFF7043"},
    {"name": "3 Wheelers", "color": "0xFF3F51B5"},
    {"name": "Pickups", "color": "0xFF546E7A"},
    {"name": "Tipper Trucks", "color": "0xFFFF7043"},
    {"name": "Tata 407", "color": "0xFF9FA8DA"},
  ];

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
              const Text("Step 1 of 3", style: TextStyle(color: Colors.grey)),
              const Text("Select Vehicle", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text("Pick your truck type for tailored driving opportunities."),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 1.4
                  ),
                  itemCount: vehicles.length,
                  itemBuilder: (context, index) => _buildVehicleCard(vehicles[index]),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/preferences'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryOrange,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text("Continue", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleCard(Map<String, String> vehicle) {
    bool isSelected = selectedVehicle == vehicle['name'];
    return GestureDetector(
      onTap: () => setState(() => selectedVehicle = vehicle['name']),
      child: Container(
        decoration: BoxDecoration(
          color: Color(int.parse(vehicle['color']!)),
          borderRadius: BorderRadius.circular(10),
          border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
        ),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            const Center(child: Icon(Icons.car_repair, size: 50, color: Colors.white24)),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(4),
              color: Colors.black26,
              child: Text(vehicle['name']!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12)),
            )
          ],
        ),
      ),
    );
  }
}