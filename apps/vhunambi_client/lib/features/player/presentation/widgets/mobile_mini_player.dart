import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/services/haptics_service.dart';
import '../../../../core/design_system/theme/vhunambi_theme_extension.dart';
import '../../../../core/design_system/tokens/design_enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/vhunambi_bottom_dock_kit.dart';
import '../providers/player_provider.dart';

class MobileMiniPlayer extends ConsumerWidget {
  final VoidCallback? onExpand;

  const MobileMiniPlayer({
    super.key,
    this.onExpand,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerStateProvider);
    final track = playerState.currentTrack;

    if (!playerState.hasActiveTrack || track == null) {
      return const SizedBox.shrink();
    }

    final notifier = ref.read(playerStateProvider.notifier);
    final genre = _mapStringToGenre(track.genre);
    final extension = VhunambiThemeExtension.of(context);
    final accent = extension.genreAccent(genre);

    // Floating frosted "island" pill with an ambient glow sampled from the
    // track's genre gradient. Dismiss is a swipe-down gesture (not a button),
    // freeing horizontal room so every transport control keeps a 44x44 target.
    // Hide the mini player when the keyboard is open to prevent layout
    // collision on the Create screen (VH-001, REQ-RWD-03).
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    if (keyboardOpen) return const SizedBox.shrink();

    return VhunambiFloatingTransportSurface(
      glow: accent,
      child: Column(
        children: [
          // 2px progress line (non-interactive on mobile; scrub in the cockpit).
          LinearProgressIndicator(
            value: playerState.progressRatio,
            minHeight: 2,
            backgroundColor: AppColors.borderSubtle,
            valueColor: AlwaysStoppedAnimation<Color>(accent),
          ),

          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragEnd: (details) {
                // `primaryVelocity` is nullable on some drag terminations.
                final velocity = details.primaryVelocity ?? 0;
                if (velocity < -250) {
                  HapticsService().lightImpact();
                  notifier.skipNext();
                } else if (velocity > 250) {
                  HapticsService().lightImpact();
                  notifier.skipPrevious();
                }
              },
              // Vertical fling → drag up to expand the cockpit, drag down to
              // dismiss the player (replaces the old 28x28 dismiss button).
              // The gesture arena disambiguates by dominant axis, so this does
              // not conflict with the horizontal swipe-to-skip above.
              onVerticalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity < -250) {
                  HapticsService().lightImpact();
                  onExpand?.call();
                } else if (velocity > 250) {
                  HapticsService().lightImpact();
                  notifier.dismiss();
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    // Leading 44x44 album art (tap to expand).
                    GestureDetector(
                      onTap: onExpand,
                      child: Hero(
                        tag: 'now_playing_art_${track.id}',
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: AppGradients.forGenre(track.genre),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.piano_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                  // Metadata Stack
                  Expanded(
                    child: GestureDetector(
                      onTap: onExpand,
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
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${track.genre} • ${playerState.formattedPosition} / ${playerState.formattedDuration}',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Skip previous — 44x44 hit target.
                  Semantics(
                    label: 'Skip previous track',
                    child: IconButton(
                      icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                      onPressed: () {
                        HapticsService().lightImpact();
                        notifier.skipPrevious();
                      },
                    ),
                  ),

                  // Play/Pause orb — 44x44 hit target.
                  Semantics(
                    label: playerState.isPlaying ? 'Pause' : 'Play',
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          playerState.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: _contrastTextColor(accent),
                          size: 22,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                        onPressed: () {
                          HapticsService().mediumImpact();
                          notifier.togglePlayPause();
                        },
                      ),
                    ),
                  ),
                  // Skip next — 44x44 hit target.
                  Semantics(
                    label: 'Skip next track',
                    child: IconButton(
                      icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                      onPressed: () {
                        HapticsService().lightImpact();
                        notifier.skipNext();
                      },
                    ),
                  ),
                ],
              ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Maps a free-form [genre] string from [Track] to a
  /// [Genre] enum for the design system token registry.
  ///
  /// Unknown genres fall back to [Genre.amapiano].
  Genre _mapStringToGenre(String genre) {
    final normalized = genre.trim().toLowerCase();
    return switch (normalized) {
      'amapiano' => Genre.amapiano,
      'afro house' => Genre.afroHouse,
      'afrohouse' => Genre.afroHouse,
      'gqom' => Genre.gqom,
      'kwaito' => Genre.kwaito,
      'afro pop' => Genre.afroPop,
      'afropop' => Genre.afroPop,
      'afrobeats' => Genre.afroPop,
      'afro beats' => Genre.afroPop,
      'maskandi' => Genre.maskandi,
      'hip hop' => Genre.hipHop,
      'hiphop' => Genre.hipHop,
      'gospel' => Genre.gospel,
      _ => Genre.amapiano,
    };
  }

  /// Returns a high-contrast text color (black or white) for [background]
  /// based on its relative luminance, ensuring WCAG AA readability.
  Color _contrastTextColor(Color background) {
    final luminance = background.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}
