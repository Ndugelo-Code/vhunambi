import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/design_system/services/haptics_service.dart';
import 'package:vhunambi_client/core/navigation/navigation_providers.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_track_artwork.dart';
import 'package:vhunambi_client/features/explore/presentation/providers/explore_providers.dart';
import 'package:vhunambi_client/features/library/domain/models/library_models.dart';
import 'package:vhunambi_client/features/library/presentation/providers/library_providers.dart';
import 'package:vhunambi_client/features/mastering/presentation/widgets/mobile_quick_master_sheet.dart';
import 'package:vhunambi_client/features/player/presentation/providers/player_provider.dart';
import 'package:vhunambi_client/features/player/presentation/widgets/expanded_cockpit_modal.dart';
import 'package:vhunambi_client/features/profile/presentation/providers/profile_providers.dart';
import 'package:vhunambi_client/shared/models/track.dart';

/// Zone 2: Zania-inspired compact Main Room player & "Jump Back In" deck
/// (`REQ-P68-PLAYER-01`, `REQ-P68-PLAYER-02`).
///
/// Registers [homeInlineNowPlayingMountedProvider] while mounted so [MiniPlayerHost]
/// suppresses duplicate floating playback pills on Home Tab 0.
class NowPlayingHomeCard extends ConsumerStatefulWidget {
  final VoidCallback? onNavigateToStudio;

  const NowPlayingHomeCard({
    super.key,
    this.onNavigateToStudio,
  });

  @override
  ConsumerState<NowPlayingHomeCard> createState() => _NowPlayingHomeCardState();
}

