import 'package:flutter/material.dart';
import 'package:loadr/constants.dart';
import 'package:loadr/widgets/bottom_nav.dart';

class WalletDepositScreen extends StatefulWidget {
  const WalletDepositScreen({super.key});

  @override
  State<WalletDepositScreen> createState() => _WalletDepositScreenState();
}

class _WalletDepositScreenState extends State<WalletDepositScreen> {
  final _upiController = TextEditingController();
  final List<int> _quickAmounts = [100, 200, 300, 500];
  int _selectedAmount = 200;

  @override
  void dispose() {
    _upiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F7F7),
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.maybePop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/dashboard');
            }
          },
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
        ),
        title: const Text(
          'Wallet',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          children: [
            _BalanceCard(amount: _selectedAmount),
            const SizedBox(height: 18),
            const Text(
              'Add money',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            _AmountSelector(
              amounts: _quickAmounts,
              selectedAmount: _selectedAmount,
              onChanged: (amount) => setState(() => _selectedAmount = amount),
            ),
            const SizedBox(height: 18),
            _UpiCard(controller: _upiController),
            const SizedBox(height: 18),
            _WalletInfoCard(
              title: 'Recent activity',
              subtitle: 'Accepted trip payouts will appear here.',
              icon: Icons.receipt_long_outlined,
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryOrange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Add Rs $_selectedAmount',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNav(selectedIndex: 1),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final int amount;

  const _BalanceCard({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDEDED)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0EA),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: kPrimaryOrange,
                ),
              ),
              const Spacer(),
              const _StatusPill(text: 'Driver wallet'),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Available balance',
            style: TextStyle(
              color: Colors.black54,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Rs 0',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 36,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Ready to add Rs $amount',
            style: const TextStyle(
              color: kPrimaryOrange,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountSelector extends StatelessWidget {
  final List<int> amounts;
  final int selectedAmount;
  final ValueChanged<int> onChanged;

  const _AmountSelector({
    required this.amounts,
    required this.selectedAmount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final amount in amounts)
          ChoiceChip(
            selected: selectedAmount == amount,
            label: Text('Rs $amount'),
            onSelected: (_) => onChanged(amount),
            selectedColor: kPrimaryOrange,
            backgroundColor: Colors.white,
            labelStyle: TextStyle(
              color: selectedAmount == amount ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w800,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
              side: BorderSide(
                color: selectedAmount == amount
                    ? kPrimaryOrange
                    : const Color(0xFFE3E3E3),
              ),
            ),
          ),
      ],
    );
  }
}

class _UpiCard extends StatelessWidget {
  final TextEditingController controller;

  const _UpiCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(
          labelText: 'UPI ID',
          hintText: 'name@upi',
          prefixIcon: Icon(Icons.qr_code_2_outlined),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class _WalletInfoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _WalletInfoCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: Row(
        children: [
          Icon(icon, color: kPrimaryOrange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String text;

  const _StatusPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0EA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: kPrimaryOrange,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
