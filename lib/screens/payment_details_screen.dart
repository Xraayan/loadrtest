import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

class PaymentDetailsScreen extends StatefulWidget {
  final int amount;
  final String topUpType;

  const PaymentDetailsScreen({
    super.key,
    this.amount = 100,
    this.topUpType = 'Paytm',
  });

  @override
  State<PaymentDetailsScreen> createState() => _PaymentDetailsScreenState();
}

class _PaymentDetailsScreenState extends State<PaymentDetailsScreen> {
  final TextEditingController _upiController = TextEditingController();
  static const Color _primaryOrange = Color(0xFFE8431A);

  String get _formattedDate {
    final now = DateTime.now();
    return '${now.day}/${now.month}/${now.year}';
  }

  String get _formattedTime {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    return '$h:$m';
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
        backgroundColor: const Color(0xFFF2F2F7),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87, size: 24),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.maybePop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/customer-home');
            }
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // ── Title ─────────────────────────────────────────────────
                  const Text(
                    'Payment Details',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                      letterSpacing: -0.5,
                    ),
                  ),

                  const SizedBox(height: 36),

                  // ── Details Card ──────────────────────────────────────────
                  _buildDetailsCard(),

                  const SizedBox(height: 28),

                  // ── UPI Input ─────────────────────────────────────────────
                  _buildUpiInput(),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // ── Bottom Section ────────────────────────────────────────────────
          _buildBottomSection(),
        ],
      ),
    );
  }

  // ─── Details Card ─────────────────────────────────────────────────────────
  Widget _buildDetailsCard() {
    final rows = [
      _DetailRow(label: 'Amount', value: 'Rs ${widget.amount}', bold: true),
      _DetailRow(label: 'Top up Type', value: widget.topUpType, bold: true),
      _DetailRow(label: 'Date', value: _formattedDate, bold: true),
      _DetailRow(label: 'Time', value: _formattedTime, bold: true),
    ];

    return Column(
      children: rows
          .map(
            (row) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    row.label,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.grey,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Text(
                    row.value,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.black87,
                      fontWeight: row.bold ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  // ─── UPI Input ────────────────────────────────────────────────────────────
  Widget _buildUpiInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _upiController,
        keyboardType: TextInputType.emailAddress,
        decoration: InputDecoration(
          hintText: 'Please enter UPI ID',
          hintStyle: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
        style: const TextStyle(
          fontSize: 15,
          color: Colors.black87,
        ),
      ),
    );
  }

  // ─── Bottom Section ───────────────────────────────────────────────────────
  Widget _buildBottomSection() {
    return Container(
      color: const Color(0xFFF2F2F7),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        children: [
          // Security note
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.shield_outlined,
                color: Colors.grey.shade400,
                size: 36,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                      height: 1.5,
                    ),
                    children: [
                      const TextSpan(
                        text: 'All your transactions are safe and fast, '
                            'By continuing this transaction, you agree to our ',
                      ),
                      TextSpan(
                        text: 'Terms & Conditions',
                        style: const TextStyle(
                          color: _primaryOrange,
                          fontWeight: FontWeight.w600,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            // Handle T&C tap
                          },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Deposit button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                // Handle deposit
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
        ],
      ),
    );
  }
}

// ─── Helper model ─────────────────────────────────────────────────────────────
class _DetailRow {
  final String label;
  final String value;
  final bool bold;
  const _DetailRow(
      {required this.label, required this.value, this.bold = false});
}
