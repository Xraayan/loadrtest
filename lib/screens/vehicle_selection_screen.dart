import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../widgets/onboarding_stepper.dart';
import '../services/api_service.dart';
import '../widgets/skeleton.dart';

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
  static const _fallbackVehicles = [
    {"name": "3 Wheeler Ape"},
    {"name": "Tata Ace"},
    {"name": "Dost Pickup"},
    {"name": "Tata 407 Water Tanker"},
  ];

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    try {
      final vehicleList = await ApiService.getVehicles();
      if (!mounted) return;
      setState(() {
        if (vehicleList.isEmpty) {
          vehicles = List<Map<String, dynamic>>.from(_fallbackVehicles);
        } else {
          vehicles = vehicleList
              .whereType<Map>()
              .map((v) => {
                    "name": v['type'] ?? v['name'] ?? 'Unknown',
                  })
              .toList();
        }
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          vehicles = List<Map<String, dynamic>>.from(_fallbackVehicles);
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
                    ? const GridSkeleton()
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
                    ? const SkeletonButtonLabel(width: 72)
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
    final name = '${vehicle['name'] ?? 'Vehicle'}';
    final presentation = _vehiclePresentationFor(name);
    final isSelected = selectedVehicle == name;

    return GestureDetector(
      onTap: () => setState(() => selectedVehicle = name),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFFBF8) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? kPrimaryOrange : const Color(0xFFEAEAEA),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0C000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: Image.asset(
                presentation.assetPath,
                cacheWidth: 320,
                filterQuality: FilterQuality.medium,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.local_shipping_outlined,
                  size: 48,
                  color: Colors.black38,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF303030),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              presentation.capacity,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehiclePresentation {
  final String assetPath;
  final String capacity;

  const _VehiclePresentation({
    required this.assetPath,
    required this.capacity,
  });
}

_VehiclePresentation _vehiclePresentationFor(String vehicleType) {
  final normalized = vehicleType.toLowerCase();
  if (normalized.contains('3 wheeler') || normalized.contains('ape')) {
    return const _VehiclePresentation(
      assetPath: 'assets/vehicles/three_wheeler_ape.png',
      capacity: 'Up to 400 kg',
    );
  }
  if (normalized.contains('dost')) {
    return const _VehiclePresentation(
      assetPath: 'assets/vehicles/dost.png',
      capacity: 'Up to 1250 kg',
    );
  }
  if (normalized.contains('407') || normalized.contains('water tanker')) {
    return const _VehiclePresentation(
      assetPath: 'assets/vehicles/tata_407.png',
      capacity: 'Up to 3000 L',
    );
  }
  return const _VehiclePresentation(
    assetPath: 'assets/vehicles/tata_ace.png',
    capacity: 'Up to 750 kg',
  );
}
