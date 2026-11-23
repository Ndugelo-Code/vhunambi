import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/design_system/services/haptics_service.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/vhunambi_bottom_dock_kit.dart';
import '../../../../core/widgets/vhunambi_track_artwork.dart';
import '../providers/player_provider.dart';
import 'player_chromatic_resolver_mixin.dart';

class MobileMiniPlayer extends ConsumerStatefulWidget {
  final VoidCallback? onExpand;

  const MobileMiniPlayer({super.key, this.onExpand});

  @override
  ConsumerState<MobileMiniPlayer> createState() => _MobileMiniPlayerState();
}

class _MobileMiniPlayerState extends ConsumerState<MobileMiniPlayer>
    with
        TickerProviderStateMixin,
        PlayerChromaticPaletteMixin<MobileMiniPlayer> {
  // Play/pause bounce controller
  late final AnimationController _playBounce;
  late final Animation<double> _playScale;

  // Skip-prev bounce controller
  late final AnimationController _prevBounce;
  late final Animation<double> _prevScale;

  // Skip-next bounce controller
  late final AnimationController _nextBounce;
  late final Animation<double> _nextScale;

  @override
  void initState() {
    super.initState();

    _playBounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _playScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.82), weight: 30),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.82,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 70,
      ),
    ]).animate(_playBounce);

    _prevBounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    _prevScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.75), weight: 30),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.75,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 70,
      ),
    ]).animate(_prevBounce);

    _nextBounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    _nextScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.75), weight: 30),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.75,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 70,
      ),
    ]).animate(_nextBounce);
  }

  @override
  void dispose() {
    _playBounce.dispose();
    _prevBounce.dispose();
    _nextBounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerStateProvider);
    final track = playerState.currentTrack;

    if (!playerState.hasActiveTrack || track == null) {
      return const SizedBox.shrink();
    }

    final notifier = ref.read(playerStateProvider.notifier);
    final palette = resolvePlayerChromaticPalette(context, track);
    final accent = palette.accent;

    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    if (keyboardOpen) return const SizedBox.shrink();

    return VhunambiFloatingTransportSurface(
      glow: palette.primaryGlow,
      borderTint: palette.glassBorderTint,
      child: Column(
        children: [
          // 2 px tinted progress bar
          LinearProgressIndicator(
            value: playerState.progressRatio,
            minHeight: 2,
            backgroundColor: AppColors.borderSubtleOf(context),
            valueColor: AlwaysStoppedAnimation<Color>(accent),
          ),

          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity < -250) {
                  HapticsService().lightImpact();
                  _nextBounce.forward(from: 0);
                  notifier.skipNext();
                } else if (velocity > 250) {
                  HapticsService().lightImpact();
                  _prevBounce.forward(from: 0);
                  notifier.skipPrevious();
                }
              },
              onVerticalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity < -250) {
                  HapticsService().lightImpact();
                  widget.onExpand?.call();
                } else if (velocity > 250) {
                  HapticsService().lightImpact();
                  notifier.dismiss();
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    // ── Album art ──────────────────────────────────────────
                    GestureDetector(
                      key: const Key('mini_player_art'),
                      onTap: widget.onExpand,
                      child: Hero(
                        tag: 'now_playing_art_${track.id}',
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: palette.primaryGlow.withValues(
                                  alpha: 0.28,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: VhunambiTrackArtwork(
                            key: const Key('mini_player_artwork'),
                            coverUrl: track.coverUrl,
                            genre: track.genre,
                            trackId: track.id,
                            width: 44,
                            height: 44,
                            borderRadius: BorderRadius.circular(10),
                            badgeIconSize: 20,
                            showSubtleBorder: false,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // ── Metadata ───────────────────────────────────────────
                    Expanded(
                      child: GestureDetector(
                        onTap: widget.onExpand,
                        behavior: HitTestBehavior.opaque,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              style: AppTypography.bodyLarge.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimaryOf(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${track.genre} • ${playerState.formattedPosition} / ${playerState.formattedDuration}',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondaryOf(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 4),

                    // ── Skip previous ──────────────────────────────────────
                    Semantics(
                      label: 'Skip previous track',
                      child: ScaleTransition(
                        scale: _prevScale,
                        child: _SoftIconButton(
                          key: const Key('mini_player_prev'),
                          icon: AppIcons.skipBack,
                          accent: accent,
                          size: 44,
                          onPressed: () {
                            HapticsService().lightImpact();
                            _prevBounce.forward(from: 0);
                            notifier.skipPrevious();
                          },
                        ),
                      ),
                    ),

                    const SizedBox(width: 4),

                    // ── Play / Pause orb (larger, bouncy) ─────────────────
                    Semantics(
                      label: playerState.isPlaying ? 'Pause' : 'Play',
                      child: ScaleTransition(
                        scale: _playScale,
                        child: _PlayPauseOrb(
                          key: const Key('mini_player_play_pause'),
                          isPlaying: playerState.isPlaying,
                          accent: accent,
                          onAccent: palette.onAccent,
                          onPressed: () {
                            HapticsService().mediumImpact();
                            _playBounce.forward(from: 0);
                            notifier.togglePlayPause();
                          },
                        ),
                      ),
                    ),

                    const SizedBox(width: 4),

                    // ── Skip next ──────────────────────────────────────────
                    Semantics(
                      label: 'Skip next track',
                      child: ScaleTransition(
                        scale: _nextScale,
                        child: _SoftIconButton(
                          key: const Key('mini_player_next'),
                          icon: AppIcons.skipForward,
                          accent: accent,
                          size: 44,
                          onPressed: () {
                            HapticsService().lightImpact();
                            _nextBounce.forward(from: 0);
                            notifier.skipNext();
                          },
                        ),
                      ),
                    ),

                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Soft-rounded icon button for skip-prev / skip-next
// ─────────────────────────────────────────────────────────────────────────────
class _SoftIconButton extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final double size;
  final VoidCallback onPressed;

  const _SoftIconButton({
    super.key,
    required this.icon,
    required this.accent,
    required this.size,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.surfaceSecondaryOf(context).withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.borderSubtleOf(context).withValues(alpha: 0.65),
            width: 1,
          ),
        ),
        child: Center(
          child: PhosphorIcon(
            icon,
            color: AppColors.textPrimaryOf(context),
            size: 20,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Play / Pause orb — 52×52 accent circle with glow
// ─────────────────────────────────────────────────────────────────────────────
class _PlayPauseOrb extends StatelessWidget {
  final bool isPlaying;
  final Color accent;
  final Color onAccent;
  final VoidCallback onPressed;

  const _PlayPauseOrb({
    super.key,
    required this.isPlaying,
    required this.accent,
    required this.onAccent,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: accent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.45),
              blurRadius: 14,
              spreadRadius: 1,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: PhosphorIcon(
              isPlaying ? AppIcons.pause : AppIcons.play,
              key: ValueKey<bool>(isPlaying),
              color: onAccent,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
