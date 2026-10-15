import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../utils/studio_haptics.dart';

/// Kinetic tab navigation with a sliding pill indicator and tactile feedback
/// (M10 / REQ-KIN-03).
///
/// The active pill glides between tabs with `Curves.easeOutCubic` over 240ms
/// while tab labels cross-fade, making the Studio deck switch feel like
/// sliding between physical synthesizer decks.
class FluidDeckSwitcher extends StatelessWidget {
  const FluidDeckSwitcher({
    super.key,
    required this.activeIndex,
    required this.tabLabels,
    required this.onTabSelected,
    this.duration = const Duration(milliseconds: 240),
  });

  /// Currently active tab index.
  final int activeIndex;

  /// Ordered tab labels (`Compose`, `Voice`, `Crate & MPC`).
  final List<String> tabLabels;

  /// Called when a different tab is tapped.
  final ValueChanged<int> onTabSelected;

  /// Slide duration for the pill indicator.
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.pillBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = (constraints.maxWidth - 8) / tabLabels.length;
          return Stack(
            children: [
              // Sliding active pill
              AnimatedPositioned(
                duration: duration,
                curve: Curves.easeOutCubic,
                left: 4 + activeIndex * tabWidth,
                top: 0,
                bottom: 0,
                width: tabWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary,
                    borderRadius: AppRadius.pillBorder,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.brandPrimary.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              // Tab labels
              Row(
                children: List.generate(tabLabels.length, (index) {
                  final isSelected = index == activeIndex;
                  return Expanded(
                    child: GestureDetector(
                      key: Key('studio_deck_tab_$index'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (index != activeIndex) {
                          unawaited(StudioHaptics.deckSwitch());
                          onTabSelected(index);
                        }
                      },
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 180),
                          style: AppTypography.bodySmall.copyWith(
                            color: isSelected
                                ? AppColors.brandContrast
                                : AppColors.textSecondary,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                          child: Text(
                            tabLabels[index],
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}