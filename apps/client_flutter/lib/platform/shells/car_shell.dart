import 'package:flutter/material.dart';

/// Wraps the UI for Car/Automotive experiences.
/// Optimizes for quick glances and larger touch targets.
class CarShell extends StatelessWidget {
  final Widget child;

  const CarShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        // Force minimum touch target sizes to be huge (e.g. 64x64)
        materialTapTargetSize: MaterialTapTargetSize.padded,
        iconTheme: Theme.of(context).iconTheme.copyWith(size: 48),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0), // Safer margins for car displays
        child: child,
      ),
    );
  }
}
