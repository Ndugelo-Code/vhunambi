import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/content_studio_preset.dart';

class TypographyPresetPicker extends StatelessWidget {
  final LyricTypographyPreset selectedPreset;
  final ValueChanged<LyricTypographyPreset> onPresetSelected;

  const TypographyPresetPicker({
    super.key,
    required this.selectedPreset,
    required this.onPresetSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.text_fields_rounded,
              size: 18,
              color: AppColors.brandPrimary,
            ),
            const SizedBox(width: 8),
            Text(
              'LYRIC TYPOGRAPHY PRESETS',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: LyricTypographyPreset.values.map((preset) {
            final isSelected = preset == selectedPreset;
            return InkWell(
              onTap: () => onPresetSelected(preset),
              borderRadius: AppRadius.inputBorder,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.brandPrimary.withValues(alpha: 0.15)
                      : AppColors.surfaceElevated,
                  borderRadius: AppRadius.inputBorder,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.brandPrimary
                        : AppColors.borderSubtle,
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      preset.label,
                      style: AppTypography.bodyLarge.copyWith(
                        color: isSelected ? AppColors.brandPrimary : AppColors.textPrimary,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      preset.description,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