class _NowPlayingHomeCardState extends ConsumerState<NowPlayingHomeCard> {
  StateController<bool>? _inlineMountController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _inlineMountController =
          ref.read(homeInlineNowPlayingMountedProvider.notifier);
      _inlineMountController?.state = true;
    });
  }

  @override
  void dispose() {
    final controller = _inlineMountController;
    if (controller != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (controller.mounted) {
          controller.state = false;
        }
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerStateProvider);
    final libraryTracks = ref.watch(libraryTracksProvider);
    final exploreTracks = ref.watch(exploreTracksProvider);
    final ownerProfile = ref.watch(ownerProfileProvider);

    final validVaultTracks = libraryTracks.where((t) => !t.isDeleted).toList();
    final LibraryTrack? latestVault =
        validVaultTracks.isNotEmpty ? validVaultTracks.first : null;

    final hasUserActiveSession = player.hasActiveTrack &&
        player.currentTrack != null &&
        (player.currentTrack!.id != 'track_default_1' ||
            player.isPlaying ||
            player.position > Duration.zero);

    final Track? targetTrack;
    final List<Track> playbackQueue;
    if (hasUserActiveSession) {
      targetTrack = player.currentTrack;
      playbackQueue =
          player.queue.isNotEmpty ? player.queue : <Track>[targetTrack!];
    } else if (latestVault != null) {
      targetTrack = Track(
        id: latestVault.id,
        title: latestVault.title,
        creatorName: latestVault.creatorName.isNotEmpty
            ? latestVault.creatorName
            : ownerProfile.displayName,
        genre: latestVault.genre,
        language: latestVault.language,
        duration: Duration(seconds: latestVault.durationSeconds),
        audioUrl: latestVault.remoteAudioUrl,
        coverUrl: latestVault.coverImageUrl,
      );
      playbackQueue = <Track>[targetTrack, ...exploreTracks];
    } else if (exploreTracks.isNotEmpty) {
      targetTrack = exploreTracks.first;
      playbackQueue = exploreTracks;
    } else {
      targetTrack = null;
      playbackQueue = const <Track>[];
    }

    if (targetTrack == null) {
      return _buildEmptyStarterCard(context);
    }

    final isThisTrackLoaded =
        player.hasActiveTrack && player.currentTrack?.id == targetTrack.id;
    final isPlayingThis = isThisTrackLoaded && player.isPlaying;
    final progressRatio = isThisTrackLoaded ? player.progressRatio : 0.0;
    final positionLabel = isThisTrackLoaded ? player.formattedPosition : '0:00';
    final durationLabel = isThisTrackLoaded
        ? player.formattedDuration
        : targetTrack.formattedDuration;
    final headerEyebrow = isThisTrackLoaded ? 'Now Playing' : 'Jump Back In';

    void ensureActiveAndOpenCockpit() {
      FocusManager.instance.primaryFocus?.unfocus();
      HapticsService().lightImpact();
      if (!isThisTrackLoaded) {
        ref
            .read(playerStateProvider.notifier)
            .playTrack(targetTrack!, queue: playbackQueue);
      }
      ExpandedCockpitModal.show(context);
    }

    void togglePlayback() {
      HapticsService().mediumImpact();
      final notifier = ref.read(playerStateProvider.notifier);
      if (isThisTrackLoaded) {
        notifier.togglePlayPause();
      } else {
        notifier.playTrack(targetTrack!, queue: playbackQueue);
      }
    }

    void openQuickMaster() {
      FocusManager.instance.primaryFocus?.unfocus();
      HapticsService().lightImpact();
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => FractionallySizedBox(
          heightFactor: 0.9,
          child: MobileQuickMasterSheet(
            trackId: targetTrack!.id,
            trackTitle: targetTrack.title,
            genre: targetTrack.genre,
          ),
        ),
      );
    }

    return Container(
      key: const Key('home_now_playing_card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevatedOf(context),
        borderRadius: AppRadius.cardBorder,
        border: Border.all(
          color: isPlayingThis
              ? AppColors.brandPrimary.withValues(alpha: 0.55)
              : AppColors.borderSubtleOf(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                headerEyebrow,
                style: AppTypography.badge.copyWith(
                  color: isPlayingThis
                      ? AppColors.brandPrimary
                      : AppColors.textSecondaryOf(context),
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              Text(
                '$positionLabel / $durationLabel',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondaryOf(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              GestureDetector(
                onTap: ensureActiveAndOpenCockpit,
                child: VhunambiTrackArtwork(
                  coverUrl: targetTrack.coverUrl,
                  genre: targetTrack.genre,
                  trackId: targetTrack.id,
                  width: 60,
                  height: 60,
                  borderRadius: AppRadius.inputBorder,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: ensureActiveAndOpenCockpit,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        targetTrack.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleSmall.copyWith(
                          color: AppColors.textPrimaryOf(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${targetTrack.creatorName} • ${targetTrack.genre}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Center(
                  child: TextButton.icon(
                    key: const Key('home_jump_back_master_btn'),
                    onPressed: openQuickMaster,
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.surfaceSecondaryOf(context),
                      foregroundColor: AppColors.textPrimaryOf(context),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      minimumSize: const Size(0, 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.pillBorder,
                        side: BorderSide(
                          color: AppColors.borderSubtleOf(context),
                        ),
                      ),
                    ),
                    icon: const PhosphorIcon(
                      PhosphorIconsBold.slidersHorizontal,
                      size: 14,
                    ),
                    label: Text(
                      'Polish',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textPrimaryOf(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: AppColors.brandPrimary,
              inactiveTrackColor: AppColors.borderSubtleOf(context),
              thumbColor: AppColors.brandPrimary,
            ),
            child: Slider(
              key: const Key('home_player_scrub_slider'),
              value: progressRatio.clamp(0.0, 1.0),
              onChanged: isThisTrackLoaded
                  ? (value) =>
                      ref.read(playerStateProvider.notifier).seekByRatio(value)
                  : null,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Text(
                  'Tap cover for Pocket DAW cockpit',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      key: const Key('home_player_prev_btn'),
                      tooltip: 'Previous track',
                      icon: PhosphorIcon(
                        PhosphorIconsFill.skipBack,
                        size: 18,
                        color: AppColors.textPrimaryOf(context),
                      ),
                      onPressed: isThisTrackLoaded && player.queue.length > 1
                          ? () => ref
                              .read(playerStateProvider.notifier)
                              .skipPrevious()
                          : null,
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      key: const Key('home_player_play_pause_btn'),
                      tooltip: isPlayingThis ? 'Pause' : 'Play',
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.brandPrimary,
                        foregroundColor: AppColors.brandContrast,
                      ),
                      icon: PhosphorIcon(
                        isPlayingThis
                            ? PhosphorIconsFill.pause
                            : PhosphorIconsFill.play,
                        size: 18,
                        color: AppColors.brandContrast,
                      ),
                      onPressed: togglePlayback,
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      key: const Key('home_player_next_btn'),
                      tooltip: 'Next track',
                      icon: PhosphorIcon(
                        PhosphorIconsFill.skipForward,
                        size: 18,
                        color: AppColors.textPrimaryOf(context),
                      ),
                      onPressed: isThisTrackLoaded && player.queue.length > 1
                          ? () =>
                              ref.read(playerStateProvider.notifier).skipNext()
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStarterCard(BuildContext context) {
    return Container(
      key: const Key('home_now_playing_empty_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevatedOf(context),
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.borderSubtleOf(context)),
      ),
      child: Row(
        children: <Widget>[
          const PhosphorIcon(
            PhosphorIconsFill.vinylRecord,
            size: 32,
            color: AppColors.brandPrimary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Your Main Room is ready',
                  style: AppTypography.titleSmall.copyWith(
                    color: AppColors.textPrimaryOf(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Generate or save your first song to resume playback here.',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Center(
              child: ElevatedButton(
                onPressed: widget.onNavigateToStudio,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  foregroundColor: AppColors.brandContrast,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.pillBorder,
                  ),
                ),
                child: const Text('Start'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
