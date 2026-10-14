import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

/// Renders a high-contrast focus indicator border when keyboard/switch navigation selects a component.
class A11yFocusIndicator extends StatelessWidget {
  final Widget child;
  final bool hasFocus;
  final BorderRadius borderRadius;
  final Color focusColor;
  final double borderWidth;

  const A11yFocusIndicator({
    super.key,
    required this.child,
    required this.hasFocus,
    this.borderRadius = AppRadius.cardBorder,
    this.focusColor = AppColors.brandPrimary,
    this.borderWidth = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: hasFocus
            ? Border.all(
                color: focusColor,
                width: borderWidth,
              )
            : Border.all(
                color: Colors.transparent,
                width: borderWidth,
              ),
      ),
      child: child,
    );
  }
}
