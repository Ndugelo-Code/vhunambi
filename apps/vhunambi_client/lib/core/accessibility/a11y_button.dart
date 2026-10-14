import 'package:flutter/material.dart';

/// Accessible button wrapper guaranteeing WCAG touch target compliance and semantic labels.
class A11yButton extends StatelessWidget {
  final String semanticLabel;
  final VoidCallback? onPressed;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool enabled;
  final double minSize;

  const A11yButton({
    super.key,
    required this.semanticLabel,
    required this.onPressed,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.enabled = true,
    this.minSize = 48.0,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      enabled: enabled,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: minSize,
          minHeight: minSize,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            child: Padding(
              padding: padding,
              child: Center(
                widthFactor: 1.0,
                heightFactor: 1.0,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
