import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_glass_surface.dart';
import 'package:vhunambi_client/features/social/domain/models/kinetic_reaction.dart';

/// Frosted-glass floating pill reaction tray triggered by long-press (`REQ-P73-SOC-04`).
///
/// Supports direct tap OR continuous horizontal drag-to-scrub with `1.4x` hover
/// magnification and `HapticFeedback.selectionClick()`.
class ReactionTrayOverlay {
  static OverlayEntry? _activeEntry;

  static void dismiss() {
    _activeEntry?.remove();
    _activeEntry = null;
  }

  static void show({
    required BuildContext context,
    required Offset anchorGlobalPosition,
    required KineticReactionType? activeReaction,
    required ValueChanged<KineticReactionType> onSelected,
  }) {
    dismiss();
    HapticFeedback.mediumImpact();

    final overlay = Overlay.of(context, rootOverlay: true);
    final screenSize = MediaQuery.sizeOf(context);
    const pillWidth = 286.0;
    const pillHeight = 56.0;

    final clampedLeft = (anchorGlobalPosition.dx - pillWidth * 0.35).clamp(
      12.0,
      (screenSize.width - pillWidth - 12.0).clamp(12.0, double.infinity),
    );
    final clampedTop = (anchorGlobalPosition.dy - pillHeight - 20.0).clamp(
      MediaQuery.paddingOf(context).top + 12.0,
      screenSize.height - pillHeight - 24.0,
    );

    _activeEntry = OverlayEntry(
      builder: (_) => _ReactionTrayLayer(
        left: clampedLeft,
        top: clampedTop,
        pillWidth: pillWidth,
        activeReaction: activeReaction,
        onDismiss: dismiss,
        onSelected: (rx) {
          dismiss();
          HapticFeedback.lightImpact();
          onSelected(rx);
        },
      ),
    );
    overlay.insert(_activeEntry!);
  }
}

class _ReactionTrayLayer extends StatefulWidget {
  final double left;
  final double top;
  final double pillWidth;
  final KineticReactionType? activeReaction;
  final VoidCallback onDismiss;
  final ValueChanged<KineticReactionType> onSelected;

  const _ReactionTrayLayer({
    required this.left,
    required this.top,
    required this.pillWidth,
    required this.activeReaction,
    required this.onDismiss,
    required this.onSelected,
  });

  @override
  State<_ReactionTrayLayer> createState() => _ReactionTrayLayerState();
}

class _ReactionTrayLayerState extends State<_ReactionTrayLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  KineticReactionType? _hovered;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateHoverFromLocalX(double localX) {
    const reactions = KineticReactionType.values;
    final slotWidth = widget.pillWidth / reactions.length;
    final index = (localX / slotWidth).floor();
    final next =
        (index >= 0 && index < reactions.length) ? reactions[index] : null;
    if (next != _hovered) {
      if (next != null) HapticFeedback.selectionClick();
      setState(() => _hovered = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: GestureDetector(
            key: const Key('reaction_tray_barrier'),
            behavior: HitTestBehavior.translucent,
            onTap: widget.onDismiss,
          ),
        ),
        Positioned(
          left: widget.left,
          top: widget.top,
          child: Material(
            color: Colors.transparent,
            child: ScaleTransition(
              scale: CurvedAnimation(
                parent: _controller,
                curve: Curves.easeOutBack,
              ),
              child: GestureDetector(
                key: const Key('reaction_tray_overlay'),
                onHorizontalDragUpdate: (details) =>
                    _updateHoverFromLocalX(details.localPosition.dx),
                onHorizontalDragEnd: (_) {
                  if (_hovered != null) {
                    widget.onSelected(_hovered!);
                  }
                },
                child: VhunambiGlassSurface(
                  variant: VhunambiGlassVariant.pill,
                  enableLiveBlur: true,
                  blurSigma: 14.0,
                  width: widget.pillWidth,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: KineticReactionType.values.map((rx) {
                      final isHovered = _hovered == rx;
                      final isSelected = widget.activeReaction == rx;
                      return GestureDetector(
                        key: Key('reaction_tray_item_${rx.wireId}'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => widget.onSelected(rx),
                        child: AnimatedScale(
                          scale: isHovered ? 1.40 : (isSelected ? 1.15 : 1.0),
                          duration: const Duration(milliseconds: 120),
                          curve: Curves.easeOutCubic,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              KineticReactionBadge(type: rx, size: 34),
                              const SizedBox(height: 2),
                              Text(
                                rx.label,
                                maxLines: 1,
                                softWrap: false,
                                style: AppTypography.caption.copyWith(
                                  fontSize: 9,
                                  fontWeight: isSelected || isHovered
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected || isHovered
                                      ? rx.accentColor
                                      : AppColors.textSecondaryOf(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(growable: false),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
