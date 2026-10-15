import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/studio_haptics.dart';

/// Haptic flavour fired by [TactilePressable] on interaction (M10).
enum TactileHapticType { none, light, medium, heavy, selection }

/// Universal elastic micro-interaction wrapper (M10 / REQ-KIN-02, REQ-KIN-08).
///
/// - Pointer down scales the child to `0.96` over 80ms (`Curves.easeInOut`).
/// - Pointer up / cancel springs back to `1.0` over 220ms with
///   `Curves.easeOutBack` (playful overshoot).
/// - Fires the configured [StudioHaptics] trigger on pointer down.
///
/// Uses a [Listener] for the press physics (arena-independent — it keeps
/// working when the child owns its own tap gesture, e.g. an [ElevatedButton])
/// plus a permissive [GestureDetector] so `onTap` fires when the child is
/// gesture-inert.
class TactilePressable extends StatefulWidget {
  const TactilePressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.hapticType = TactileHapticType.light,
    this.pressedScale = 0.96,
    this.pressDuration = const Duration(milliseconds: 80),
    this.releaseDuration = const Duration(milliseconds: 220),
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final TactileHapticType hapticType;
  final double pressedScale;
  final Duration pressDuration;
  final Duration releaseDuration;

  @override
  State<TactilePressable> createState() => _TactilePressableState();
}

class _TactilePressableState extends State<TactilePressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.pressDuration,
      reverseDuration: widget.releaseDuration,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.pressedScale,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
        reverseCurve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _triggerHaptic() {
    switch (widget.hapticType) {
      case TactileHapticType.light:
        unawaited(StudioHaptics.chipSnap());
      case TactileHapticType.medium:
        unawaited(StudioHaptics.deckSwitch());
      case TactileHapticType.heavy:
        unawaited(StudioHaptics.ignitionThump());
      case TactileHapticType.selection:
        unawaited(StudioHaptics.sliderTick());
      case TactileHapticType.none:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (disableAnimations) {
      return GestureDetector(
        onTap: () {
          _triggerHaptic();
          widget.onTap?.call();
        },
        onLongPress: widget.onLongPress,
        behavior: HitTestBehavior.opaque,
        child: widget.child,
      );
    }

    return Listener(
      onPointerDown: (_) {
        _triggerHaptic();
        _controller.forward();
      },
      onPointerUp: (_) => _controller.reverse(),
      onPointerCancel: (_) => _controller.reverse(),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        behavior: HitTestBehavior.opaque,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: widget.child,
        ),
      ),
    );
  }
}
