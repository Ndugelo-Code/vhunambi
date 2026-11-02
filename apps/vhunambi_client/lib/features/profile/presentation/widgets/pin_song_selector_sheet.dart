import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../beats/presentation/providers/beats_provider.dart';
import '../../../library/presentation/providers/library_providers.dart';
import '../providers/profile_providers.dart';

/// Modal picker allowing creators to pin a featured anthem to the top of their profile.
class PinSongSelectorSheet extends ConsumerWidget {
  const PinSongSelectorSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceModal,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.modalBorder,
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      builder: (_) => const PinSongSelectorSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryTracks = ref.watch(libraryTracksProvider);
    final beats = ref.watch(beatsProvider);
    final currentPinnedId = ref.watch(ownerProfileProvider).pinnedTrackId;
    final activeTracks =
        libraryTracks.where((t) => !t.isDeleted).toList(growable: false);
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Drag Handle & Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textTertiary.withAlpha(80),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const PhosphorIcon(
                            PhosphorIconsRegular.pushPin,
                            color: AppColors.brandPrimary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Select Featured Anthem',
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const PhosphorIcon(AppIcons.close, size: 20),
                      ),
                    ],
                  ),
                  if (currentPinnedId != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        key: const Key('pin_song_unpin_action'),
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          ref
                              .read(ownerProfileProvider.notifier)
                              .setPinnedTrack(null);
                          Navigator.of(context).pop();
                        },
                        icon: const PhosphorIcon(
                          PhosphorIconsRegular.xCircle,
                          size: 16,
                          color: AppColors.error,
                        ),
                        label: Text(
                          'Unpin Current Anthem',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            Divider(height: 1, color: AppColors.borderSubtle),

            // Selectable List of Songs and Beats
            Expanded(
              child: activeTracks.isEmpty && beats.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No tracks or beats found in your vault.\nProduce or license a song to pin it as your anthem.',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      children: [
                        if (activeTracks.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'VAULT SONGS',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          for (final track in activeTracks)
                            _buildSelectableTile(
                              context: context,
                              ref: ref,
                              id: track.id,
                              title: track.title,
                              subtitle:
                                  '${track.genre} • ${track.durationSeconds ~/ 60}:${(track.durationSeconds % 60).toString().padLeft(2, '0')}',
                              isPinned: currentPinnedId == track.id,
                              icon: AppIcons.songs,
                            ),
                          const SizedBox(height: 16),
                        ],
                        if (beats.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'BEATSTORE PRODUCTIONS',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          for (final beat in beats)
                            _buildSelectableTile(
                              context: context,
                              ref: ref,
                              id: beat.id,
                              title: beat.title,
                              subtitle:
                                  '${beat.bpm} BPM • ${beat.musicalKey} • ${beat.genre}',
                              isPinned: currentPinnedId == beat.id,
                              icon: AppIcons.drums,
                            ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectableTile({
    required BuildContext context,
    required WidgetRef ref,
    required String id,
    required String title,
    required String subtitle,
    required bool isPinned,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isPinned
            ? AppColors.brandPrimary.withAlpha(25)
            : AppColors.surfaceElevated,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(
          color: isPinned ? AppColors.brandPrimary : AppColors.borderSubtle,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          key: Key('pin_tile_$id'),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: PhosphorIcon(
              icon,
              size: 20,
              color: isPinned
                  ? AppColors.brandPrimary
                  : AppColors.textSecondary,
            ),
          ),
        ),
        title: Text(
          title,
          style: AppTypography.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: isPinned ? AppColors.brandPrimary : AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        trailing: isPinned
            ? const PhosphorIcon(
                PhosphorIconsFill.pushPin,
                color: AppColors.brandPrimary,
                size: 20,
              )
            : PhosphorIcon(
                PhosphorIconsRegular.pushPin,
                color: AppColors.textTertiary,
                size: 20,
              ),
        onTap: () {
          HapticFeedback.mediumImpact();
          ref.read(ownerProfileProvider.notifier).setPinnedTrack(id);
          Navigator.of(context).pop();
        },
      ),
    ),
  );
}
}

