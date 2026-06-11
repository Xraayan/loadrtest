// Under Development !!!!
/* ================================*/

import 'package:flutter/material.dart';
import 'package:loadr/screens/dashboard_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            onPressed: () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const DashboardScreen(),
                ),
                (route) => false),
            icon: const Icon(Icons.arrow_back)),
        backgroundColor: Colors.white,
        title: Text("Notifications"),
      ),
    );
  }
}
