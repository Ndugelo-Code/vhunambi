import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/content_studio_preset.dart';

class AtmosphericEffectsDeck extends StatelessWidget {
  final AtmosphericEffects effects;
  final void Function({bool? filmGrain, bool? bassPulse, bool? kenBurnsMotion})
  onToggle;

  const AtmosphericEffectsDeck({
    super.key,
    required this.effects,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final textSecondary = AppColors.textSecondaryOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const PhosphorIcon(
              AppIcons.sparkle,
              size: 16,
              color: AppColors.brandPrimary,
            ),
            const SizedBox(width: 6),
            Text(
              'ATMOSPHERIC OVERLAY SHADERS',
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
          height: 62,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildTogglePill(
                context: context,
                icon: PhosphorIconsRegular.filmStrip,
                title: '35mm Film Grain',
                value: effects.filmGrain,
                onChanged: (val) => onToggle(filmGrain: val),
              ),
              const SizedBox(width: 8),
              _buildTogglePill(
                context: context,
                icon: AppIcons.waveform,
                title: 'Bass-Reactive Pulse',
                value: effects.bassPulse,
                onChanged: (val) => onToggle(bassPulse: val),
              ),
              const SizedBox(width: 8),
              _buildTogglePill(
                context: context,
                icon: PhosphorIconsRegular.camera,
                title: 'Ken Burns Motion',
                value: effects.kenBurnsMotion,
                onChanged: (val) => onToggle(kenBurnsMotion: val),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTogglePill({
    required BuildContext context,
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: AppRadius.inputBorder,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: value
              ? AppColors.brandPrimary.withValues(alpha: 0.16)
              : AppColors.surfaceElevatedOf(context),
          borderRadius: AppRadius.inputBorder,
          border: Border.all(
            color: value
                ? AppColors.brandPrimary
                : AppColors.borderSubtleOf(context),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhosphorIcon(
              icon,
              size: 18,
              color: value ? AppColors.brandPrimary : textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: AppTypography.bodySmall.copyWith(
                color: value ? AppColors.brandPrimary : textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Switch.adaptive(
              value: value,
              activeTrackColor: AppColors.brandPrimary.withValues(alpha: 0.5),
              activeThumbColor: AppColors.brandPrimary,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
