import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:loadr/screens/dashboard_screen.dart';

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  String _selectedPeriod = 'Monthly';

  final List<String> _periodOptions = ['Daily', 'Weekly', 'Monthly', 'Yearly'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => const DashboardScreen(),
              ),
              (route) => false),
          icon: const Icon(Icons.arrow_back),
        ),
        backgroundColor: Colors.white,
        title: Text(
          "Ledger",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 28),

              _buildGreeting(),
              const SizedBox(height: 28),

              _buildActionCards(),
              const SizedBox(height: 28),

              // All orders content inside ONE orange bordered container
              Container(
                decoration: BoxDecoration(
                  border:
                      Border.all(color: const Color(0xFFE64A19), width: 1.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    // Orders header row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: _buildOrdersHeader(),
                    ),

                    const Divider(
                        height: 1, thickness: 1, color: Color(0xFFE0E0E0)),

                    _buildSummaryRow(
                      label: 'Total Amount',
                      value: '₹ 15000',
                      valueColor: Colors.black,
                      labelWeight: FontWeight.bold,
                      showDivider: true,
                    ),
                    _buildSummaryRow(
                      label: 'Cash Collection',
                      value: '₹ 800',
                      valueColor: const Color(0xFF4CAF50),
                      labelWeight: FontWeight.w600,
                      showDivider: true,
                    ),
                    _buildSummaryRow(
                      label: 'Online Payment',
                      value: '₹ 800',
                      valueColor: const Color(0xFFE64A19),
                      labelWeight: FontWeight.w600,
                      showDivider: true,
                    ),
                    _buildSummaryRow(
                      label: 'Commission(20%)',
                      value: '₹ 200',
                      valueColor: const Color(0xFFE64A19),
                      labelWeight: FontWeight.w600,
                      showDivider: true,
                    ),
                    _buildSummaryRow(
                      label: 'Convenience Fee(2.5%)',
                      value: '₹ 40',
                      valueColor: const Color(0xFFE64A19),
                      labelWeight: FontWeight.w600,
                      showDivider: true,
                    ),
                    _buildSummaryRow(
                      label: 'Your Earnings',
                      value: '₹ 1,200',
                      valueColor: const Color(0xFF4CAF50),
                      labelWeight: FontWeight.bold,
                      showDivider: false, // last row — no divider
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGreeting() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hello Micheal...',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFFBDBDBD),
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Good afternoon',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF9E9E9E),
          ),
        ),
      ],
    );
  }

  Widget _buildActionCards() {
    return Row(
      children: [
        Expanded(
          child: _buildCard(
            'See All',
            const Icon(Icons.list_alt_rounded,
                size: 40, color: Color(0xFFE64A19)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildCard(
            'Get PDF',
            const Icon(Icons.download_rounded,
                size: 40, color: Color(0xFFE64A19)),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(String title, Icon iconName) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: Center(child: iconName),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE64A19),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Orders',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        _buildPeriodDropdown(),
      ],
    );
  }

  Widget _buildPeriodDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE64A19), width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedPeriod,
          icon: const Icon(
            Icons.arrow_drop_down,
            color: Color(0xFFE64A19),
            size: 20,
          ),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFFE64A19),
          ),
          isDense: true,
          items: _periodOptions.map((String period) {
            return DropdownMenuItem<String>(
              value: period,
              child: Text(period),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() => _selectedPeriod = newValue);
            }
          },
        ),
      ),
    );
  }

  Widget _buildSummaryRow({
    required String label,
    required String value,
    required Color valueColor,
    required FontWeight labelWeight,
    required bool showDivider,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: labelWeight,
                  color: Colors.black87,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, thickness: 1, color: Color(0xFFE0E0E0)),
      ],
    );
  }
}
