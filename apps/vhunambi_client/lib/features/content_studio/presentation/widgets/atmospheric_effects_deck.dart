import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/content_studio_preset.dart';

class AtmosphericEffectsDeck extends StatelessWidget {
  final AtmosphericEffects effects;
  final void Function({bool? filmGrain, bool? bassPulse, bool? kenBurnsMotion}) onToggle;

  const AtmosphericEffectsDeck({
    super.key,
    required this.effects,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.auto_awesome_rounded,
              size: 18,
              color: AppColors.brandPrimary,
            ),
            const SizedBox(width: 8),
            Text(
              'ATMOSPHERIC OVERLAY SHADERS',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildToggleTile(
          icon: Icons.grain_rounded,
          title: '35mm Film Grain',
          subtitle: 'Organic procedural analog noise texture overlay',
          value: effects.filmGrain,
          onChanged: (val) => onToggle(filmGrain: val),
        ),
        const SizedBox(height: 8),
        _buildToggleTile(
          icon: Icons.graphic_eq_rounded,
          title: 'Bass-Reactive Pulse',
          subtitle: 'Subtle radial bounce reacting to log drum frequencies',
          value: effects.bassPulse,
          onChanged: (val) => onToggle(bassPulse: val),
        ),
        const SizedBox(height: 8),
        _buildToggleTile(
          icon: Icons.camera_enhance_rounded,
          title: 'Ken Burns Motion',
          subtitle: 'Smooth 1.05x zoom drift and slow kinetic pan',
          value: effects.kenBurnsMotion,
          onChanged: (val) => onToggle(kenBurnsMotion: val),
        ),
      ],
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.inputBorder,
        border: Border.all(
          color: value
              ? AppColors.brandPrimary.withValues(alpha: 0.4)
              : AppColors.borderSubtle,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: value ? AppColors.brandPrimary : AppColors.textTertiary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeTrackColor: AppColors.brandPrimary.withValues(alpha: 0.5),
            activeThumbColor: AppColors.brandPrimary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
