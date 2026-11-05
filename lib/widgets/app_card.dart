// lib/widgets/app_card.dart
//
// Shared card surface that always inherits CardThemeData from the app's
// theme (radius, elevation, color) instead of screens hand-rolling their
// own Container + BoxDecoration + BoxShadow with inconsistent values.

import 'package:flutter/material.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cardTheme = Theme.of(context).cardTheme;
    final shape = cardTheme.shape;
    final borderRadius = shape is RoundedRectangleBorder
        ? shape.borderRadius
        : BorderRadius.circular(16);

    final content = Padding(padding: padding, child: child);

    return Card(
      color: color,
      clipBehavior: onTap != null ? Clip.antiAlias : Clip.none,
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              customBorder: RoundedRectangleBorder(
                borderRadius: borderRadius is BorderRadius
                    ? borderRadius
                    : BorderRadius.circular(16),
              ),
              child: content,
            )
          : content,
    );
  }
}
