import 'package:flutter/material.dart';

/// Wraps the UI for TV experiences.
/// Uses a Theme override to enlarge text and icons.
/// Focus traversal is naturally handled by Flutter's Focus system, 
/// but this ensures UI elements have clear active states.
class TvShell extends StatelessWidget {
  final Widget child;

  const TvShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(
              bodyColor: Colors.white,
              displayColor: Colors.white,
              fontSizeFactor: 1.5, // 10-foot UI scaling
            ),
        iconTheme: Theme.of(context).iconTheme.copyWith(size: 36),
        // Add subtle focus highlights to all focusable elements
        focusColor: Colors.white.withAlpha(50),
      ),
      child: FocusScope(
        autofocus: true,
        child: child,
      ),
    );
  }
}
