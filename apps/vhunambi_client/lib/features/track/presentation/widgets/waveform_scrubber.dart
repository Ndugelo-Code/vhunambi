import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_glass_surface.dart';
import 'package:vhunambi_client/features/track/domain/models/track_detail_models.dart';

/// Interactive Amplitude Waveform Scrubber (`REQ-TRK-07`, `STD-UIUX-001`).
class WaveformScrubber extends StatelessWidget {
  final TrackDetailEntity track;
  final Duration currentPosition;
  final bool isPlaying;
  final ValueChanged<Duration>? onSeek;
  final VoidCallback? onTogglePlay;

  const WaveformScrubber({
    super.key,
    required this.track,
    this.currentPosition = Duration.zero,
    this.isPlaying = false,
    this.onSeek,
    this.onTogglePlay,
  });

  @override
  Widget build(BuildContext context) {
    final totalMillis = track.duration.inMilliseconds > 0
        ? track.duration.inMilliseconds
        : 1;
    final progress = (currentPosition.inMilliseconds / totalMillis).clamp(
      0.0,
      1.0,
    );
    final textSecondary = AppColors.textSecondaryOf(context);
    final inactiveBarColor = AppColors.borderSubtleOf(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: VhunambiGlassSurface(
        variant: VhunambiGlassVariant.card,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                IconButton(
                  key: const Key('track_waveform_play_btn'),
                  iconSize: 42,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  icon: PhosphorIcon(
                    isPlaying
                        ? PhosphorIconsFill.pauseCircle
                        : PhosphorIconsFill.playCircle,
                    color: AppColors.brandPrimary,
                    size: 42,
                  ),
                  onPressed: onTogglePlay,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const barCount = 38;
                      final activeBars = (progress * barCount).round();

                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (details) {
                          final ratio =
                              (details.localPosition.dx / constraints.maxWidth)
                                  .clamp(0.0, 1.0);
                          final target = Duration(
                            milliseconds: (ratio * totalMillis).round(),
                          );
                          onSeek?.call(target);
                        },
                        onHorizontalDragUpdate: (details) {
                          final ratio =
                              (details.localPosition.dx / constraints.maxWidth)
                                  .clamp(0.0, 1.0);
                          final target = Duration(
                            milliseconds: (ratio * totalMillis).round(),
                          );
                          onSeek?.call(target);
                        },
                        child: SizedBox(
                          height: 48,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: List.generate(barCount, (index) {
                              final isActive = index <= activeBars;
                              const heightFactors = <double>[
                                0.3, 0.5, 0.8, 0.4, 0.9, 0.6, 1.0, 0.7, 0.4,
                                0.6, 0.85, 0.5, 0.95, 0.4, 0.7, 0.3, 0.8, 0.6,
                                0.4, 0.9, 0.5, 0.75, 0.3, 0.65, 0.8, 0.45, 1.0,
                                0.55, 0.35, 0.85, 0.6, 0.4, 0.7, 0.9, 0.5, 0.3,
                                0.6, 0.8,
                              ];
                              final height =
                                  48.0 *
                                  heightFactors[index % heightFactors.length];

                              return Container(
                                width: (constraints.maxWidth / barCount) - 2.5,
                                height: height,
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? AppColors.brandPrimary
                                      : inactiveBarColor,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              );
                            }),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  _formatDuration(currentPosition),
                  style: AppTypography.caption.copyWith(
                    color: textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  track.formattedDuration,
                  style: AppTypography.caption.copyWith(
                    color: textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
