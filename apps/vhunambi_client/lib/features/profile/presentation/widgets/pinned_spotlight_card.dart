import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/vhunambi_glass_surface.dart';
import '../../../../core/widgets/vhunambi_track_artwork.dart';
import '../../../../shared/models/track.dart';
import '../../../beats/presentation/providers/beats_provider.dart';
import '../../../explore/presentation/providers/explore_providers.dart';
import '../../../library/presentation/providers/library_providers.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../track/presentation/views/track_detail_view.dart';

/// Prominent hero card showcasing the creator's pinned spotlight anthem.
///
/// Displayed right above the studio tabs on both [OwnerProfileView] and [ArtistProfileView].
class PinnedSpotlightCard extends ConsumerWidget {
  final String? pinnedTrackId;
  final String fallbackCreatorName;

  const PinnedSpotlightCard({
    super.key,
    required this.pinnedTrackId,
    required this.fallbackCreatorName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (pinnedTrackId == null || pinnedTrackId!.isEmpty) {
      return const SizedBox.shrink();
    }

    final libraryTracks = ref.watch(libraryTracksProvider);
    final beats = ref.watch(beatsProvider);
    final exploreTracks = ref.watch(exploreTracksProvider);
    final playerState = ref.watch(playerStateProvider);

    // Resolve track entity from library, beats, or explore catalog
    String title = 'Featured Anthem';
    String genre = 'Amapiano';
    String durationLabel = '3:24';
    String creator = fallbackCreatorName;
    String? audioUrl;
    String? coverUrl;

    final libMatch = libraryTracks
        .where((t) => t.id == pinnedTrackId)
        .firstOrNull;

    if (libMatch != null) {
      title = libMatch.title;
      genre = libMatch.genre;
      durationLabel =
          '${libMatch.durationSeconds ~/ 60}:${(libMatch.durationSeconds % 60).toString().padLeft(2, '0')}';
      audioUrl = libMatch.localAudioFilePath ?? libMatch.remoteAudioUrl;
      coverUrl = libMatch.coverImageUrl;
    } else {
      final beatMatch = beats.where((b) => b.id == pinnedTrackId).firstOrNull;
      if (beatMatch != null) {
        title = beatMatch.title;
        genre = beatMatch.genre;
        durationLabel = '${beatMatch.bpm} BPM';
        audioUrl = beatMatch.previewAudioUrl;
      } else {
        final expMatch = exploreTracks
            .where((t) => t.id == pinnedTrackId)
            .firstOrNull;
        if (expMatch != null) {
          title = expMatch.title;
          genre = expMatch.genre;
          creator = expMatch.creatorName;
          durationLabel =
              '${expMatch.duration.inMinutes}:${(expMatch.duration.inSeconds % 60).toString().padLeft(2, '0')}';
          audioUrl = expMatch.audioUrl;
          coverUrl = expMatch.coverUrl;
        }
      }
    }

    final isPlaying =
        playerState.isPlaying && playerState.currentTrack?.id == pinnedTrackId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: VhunambiGlassSurface(
        key: const Key('profile_pinned_spotlight_card'),
        variant: VhunambiGlassVariant.card,
        enableLiveBlur: false,
        padding: const EdgeInsets.all(14),
        child: InkWell(
          borderRadius: AppRadius.cardBorder,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => TrackDetailView(trackId: pinnedTrackId!),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const PhosphorIcon(
                        PhosphorIconsFill.pushPin,
                        color: AppColors.brandPrimary,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'FEATURED ARTIST ANTHEM',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.brandPrimary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondaryOf(context),
                      borderRadius: AppRadius.pillBorder,
                      border: Border.all(
                        color: AppColors.borderSubtleOf(context),
                      ),
                    ),
                    child: Text(
                      genre,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondaryOf(context),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  VhunambiTrackArtwork(
                    coverUrl: coverUrl,
                    genre: genre,
                    trackId: pinnedTrackId!,
                    width: 52,
                    height: 52,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  const SizedBox(width: 12),

                  // Title & Metadata
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textPrimaryOf(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$creator • $durationLabel',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondaryOf(context),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 1-Tap Play/Pause Button (>=44dp target)
                  InkWell(
                    key: const Key('pinned_anthem_play_btn'),
                    onTap: () {
                      final player = ref.read(playerStateProvider.notifier);
                      if (isPlaying) {
                        player.togglePlayPause();
                      } else {
                        player.playTrack(
                          Track(
                            id: pinnedTrackId!,
                            title: title,
                            creatorName: creator,
                            genre: genre,
                            audioUrl:
                                audioUrl ??
                                'https://r2.vhunambi.com/audio/$pinnedTrackId.mp3',
                            coverUrl: coverUrl,
                            duration: const Duration(minutes: 3, seconds: 24),
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppColors.brandPrimary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: PhosphorIcon(
                          isPlaying ? AppIcons.pause : AppIcons.play,
                          color: AppColors.brandContrast,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
