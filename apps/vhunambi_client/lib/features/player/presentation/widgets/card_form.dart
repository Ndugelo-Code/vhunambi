import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/design_system/tokens/app_icons.dart';
import 'package:vhunambi_client/core/design_system/theme/vhunambi_theme_extension.dart';
import 'package:vhunambi_client/core/design_system/tokens/design_enums.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/player_provider.dart';

/// Card form — 128×128dp square floating card with cover art gradient and
/// progress percentage. Morphs from Bar via diagonal-up drag.
///
/// Snaps to left or right edge based on drag direction (16dp margin from
/// safe area edges). Opens Now Playing cockpit on tap.
class CardForm extends ConsumerWidget {
  final VoidCallback? onExpand;

  const CardForm({super.key, this.onExpand});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerStateProvider);
    final track = playerState.currentTrack;

    if (track == null) return const SizedBox.shrink();

    final genre = _mapStringToGenre(track.genre);
    final extension = VhunambiThemeExtension.of(context);
    final accent = extension.genreAccent(genre);

    return GestureDetector(
      onTap: onExpand,
      child: Container(
        width: 128,
        height: 128,
        decoration: BoxDecoration(
          gradient: AppGradients.forGenre(track.genre),
          borderRadius: AppRadius.cardBorder,
          border: Border.all(
            color: accent.withValues(alpha: 0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Cover art gradient placeholder.
            const Center(
              child: PhosphorIcon(
                AppIcons.piano,
                size: 48,
                color: Colors.white,
              ),
            ),

            // Progress overlay — bottom pill with play/pause + %.
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      playerState.isPlaying
                          ? AppIcons.pause
                          : AppIcons.play,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${(playerState.progressRatio * 100).toInt()}%',
                      style: AppTypography.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
}