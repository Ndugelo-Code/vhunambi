import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/design_system/tokens/app_icons.dart';
import 'package:vhunambi_client/core/design_system/tokens/vhunambi_mood.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_glass_surface.dart';
import 'package:vhunambi_client/features/track/domain/models/track_detail_models.dart';

/// Structured Song Description & Sonic Telemetry Glass Card (`REQ-P70-SCUX-04`).
class TrackSonicTelemetryCard extends StatelessWidget {
  final TrackDetailEntity track;
  final ValueChanged<VhunambiMood>? onMoodTap;

  const TrackSonicTelemetryCard({
    super.key,
    required this.track,
    this.onMoodTap,
  });

  String _formatDate(DateTime? date) {
    if (date == null) return 'Recent Release';
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final mood = track.canonicalMood;
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final description = track.description.trim().isNotEmpty
        ? track.description.trim()
        : '${track.title} — ${track.genre} production recorded in ${track.language}.';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: VhunambiGlassSurface(
        key: const Key('track_sonic_telemetry_card'),
        variant: VhunambiGlassVariant.card,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const PhosphorIcon(
                  AppIcons.info,
                  size: 18,
                  color: AppColors.brandPrimary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Song Description & Sonic DNA',
                  style: AppTypography.titleSmall.copyWith(color: textPrimary),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              description,
              style: AppTypography.bodyMuted.copyWith(color: textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _TelemetryChip(
                  icon: AppIcons.songs,
                  label: track.genre,
                ),
                _TelemetryChip(
                  icon: AppIcons.waveform,
                  label: '${track.bpm} BPM · ${track.musicalKey}',
                ),
                _TelemetryChip(
                  icon: AppIcons.disc,
                  label: '${track.language} · ${track.formattedDuration}',
                ),
                _TelemetryChip(
                  icon: PhosphorIconsRegular.calendarBlank,
                  label: _formatDate(track.createdAt),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: const Key('track_mood_chip'),
                    onTap: onMoodTap == null ? null : () => onMoodTap!(mood),
                    borderRadius: AppRadius.pillBorder,
                    child: VhunambiGlassSurface(
                      variant: VhunambiGlassVariant.pill,
                      tintAccent: mood.accentColor,
                      borderColorOverride: mood.accentColor.withValues(
                        alpha: 0.55,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          PhosphorIcon(
                            mood.icon,
                            size: 14,
                            color: mood.accentColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            mood.label,
                            style: AppTypography.caption.copyWith(
                              color: textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TelemetryChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TelemetryChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    return VhunambiGlassSurface(
      variant: VhunambiGlassVariant.pill,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PhosphorIcon(icon, size: 14, color: textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
