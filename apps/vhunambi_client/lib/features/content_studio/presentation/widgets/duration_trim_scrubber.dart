import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/content_studio_preset.dart';

class DurationTrimScrubber extends StatelessWidget {
  final DurationPreset selectedPreset;
  final double startSeconds;
  final double endSeconds;
  final double maxDurationSec;
  final double playbackPositionSec;
  final ValueChanged<DurationPreset> onPresetChanged;
  final void Function(double start, double end) onTrimBoundsChanged;
  final ValueChanged<double>? onSeek;

  const DurationTrimScrubber({
    super.key,
    required this.selectedPreset,
    required this.startSeconds,
    required this.endSeconds,
    required this.maxDurationSec,
    required this.playbackPositionSec,
    required this.onPresetChanged,
    required this.onTrimBoundsChanged,
    this.onSeek,
  });

  String _formatTime(double sec) {
    final mins = sec ~/ 60;
    final remainingSecs = (sec % 60).toInt();
    final ms = ((sec - sec.toInt()) * 10).toInt();
    return '${mins.toString().padLeft(2, '0')}:${remainingSecs.toString().padLeft(2, '0')}.${ms}s';
  }

  @override
  Widget build(BuildContext context) {
    final clipDuration = (endSeconds - startSeconds).clamp(1.0, maxDurationSec);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.content_cut_rounded,
                    size: 18,
                    color: AppColors.brandPrimary,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'CLIP DURATION & TRIMMING',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.brandPrimary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                'Clip: ${clipDuration.toStringAsFixed(1)}s',
                style: AppTypography.caption.copyWith(
                  color: AppColors.brandPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Duration Presets Row
        Row(
          children: DurationPreset.values.map((preset) {
            final isSelected = preset == selectedPreset;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  onTap: () => onPresetChanged(preset),
                  borderRadius: AppRadius.thumbBorder,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.brandPrimary
                          : AppColors.surfaceElevated,
                      borderRadius: AppRadius.thumbBorder,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.brandPrimary
                            : AppColors.borderSubtle,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        preset.label,
                        style: AppTypography.bodyLarge.copyWith(
                          color: isSelected
                              ? AppColors.brandContrast
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // Range Slider
        RangeSlider(
          values: RangeValues(
            startSeconds.clamp(0.0, maxDurationSec),
            endSeconds.clamp(startSeconds + 1.0, maxDurationSec),
          ),
          min: 0.0,
          max: maxDurationSec > 0.0 ? maxDurationSec : 180.0,
          activeColor: AppColors.brandPrimary,
          inactiveColor: AppColors.surfaceSecondary,
          onChanged: (RangeValues values) {
            onTrimBoundsChanged(values.start, values.end);
          },
        ),

        // Timestamps Bounds Indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'Start: ${_formatTime(startSeconds)}',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Flexible(
              child: Text(
                'Pos: ${_formatTime(playbackPositionSec)}',
                style: AppTypography.caption.copyWith(
                  color: AppColors.brandPrimary,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Flexible(
              child: Text(
                'End: ${_formatTime(endSeconds)}',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                ),
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
