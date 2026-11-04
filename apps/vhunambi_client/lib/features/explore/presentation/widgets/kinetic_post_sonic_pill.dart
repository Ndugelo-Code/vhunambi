import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../domain/models/social_music_post.dart';
import '../providers/explore_providers.dart';

/// Non-invasive floating sonic pill for Kinetic Posts (REQ-KPOST-SONIC-01).
/// Docks either as a frosted glass overlay (40dp) inside the visual canvas
/// or as a slim capsule (44dp) on text-only posts.
class KineticPostSonicPill extends ConsumerStatefulWidget {
  final SocialMusicPost post;
  final bool isOverlay;

  const KineticPostSonicPill({
    super.key,
    required this.post,
    this.isOverlay = false,
  });

  @override
  ConsumerState<KineticPostSonicPill> createState() =>
      _KineticPostSonicPillState();
}

class _KineticPostSonicPillState extends ConsumerState<KineticPostSonicPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _eqController;

  @override
  void initState() {
    super.initState();
    _eqController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
  }

  @override
  void dispose() {
    _eqController.dispose();
    super.dispose();
  }

  void _handlePlayToggle(bool isPlayingThis) {
    HapticFeedback.lightImpact();
    if (isPlayingThis) {
      ref.read(playerStateProvider.notifier).pause();
    } else {
      playExploreTrack(ref, widget.post.track);
    }
  }

  String _formatDurationBadge() {
    final audio = widget.post.audioAttachment;
    if (audio != null && audio.clipDurationSec > 0) {
      final dur = audio.clipDurationSec.toInt();
      final mins = dur ~/ 60;
      final secs = dur % 60;
      final timeStr =
          '$mins:${secs.toString().padLeft(2, '0')}';
      return audio.clipStartSec > 0 ? '$timeStr Hook' : '$timeStr Snippet';
    }
    return widget.post.track.formattedDuration;
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerStateProvider);
    final isPlayingThis =
        player.isPlaying && player.currentTrack?.id == widget.post.track.id;
    final isOverlay = widget.isOverlay;

    if (isPlayingThis) {
      if (!_eqController.isAnimating) {
        _eqController.repeat(reverse: true);
      }
    } else {
      if (_eqController.isAnimating) {
        _eqController.stop();
        _eqController.reset();
      }
    }

    final sourceLabel =
        widget.post.audioAttachment?.sourceType.label ?? 'Song';
    final durationBadge = _formatDurationBadge();

    final pillContent = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Play / Pause Action Button (Preserves Key)
        GestureDetector(
          key: Key('social_post_play_btn_${widget.post.id}'),
          onTap: () => _handlePlayToggle(isPlayingThis),
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOverlay
                  ? AppColors.brandPrimary
                  : AppColors.brandPrimary.withValues(alpha: 0.15),
            ),
            alignment: Alignment.center,
            child: PhosphorIcon(
              isPlayingThis
                  ? PhosphorIconsFill.pause
                  : PhosphorIconsFill.play,
              size: 16,
              color: isOverlay
                  ? AppColors.brandContrast
                  : AppColors.brandPrimary,
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Track Title & Source / Duration Badges
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      widget.post.track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isOverlay
                            ? Colors.white
                            : AppColors.textPrimary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Source Badge ('Song', 'Beat', 'Voice DNA', 'Groove')
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: isOverlay
                          ? Colors.white.withValues(alpha: 0.2)
                          : AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isOverlay
                            ? Colors.white.withValues(alpha: 0.3)
                            : AppColors.borderSubtle,
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      sourceLabel,
                      style: AppTypography.caption.copyWith(
                        color: isOverlay
                            ? Colors.white.withValues(alpha: 0.9)
                            : AppColors.brandPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 9.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 1),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${widget.post.track.creatorName} · $durationBadge',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: isOverlay
                            ? Colors.white.withValues(alpha: 0.75)
                            : AppColors.textSecondary,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(width: 6),

        // Micro-Equalizer Visualizer
        _MicroEqualizerBars(
          isPlaying: isPlayingThis,
          controller: _eqController,
          isOverlay: isOverlay,
        ),
      ],
    );

    if (isOverlay) {
      return Container(
        key: Key('kinetic_post_sonic_pill_${widget.post.id}'),
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.58),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 0.75,
                ),
              ),
              child: pillContent,
            ),
          ),
        ),
      );
    }

    return Container(
      key: Key('kinetic_post_sonic_pill_${widget.post.id}'),
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: pillContent,
    );
  }
}

class _MicroEqualizerBars extends StatelessWidget {
  final bool isPlaying;
  final AnimationController controller;
  final bool isOverlay;

  const _MicroEqualizerBars({
    required this.isPlaying,
    required this.controller,
    required this.isOverlay,
  });

  static const List<double> _baseHeights = [4.0, 10.0, 16.0, 8.0];

  @override
  Widget build(BuildContext context) {
    final barColor = isOverlay
        ? AppColors.brandPrimary
        : AppColors.brandPrimary;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < _baseHeights.length; i++) ...[
              Container(
                width: 2.5,
                height: isPlaying
                    ? (_baseHeights[i] *
                            (0.4 + 0.6 * ((controller.value + (i * 0.25)) % 1.0)))
                        .clamp(3.0, 18.0)
                    : 3.0,
                decoration: BoxDecoration(
                  color: isPlaying
                      ? barColor
                      : (isOverlay
                          ? Colors.white.withValues(alpha: 0.4)
                          : AppColors.borderSubtle),
                  borderRadius: BorderRadius.circular(1.25),
                ),
              ),
              if (i < _baseHeights.length - 1) const SizedBox(width: 2),
            ],
          ],
        );
      },
    );
  }
}

