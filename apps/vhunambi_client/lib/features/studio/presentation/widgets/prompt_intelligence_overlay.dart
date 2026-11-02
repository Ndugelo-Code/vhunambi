import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/prompt_enhancement_result.dart';
import '../utils/studio_haptics.dart';
import 'tactile_pressable.dart';

/// AI-refinement suggestion panel rendered beneath the prompt text field
/// (M10 / REQ-PRI-04).
///
/// Displays the enhanced prompt plus one auto-fill chip per detected studio
/// override with 1-tap apply / dismiss, an [Apply All] action, and a `×`
/// dismissal — all keyed for testability and wrapped in 44×44px ergonomics.
class PromptIntelligenceOverlay extends StatelessWidget {
  const PromptIntelligenceOverlay({
    super.key,
    required this.result,
    required this.onApplyOverride,
    required this.onDismissSuggestion,
    required this.onApplyAll,
    required this.onDismiss,
    this.dismissedFields = const <String>{},
  });

  /// Key: `Key('prompt_intelligence_overlay')`.
  static const Key overlayKey = Key('prompt_intelligence_overlay');

  final PromptEnhancementResult result;

  /// Applies a single field override (`fieldName`, `value`) to the form.
  final void Function(String fieldName, Object? value) onApplyOverride;

  /// Hides a single suggestion chip without applying it.
  final void Function(String fieldName) onDismissSuggestion;

  /// Applies every remaining suggestion at once.
  final VoidCallback onApplyAll;

  /// Dismisses the whole overlay.
  final VoidCallback onDismiss;

  /// Field names whose individual chips were dismissed.
  final Set<String> dismissedFields;

  String _fieldLabel(String fieldName) => switch (fieldName) {
        'genre' => 'Genre',
        'language' => 'Language',
        'vocalGender' => 'Vocal Gender',
        'vocalMode' => 'Vocal Mode',
        'mood' => 'Mood',
        _ => fieldName,
      };

  @override
  Widget build(BuildContext context) {
    final visibleFields = result.suggestedOverrides.keys
        .where((field) => !dismissedFields.contains(field))
        .toList();

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: Container(
        key: overlayKey,
        width: double.infinity,
        margin: const EdgeInsets.only(top: AppSpacing.xs),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.brandPrimary.withAlpha(15),
          borderRadius: AppRadius.inputBorder,
          border: Border.all(color: AppColors.brandPrimary.withAlpha(90)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: 14,
                  color: AppColors.brandPrimary,
                ),
                const SizedBox(width: AppSpacing.xxs),
                Expanded(
                  child: Text(
                    'AI refined your prompt',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.brandPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('prompt_intelligence_dismiss'),
                  tooltip: 'Dismiss',
                  constraints:
                      const BoxConstraints(minWidth: 44, minHeight: 44),
                  padding: EdgeInsets.zero,
                  onPressed: onDismiss,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
            Text(
              result.enhancedPrompt,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (visibleFields.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final field in visibleFields)
                    _AutoFillChip(
                      fieldName: field,
                      label: _fieldLabel(field),
                      value: '${result.suggestedOverrides[field]}',
                      onApply: () {
                        unawaited(StudioHaptics.chipSnap());
                        onApplyOverride(
                          field,
                          result.suggestedOverrides[field],
                        );
                      },
                      onDismiss: () => onDismissSuggestion(field),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              TactilePressable(
                hapticType: TactileHapticType.medium,
                onTap: () {
                  unawaited(StudioHaptics.successPulse());
                  onApplyAll();
                },
                child: Container(
                  key: const Key('prompt_intelligence_apply_all'),
                  constraints: const BoxConstraints(minHeight: 44),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary,
                    borderRadius: AppRadius.pillBorder,
                  ),
                  child: Text(
                    'Apply All ✨',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.brandContrast,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Single detected-override suggestion pill (M10 / REQ-PRI-04).
class _AutoFillChip extends StatelessWidget {
  const _AutoFillChip({
    required this.fieldName,
    required this.label,
    required this.value,
    required this.onApply,
    required this.onDismiss,
  });

  final String fieldName;
  final String label;
  final String value;
  final VoidCallback onApply;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return TactilePressable(
      hapticType: TactileHapticType.light,
      onTap: onApply,
      child: Container(
        key: Key('autofill_chip_$fieldName'),
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.only(left: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surfaceSecondary,
          borderRadius: AppRadius.pillBorder,
          border: Border.all(color: AppColors.brandPrimary.withAlpha(120)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label: $value',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                key: Key('autofill_chip_dismiss_$fieldName'),
                tooltip: 'Ignore $label',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.expand(),
                onPressed: onDismiss,
                icon: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
