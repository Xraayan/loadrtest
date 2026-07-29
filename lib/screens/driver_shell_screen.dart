import 'package:flutter/material.dart';
import 'package:loadr/screens/dashboard_screen.dart';
import 'package:loadr/screens/messages_screen.dart';
import 'package:loadr/screens/profile_screen.dart';
import 'package:loadr/screens/wallet_deposit_screen.dart';
import 'package:loadr/widgets/bottom_nav.dart';

class DriverShellScreen extends StatefulWidget {
  final int initialIndex;

  const DriverShellScreen({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<DriverShellScreen> createState() => _DriverShellScreenState();
}

class _DriverShellScreenState extends State<DriverShellScreen> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  void _selectTab(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          DashboardScreen(
            showBottomNav: false,
            onTabSelected: _selectTab,
          ),
          const WalletDepositScreen(
            showBottomNav: false,
            showBackButton: false,
          ),
          const MessagesScreen(showBottomNav: false),
          const ProfileScreen(showBackButton: false),
        ],
      ),
      bottomNavigationBar: BottomNav(
        selectedIndex: _selectedIndex,
        onSelect: _selectTab,
      ),
    );
  }
}
