import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../widgets/onboarding_stepper.dart';
import '../services/api_service.dart';

class VehicleSelectionScreen extends StatefulWidget {
  const VehicleSelectionScreen({super.key});

  @override
  State<VehicleSelectionScreen> createState() => _VehicleSelectionScreenState();
}

class _VehicleSelectionScreenState extends State<VehicleSelectionScreen> {
  String? selectedVehicle;
  bool _isLoading = true;
  bool _isSaving = false;
  List<Map<String, dynamic>> vehicles = [];

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    try {
      final vehicleList = await ApiService.getVehicles();
      setState(() {
        // If no vehicles in backend, use default list
        if (vehicleList.isEmpty) {
          vehicles = [
            {"name": "Construction Excavator", "color": "0xFF78909C"},
            {"name": "Backhoe Loader", "color": "0xFFFF7043"},
            {"name": "3 Wheelers", "color": "0xFF3F51B5"},
            {"name": "Pickups", "color": "0xFF546E7A"},
            {"name": "Tipper Trucks", "color": "0xFFFF7043"},
            {"name": "Tata 407", "color": "0xFF9FA8DA"},
          ];
        } else {
          vehicles = vehicleList
              .map((v) => {
                    "name": v['type'] ?? v['name'] ?? 'Unknown',
                    "color": "0xFFFF7043",
                  })
              .toList()
              .cast<Map<String, dynamic>>();
        }
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        // Use default vehicles on error
        setState(() {
          vehicles = [
            {"name": "Construction Excavator", "color": "0xFF78909C"},
            {"name": "Backhoe Loader", "color": "0xFFFF7043"},
            {"name": "3 Wheelers", "color": "0xFF3F51B5"},
            {"name": "Pickups", "color": "0xFF546E7A"},
            {"name": "Tipper Trucks", "color": "0xFFFF7043"},
            {"name": "Tata 407", "color": "0xFF9FA8DA"},
          ];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleContinue() async {
    if (selectedVehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a vehicle')),
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

      // Assign vehicle to driver
      await ApiService.assignVehicle(uid, selectedVehicle!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle assigned successfully')),
        );
        Navigator.pushNamed(context, '/preferences');
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
              const OnboardingStepper(currentStep: 1),
              const Text("Step 1 of 3", style: TextStyle(color: Colors.grey)),
              const Text("Select Vehicle",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text(
                  "Pick your truck type for tailored driving opportunities."),
              const SizedBox(height: 20),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 15,
                                mainAxisSpacing: 15,
                                childAspectRatio: 1.4),
                        itemCount: vehicles.length,
                        itemBuilder: (context, index) =>
                            _buildVehicleCard(vehicles[index]),
                      ),
              ),
              ElevatedButton(
                onPressed: _isSaving ? null : _handleContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryOrange,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : const Text("Continue",
                        style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleCard(Map<String, dynamic> vehicle) {
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
            const Center(
                child: Icon(Icons.car_repair, size: 50, color: Colors.white24)),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(4),
              color: Colors.black26,
              child: Text(vehicle['name']!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            )
          ],
        ),
      ),
    );
  }
}
