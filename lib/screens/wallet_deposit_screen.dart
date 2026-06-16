import 'package:flutter/material.dart';
import 'package:loadr/screens/dashboard_screen.dart';
import 'package:loadr/widgets/bottom_nav.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wallet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFFF2F2F7),
      ),
      home: const WalletDepositScreen(),
    );
  }
}

class WalletDepositScreen extends StatefulWidget {
  const WalletDepositScreen({super.key});

  @override
  State<WalletDepositScreen> createState() => _WalletDepositScreenState();
}

class _WalletDepositScreenState extends State<WalletDepositScreen> {
  double _sliderValue = 100;
  int _selectedAmount = 100;
  final TextEditingController _upiController = TextEditingController();

  final List<int> _quickAmounts = [100, 200, 300, 500];

  static const Color _primaryOrange = Color(0xFFE8431A);
  static const Color _darkBlue = Color(0xFF1A237E);

  void _onQuickAmountSelected(int amount) {
    setState(() {
      _selectedAmount = amount;
      _sliderValue = amount.toDouble();
    });
  }

  @override
  void dispose() {
    _upiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
            onPressed: () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const DashboardScreen(),
                ),
                (route) => false),
            icon: const Icon(Icons.arrow_back)),
        title: const Text(
          'Wallet',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: _primaryOrange, size: 26),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.crop_free, color: _primaryOrange, size: 26),
            onPressed: () {},
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 32),

                  // ── Amount Section ──
                  _buildAmountSection(),

                  const SizedBox(height: 28),

                  // ── Slider ──
                  _buildSlider(),

                  const SizedBox(height: 20),

                  // ── Quick Amount Buttons ──
                  _buildQuickAmounts(),

                  const SizedBox(height: 36),

                  // ── UPI Section ──
                  _buildUpiSection(),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // ── Deposit Button ──
          _buildDepositButton(),
        ],
      ),
      bottomNavigationBar: BottomNav(
        selectedIndex: 1,
      ),
    );
  }

  // ─── Amount Display ───────────────────────────────────────────────────────
  Widget _buildAmountSection() {
    return Column(
      children: [
        const Text(
          'Amount',
          style: TextStyle(
            fontSize: 16,
            color: Colors.black54,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Rs ${_selectedAmount.toInt()}',
          style: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w900,
            color: Colors.black87,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Your Current Balance:',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  // ─── Slider ───────────────────────────────────────────────────────────────
  Widget _buildSlider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          activeTrackColor: _primaryOrange,
          inactiveTrackColor: Colors.grey.shade300,
          thumbColor: _primaryOrange,
          overlayColor: _primaryOrange.withOpacity(0.15),
          trackHeight: 4.0,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 22),
        ),
        child: Slider(
          value: _sliderValue.clamp(100, 500),
          min: 100,
          max: 500,
          divisions: 400,
          onChanged: (value) {
            setState(() {
              _sliderValue = value;
              _selectedAmount = value.toInt();
            });
          },
        ),
      ),
    );
  }

  // ─── Quick Amount Buttons ─────────────────────────────────────────────────
  Widget _buildQuickAmounts() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: _quickAmounts.map((amount) {
          final bool isSelected = _selectedAmount == amount;
          return GestureDetector(
            onTap: () => _onQuickAmountSelected(amount),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 78,
              height: 56,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFFAEDE8) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? _primaryOrange.withOpacity(0.4)
                      : Colors.grey.shade200,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '$amount',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? _primaryOrange : Colors.black87,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── UPI Section ──────────────────────────────────────────────────────────
  Widget _buildUpiSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter UPI',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _darkBlue,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black87, width: 1.5),
            ),
            child: Row(
              children: [
                // PhonePe-style logo

                Expanded(
                  child: TextField(
                    controller: _upiController,
                    decoration: const InputDecoration(
                      hintText: 'Enter your UPI',
                      hintStyle: TextStyle(
                        color: Colors.grey,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 16),
                    ),
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Deposit Button ───────────────────────────────────────────────────────
  Widget _buildDepositButton() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: SizedBox(
        height: 56,
        child: ElevatedButton(
          onPressed: () {
            // Handle deposit action
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryOrange,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text(
            'DEPOSIT',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
