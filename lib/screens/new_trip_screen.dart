import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:loadr/services/api_service.dart';
import 'package:loadr/widgets/skeleton.dart';

class NewTripScreen extends StatefulWidget {
  const NewTripScreen({super.key});

  @override
  State<NewTripScreen> createState() => _NewTripScreenState();
}

class _NewTripScreenState extends State<NewTripScreen> {
  final TextEditingController stateController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  bool _isLoading = false;
  List<dynamic> _jobs = [];

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  @override
  void dispose() {
    stateController.dispose();
    cityController.dispose();
    super.dispose();
  }

  Future<void> _loadJobs() async {
    setState(() => _isLoading = true);
    try {
      final jobs = await ApiService.getJobs(
        state: stateController.text,
        city: cityController.text,
      );
      if (!mounted) return;
      setState(() {
        _jobs = jobs;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Loads error: $e')),
      );
    }
  }

  Future<void> _openJob(Map<String, dynamic> job) async {
    await Navigator.pushNamed(
      context,
      '/driver-load-request',
      arguments: job,
    );
    if (mounted) _loadJobs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.maybePop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/dashboard');
            }
          },
          icon: const Icon(Icons.arrow_back),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'New Trip',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadJobs,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Find Loads',
              style: GoogleFonts.poppins(
                fontSize: 30,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Search open loads by state or city, then view the route before accepting.',
              style: GoogleFonts.poppins(color: Colors.black54, fontSize: 15),
            ),
            const SizedBox(height: 20),
            _SearchField(
              controller: stateController,
              label: 'State',
              hint: 'Kerala',
            ),
            const SizedBox(height: 12),
            _SearchField(
              controller: cityController,
              label: 'City',
              hint: 'Kochi',
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _loadJobs,
                icon: const Icon(Icons.search, color: Colors.white),
                label: const Text(
                  'Search Loads',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const CardListSkeleton()
            else if (_jobs.isEmpty)
              _EmptyJobs(onReset: () {
                stateController.clear();
                cityController.clear();
                _loadJobs();
              })
            else
              ..._jobs.map(
                (job) => _JobCard(
                  job: job as Map<String, dynamic>,
                  onTap: () => _openJob(job),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;

  const _SearchField({
    required this.controller,
    required this.label,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: const Icon(Icons.search, color: Colors.orange),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.deepOrange),
          borderRadius: BorderRadius.circular(18),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.deepOrange, width: 2),
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final Map<String, dynamic> job;
  final VoidCallback onTap;

  const _JobCard({
    required this.job,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final amount = num.tryParse('${job['amount'] ?? 0}') ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFECECEC)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '${job['title'] ?? 'Open load'}',
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      'Rs ${amount.toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(
                        color: Colors.deepOrange,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _RouteLine(
                  icon: Icons.trip_origin,
                  label: '${job['pickup_location'] ?? '-'}',
                ),
                const SizedBox(height: 6),
                _RouteLine(
                  icon: Icons.location_on_outlined,
                  label: '${job['dropoff_location'] ?? '-'}',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Chip(label: '${job['city'] ?? 'Any city'}'),
                    _Chip(label: '${job['district'] ?? 'Any district'}'),
                    _Chip(label: '${job['state'] ?? 'Any state'}'),
                    _Chip(label: '${job['vehicle_type'] ?? 'Any vehicle'}'),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: onTap,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.deepOrange,
                      side: const BorderSide(color: Color(0xFFFFC8B6)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.map_outlined),
                    label: const Text(
                      'View Details',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteLine extends StatelessWidget {
  final IconData icon;
  final String label;

  const _RouteLine({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.deepOrange),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;

  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFECE8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _EmptyJobs extends StatelessWidget {
  final VoidCallback onReset;

  const _EmptyJobs({required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.search_off, size: 54, color: Colors.grey.shade500),
          const SizedBox(height: 12),
          Text(
            'No open loads found',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onReset, child: const Text('Show all loads')),
        ],
      ),
    );
  }
}
