import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../domain/models/player_state.dart';
import '../../../library/presentation/providers/library_providers.dart';
import '../../../offline/presentation/widgets/offline_indicator_badge.dart';
import '../providers/player_provider.dart';
import 'queue_drawer.dart';

class ExpandedCockpitModal extends ConsumerWidget {
  const ExpandedCockpitModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ExpandedCockpitModal(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerStateProvider);
    final track = playerState.currentTrack;

    if (track == null) {
      return const SizedBox.shrink();
    }

    final notifier = ref.read(playerStateProvider.notifier);

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.88,
      decoration: const BoxDecoration(
        color: AppColors.surfaceModal,
        borderRadius: AppRadius.modalBorder,
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 30,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Drag Handle
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF4B5563),
                borderRadius: BorderRadius.circular(9999),
              ),
            ),
            const SizedBox(height: 12),

            // Top Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Text(
                    'Now Playing',
                    style: AppTypography.titleMedium.copyWith(color: AppColors.textSecondary),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_horiz_rounded, size: 24, color: Colors.white),
                    onPressed: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Hero Artwork Card (1:1 Aspect Ratio)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppGradients.forGenre(track.genre),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.brandPrimary.withAlpha(80),
                            blurRadius: 40,
                            spreadRadius: -8,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.piano_rounded,
                          size: 72,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Track Info Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          style: AppTypography.titleLarge.copyWith(fontSize: 22),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              track.creatorName,
                              style: AppTypography.bodyMuted.copyWith(fontSize: 15),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.verified_rounded, color: AppColors.brandPrimary, size: 16),
                            const SizedBox(width: 8),
                            Text('•  ${track.genre}', style: AppTypography.caption),
                            if (ref.watch(libraryTracksProvider).any(
                              (t) => t.id == track.id && t.isOfflineAvailable,
                            )) ...[
                              const SizedBox(width: 8),
                              const OfflineIndicatorBadge(isCompact: true),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.favorite_rounded, color: AppColors.brandPrimary, size: 26),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.ios_share_rounded, color: AppColors.textSecondary, size: 22),
                    onPressed: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Waveform Scrubber
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      final box = context.findRenderObject() as RenderBox?;
                      if (box != null) {
                        final ratio = (details.localPosition.dx / box.size.width).clamp(0.0, 1.0);
                        notifier.seekByRatio(ratio);
                      }
                    },
                    child: Container(
                      height: 42,
                      alignment: Alignment.center,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(40, (index) {
                          final barRatio = index / 40;
                          final isElapsed = barRatio <= playerState.progressRatio;
                          final barHeight = 10.0 + (index % 5) * 6.0;

                          return Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 1.5),
                              height: barHeight,
                              decoration: BoxDecoration(
                                color: isElapsed ? AppColors.brandPrimary : AppColors.borderSubtle,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(playerState.formattedPosition, style: AppTypography.caption),
                      Text(playerState.formattedDuration, style: AppTypography.caption),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // DAW Transport Control Deck
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.shuffle_rounded,
                      color: playerState.isShuffle ? AppColors.brandPrimary : AppColors.textSecondary,
                      size: 24,
                    ),
                    onPressed: notifier.toggleShuffle,
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_previous_rounded, size: 36, color: Colors.white),
                    onPressed: notifier.skipPrevious,
                  ),
                  // Primary 64x64px Play/Pause Orb
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.brandPrimary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.brandPrimary.withAlpha(100),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(
                        playerState.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 36,
                        color: AppColors.brandContrast,
                      ),
                      onPressed: notifier.togglePlayPause,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next_rounded, size: 36, color: Colors.white),
                    onPressed: notifier.skipNext,
                  ),
                  IconButton(
                    icon: Icon(
                      playerState.repeatMode == AudioRepeatMode.one
                          ? Icons.repeat_one_rounded
                          : Icons.repeat_rounded,
                      color: playerState.repeatMode != AudioRepeatMode.off
                          ? AppColors.brandPrimary
                          : AppColors.textSecondary,
                      size: 24,
                    ),
                    onPressed: notifier.cycleRepeatMode,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Track Utility Tray
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: AppRadius.pillBorder,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _UtilityItem(
                    icon: Icons.lyrics_outlined,
                    label: 'Lyrics',
                    onTap: () {},
                  ),
                  _UtilityItem(
                    icon: Icons.tune_rounded,
                    label: 'Stems',
                    onTap: () {},
                  ),
                  _UtilityItem(
                    icon: Icons.download_rounded,
                    label: 'Export',
                    onTap: () {},
                  ),
                  _UtilityItem(
                    icon: Icons.queue_music_rounded,
                    label: 'Queue',
                    onTap: () => QueueDrawer.show(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _UtilityItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _UtilityItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(label, style: AppTypography.caption.copyWith(color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}
