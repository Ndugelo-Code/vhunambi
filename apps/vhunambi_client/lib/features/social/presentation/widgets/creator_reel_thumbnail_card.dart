import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/vhunambi_track_artwork.dart';
import '../../domain/models/published_clip.dart';

/// Formats a play count into a compact label (24500 -> "24.5K").
String formatPlayCount(int count) {
  if (count >= 1000000) {
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }
  if (count >= 1000) {
    return '${(count / 1000).toStringAsFixed(1)}K';
  }
  return '$count';
}

/// 9:16 reel thumbnail card for a creator's "Clips & Reels" grid (REQ-SOC-07).
///
/// Image-only (no video controller) — tapping hands off to the zero-video
/// `KineticReelsModal` which renders the clip via its Song DNA.
class CreatorReelThumbnailCard extends StatelessWidget {
  final PublishedClip clip;
  final VoidCallback onTap;

  const CreatorReelThumbnailCard({
    super.key,
    required this.clip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('reel_card_${clip.id}'),
      onTap: onTap,
      child: ClipRRect(
        borderRadius: AppRadius.cardBorder,
        child: AspectRatio(
          aspectRatio: 9 / 16,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _CoverArt(clip: clip),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                    stops: [0.45, 1.0],
                  ),
                ),
              ),
              Positioned(
                top: 6,
                left: 6,
                child: _MetaPill(
                  icon: PhosphorIconsFill.play,
                  label: formatPlayCount(clip.playCount),
                ),
              ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _WaveformBars(seed: clip.id),
                    const SizedBox(height: 6),
                    Text(
                      clip.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '#${clip.genre}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoverArt extends StatelessWidget {
  final PublishedClip clip;
  const _CoverArt({required this.clip});

  @override
  Widget build(BuildContext context) {
    return VhunambiTrackArtwork(
      coverUrl: clip.coverUrl,
      genre: clip.genre,
      trackId: clip.trackId,
      borderRadius: BorderRadius.zero,
      showSubtleBorder: false,
      badgeIconSize: 28,
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: AppRadius.pillBorder,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PhosphorIcon(icon, size: 11, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Static, deterministic mini-waveform (heights derived from the clip id) —
/// avoids a live AnimationController so grid tests stay timer-clean.
class _WaveformBars extends StatelessWidget {
  final String seed;
  const _WaveformBars({required this.seed});

  @override
  Widget build(BuildContext context) {
    final base = seed.hashCode.abs();
    return SizedBox(
      height: 12,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 7; i++)
            Container(
              width: 3,
              height: 4 + ((base >> (i % 10)) & 7).toDouble(),
              margin: const EdgeInsets.only(right: 2),
              decoration: BoxDecoration(
                color: AppColors.brandPrimary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}
