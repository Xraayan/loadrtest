import 'package:flutter/material.dart';
import 'package:loadr/constants.dart';
import 'package:loadr/services/api_service.dart';
import 'package:loadr/widgets/bottom_nav.dart';

class WalletDepositScreen extends StatefulWidget {
  const WalletDepositScreen({super.key});

  @override
  State<WalletDepositScreen> createState() => _WalletDepositScreenState();
}

class _WalletDepositScreenState extends State<WalletDepositScreen> {
  final _upiController = TextEditingController();
  Map<String, dynamic>? _ledger;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLedger();
  }

  @override
  void dispose() {
    _upiController.dispose();
    super.dispose();
  }

  Future<void> _loadLedger() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final uid = await ApiService.getUid();
      if (uid == null) throw Exception('User not authenticated');
      final ledger = await ApiService.getDriverLedger(uid);
      if (!mounted) return;
      setState(() => _ledger = ledger);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              top: false,
              child: RefreshIndicator(
                onRefresh: _loadLedger,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  children: [
                    _BalanceCard(summary: _summary),
                    const SizedBox(height: 18),
                    _UpiCard(controller: _upiController),
                    const SizedBox(height: 18),
                    if (_error != null)
                      _WalletInfoCard(
                        title: 'Wallet unavailable',
                        subtitle: _error!,
                        icon: Icons.error_outline,
                      )
                    else
                      _LedgerList(entries: _entries),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: const BottomNav(selectedIndex: 1),
    );
  }

  Map<String, dynamic> get _summary {
    final summary = _ledger?['summary'];
    return summary is Map ? Map<String, dynamic>.from(summary) : {};
  }

  List<Map<String, dynamic>> get _entries {
    final entries = _ledger?['entries'];
    if (entries is! List) return [];
    return entries
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }
}

class _BalanceCard extends StatelessWidget {
  final Map<String, dynamic> summary;

  const _BalanceCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final totalEarned = _asDouble(summary['total_earned']);
    final pendingAmount = _asDouble(summary['pending_amount']);
    final completedTrips = _asInt(summary['completed_trips']);
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
          Text(
            'Rs ${totalEarned.toStringAsFixed(0)}',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 36,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Pending Rs ${pendingAmount.toStringAsFixed(0)} - $completedTrips completed trips',
            style: TextStyle(
              color: kPrimaryOrange,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
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
          labelText: 'Withdrawal UPI ID',
          hintText: 'name@upi',
          prefixIcon: Icon(Icons.qr_code_2_outlined),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class _LedgerList extends StatelessWidget {
  final List<Map<String, dynamic>> entries;

  const _LedgerList({required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const _WalletInfoCard(
        title: 'Recent activity',
        subtitle: 'Paid trip amounts will appear here.',
        icon: Icons.receipt_long_outlined,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent activity',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        for (final entry in entries.take(12)) _LedgerRow(entry: entry),
      ],
    );
  }
}

class _LedgerRow extends StatelessWidget {
  final Map<String, dynamic> entry;

  const _LedgerRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final amount = _asDouble(entry['amount']);
    final status = '${entry['status'] ?? 'pending'}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long_outlined, color: kPrimaryOrange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry['title'] ?? 'Trip'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  status.replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'Rs ${amount.toStringAsFixed(0)}',
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
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

double _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

int _asInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
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
