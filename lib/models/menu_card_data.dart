import 'package:flutter/material.dart';

class MenuCardData {
  final String title;
  final String description;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String? route;

  const MenuCardData({
    required this.title,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    this.route,
  });
}
