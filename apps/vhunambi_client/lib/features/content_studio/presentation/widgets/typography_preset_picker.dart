import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
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
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final borderSubtle = AppColors.borderSubtleOf(context);
    final surfaceElevated = AppColors.surfaceElevatedOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const PhosphorIcon(
              PhosphorIconsRegular.textAa,
              size: 16,
              color: AppColors.brandPrimary,
            ),
            const SizedBox(width: 6),
            Text(
              'LYRIC TYPOGRAPHY PRESETS',
              style: AppTypography.caption.copyWith(
                color: textSecondary,
                letterSpacing: 1.0,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 64,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: LyricTypographyPreset.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final preset = LyricTypographyPreset.values[index];
              final isSelected = preset == selectedPreset;
              return InkWell(
                onTap: () => onPresetSelected(preset),
                borderRadius: AppRadius.inputBorder,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.brandPrimary.withValues(alpha: 0.18)
                        : surfaceElevated,
                    borderRadius: AppRadius.inputBorder,
                    border: Border.all(
                      color: isSelected ? AppColors.brandPrimary : borderSubtle,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        preset.label,
                        style: AppTypography.bodySmall.copyWith(
                          color: isSelected
                              ? AppColors.brandPrimary
                              : textPrimary,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        preset.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
