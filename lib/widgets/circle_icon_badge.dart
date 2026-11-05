// lib/widgets/circle_icon_badge.dart
//
// Circular tinted icon badge used by dashboard stat/metric cards,
// replacing the earlier square/rounded-rect badge treatment.

import 'package:flutter/material.dart';

class CircleIconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;

  const CircleIconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
    this.iconSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}
