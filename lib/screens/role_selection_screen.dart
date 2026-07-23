import 'package:flutter/material.dart';
import 'package:loadr/constants.dart';
import 'package:loadr/services/api_service.dart';
import 'package:loadr/widgets/skeleton.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? _selectedRole;
  bool _isSaving = false;

  Future<void> _continue() async {
    final role = _selectedRole;
    if (role == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please choose how you want to use LoadR')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final uid = await ApiService.getUid();
      if (uid == null) {
        throw Exception('User not authenticated');
      }

      await ApiService.selectRole(uid, role);

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/location');
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              const Icon(
                Icons.local_shipping_outlined,
                color: kPrimaryOrange,
                size: 42,
              ),
              const SizedBox(height: 28),
              const Text(
                'Choose your role',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This sets up the right dashboard and onboarding flow for you.',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              _RoleCard(
                title: 'I am a driver',
                description: 'Find loads, manage trips, wallet, and documents.',
                icon: Icons.badge_outlined,
                selected: _selectedRole == 'driver',
                onTap: () => setState(() => _selectedRole = 'driver'),
              ),
              const SizedBox(height: 16),
              _RoleCard(
                title: 'I am a customer',
                description: 'Book vehicles, track moves, and manage requests.',
                icon: Icons.inventory_2_outlined,
                selected: _selectedRole == 'user',
                onTap: () => setState(() => _selectedRole = 'user'),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _continue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryOrange,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        kPrimaryOrange.withValues(alpha: 0.6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSaving
                      ? const SkeletonButtonLabel(width: 72)
                      : const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFF0EA) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? kPrimaryOrange : const Color(0xFFE5E5E5),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: selected ? kPrimaryOrange : const Color(0xFFF4F4F4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: selected ? Colors.white : Colors.black54,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? kPrimaryOrange : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }
}
