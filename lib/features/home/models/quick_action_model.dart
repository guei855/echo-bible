import 'package:flutter/material.dart';

class QuickActionModel {
  final String title;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const QuickActionModel({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });
}
