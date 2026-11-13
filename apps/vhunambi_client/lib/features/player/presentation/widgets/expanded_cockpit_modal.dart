import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/design_system/services/haptics_service.dart';
import '../../../../core/design_system/theme/vhunambi_theme_extension.dart';
import '../../../../core/design_system/tokens/design_enums.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../domain/models/player_state.dart';
import '../../../../shared/models/track.dart';
import '../../../library/domain/models/library_models.dart';
import '../../../library/presentation/providers/library_providers.dart';
import '../../../library/presentation/widgets/track_actions_sheet.dart';
import '../../../library/presentation/widgets/track_details_modal.dart';
import '../../../offline/presentation/widgets/offline_indicator_badge.dart';
import '../providers/mini_player_controller.dart';
import '../providers/player_provider.dart';
import 'queue_drawer.dart';
import '../../../content_studio/presentation/providers/master_media_object_provider.dart';
import '../../../mastering/presentation/providers/mastering_session_provider.dart';
import '../../../studio/presentation/providers/studio_form_provider.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/song_metadata_dna.dart';
import 'package:vhunambi_client/features/content_studio/presentation/views/content_studio_dock_view.dart';
import 'package:vhunambi_client/features/social/domain/models/video_export_job.dart';
import 'package:vhunambi_client/features/social/presentation/widgets/video_export_modal.dart';
import 'stem_mixer_deck.dart';
import 'player_living_biome_hero_viewport.dart';
import '../../../studio/domain/models/mycelium_biome_models.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../../notifications/domain/models/notification_entity.dart';
import '../../../notifications/domain/models/notification_enums.dart';

/// True when the active player [trackId] is hearted in the vault.
bool _isFavorite(WidgetRef ref, String trackId) {
  return ref
      .watch(libraryTracksProvider)
      .any((track) => track.id == trackId && track.isFavorite);
}

class ExpandedCockpitModal extends ConsumerStatefulWidget {
  const ExpandedCockpitModal({super.key});

  static void show(BuildContext context) {
    final nav = Navigator.maybeOf(context);
    final navContext = nav != null
        ? context
        : (appNavigatorKey.currentContext ?? context);
    final height = MediaQuery.sizeOf(navContext).height;
    // Organic expand: scale/fade/rise out of the pill while the shared
    // artwork Hero flies up. showGeneralDialog gives barrier + tap-to-dismiss.
    showGeneralDialog(
      context: navContext,
      useRootNavigator: false,
      barrierDismissible: true,
      barrierLabel: 'Dismiss now playing',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 340),
      pageBuilder: (context, _, _) => Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          height: height * 0.88,
          child: const ExpandedCockpitModal(),
        ),
      ),
      transitionBuilder: (context, anim, _, child) {
        final pop = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeIn,
        );
        final rise = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeIn,
        );
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(rise),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1.0).animate(pop),
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  ConsumerState<ExpandedCockpitModal> createState() =>
      _ExpandedCockpitModalState();
}

class _ExpandedCockpitModalState extends ConsumerState<ExpandedCockpitModal> {
  PlayerHeroMode _heroMode = PlayerHeroMode.artwork;
  bool get _showLyrics => _heroMode == PlayerHeroMode.lyrics;
  late MiniPlayerController _miniPlayerController;

  @override
  void initState() {
    super.initState();
    _miniPlayerController = ref.read(miniPlayerControllerProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _miniPlayerController.setNowPlayingOpen(true);
      }
    });
  }

  @override
  void dispose() {
    Future.microtask(() {
      try {
        _miniPlayerController.setNowPlayingOpen(false);
      } catch (_) {}
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerStateProvider);
    final track = playerState.currentTrack;

    if (track == null) {
      return const SizedBox.shrink();
    }

    final notifier = ref.read(playerStateProvider.notifier);
    final genre = _mapStringToGenre(track.genre);
    final extension = VhunambiThemeExtension.of(context);
    final accent = extension.genreAccent(genre);

    final masteringState = ref.watch(masteringSessionProvider);
    final isMasteredActive = masteringState.isMasteredPreviewActive;

    final dna = SongMetadataDna.fromTrackInfo(
      id: track.id,
      title: track.title,
      genre: track.genre,
      language: track.language,
      durationSec: track.duration.inSeconds,
      coverUrl: track.coverUrl,
    );
    final mmo = ref.watch(masterMediaObjectProvider(dna));
    final rmsBytes = mmo.modulationBus.masterRmsBytes;

    return Material(
      type: MaterialType.transparency,
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.88,
        decoration: BoxDecoration(
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
          child: SingleChildScrollView(
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
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      IconButton(
                        icon: const PhosphorIcon(
                          AppIcons.caretDown,
                          size: 28,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Text(
                        'Now Playing',
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Semantics(
                        label: _showLyrics ? 'Show artwork' : 'Show lyrics',
                        child: IconButton(
                          key: const Key('player_lyrics_toggle'),
                          style: IconButton.styleFrom(
                            shape: const CircleBorder(),
                          ),
                          icon: PhosphorIcon(
                            _showLyrics ? AppIcons.disc : AppIcons.mic,
                            size: 22,
                            color: _showLyrics ? accent : Colors.white,
                          ),
                          tooltip: _showLyrics ? 'Show artwork' : 'Show lyrics',
                          onPressed: () {
                            HapticsService().selectionClick();
                            setState(() {
                              _heroMode = (_heroMode == PlayerHeroMode.lyrics)
                                  ? PlayerHeroMode.artwork
                                  : PlayerHeroMode.lyrics;
                            });
                          },
                        ),
                      ),
                      IconButton(
                        style: IconButton.styleFrom(
                          shape: const CircleBorder(),
                        ),
                        icon: PhosphorIcon(
                          _isFavorite(ref, track.id)
                              ? AppIcons.heart
                              : AppIcons.heartOutline,
                          size: 22,
                          color: _isFavorite(ref, track.id)
                              ? AppColors.brandPrimary
                              : Colors.white,
                        ),
                        tooltip: _isFavorite(ref, track.id)
                            ? 'Remove from favourites'
                            : 'Add to favourites',
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          ref
                              .read(libraryTracksProvider.notifier)
                              .toggleFavorite(track.id);
                        },
                      ),
                      IconButton(
                        key: const Key('player_create_reel_btn'),
                        style: IconButton.styleFrom(
                          shape: const CircleBorder(),
                        ),
                        icon: const PhosphorIcon(
                          AppIcons.sparkle,
                          size: 22,
                          color: Colors.white,
                        ),
                        tooltip: 'Create 9:16 Lyric Reel',
                        onPressed: () => _openContentStudio(context, track),
                      ),
                      IconButton(
                        key: const Key('player_more_actions_btn'),
                        icon: const PhosphorIcon(
                          AppIcons.dotsHorizontal,
                          size: 24,
                          color: Colors.white,
                        ),
                        tooltip: 'More actions',
                        onPressed: () {
                          final libraryTrack = ref
                              .read(libraryTracksProvider)
                              .cast<LibraryTrack?>()
                              .firstWhere(
                                (t) => t?.id == track.id,
                                orElse: () => null,
                              );
                          if (libraryTrack != null) {
                            TrackActionsSheet.show(context, libraryTrack);
                          }
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // 3-Way Segmented Hero Mode Selector (REQ-P55-HERO-01)
                Container(
                  key: const Key('player_hero_mode_selector'),
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.darkSurfaceSecondary,
                    borderRadius: AppRadius.pillBorder,
                    border: Border.all(color: AppColors.darkBorderSubtle),
                  ),
                  child: Row(
                    children: [
                      for (final mode in PlayerHeroMode.values)
                        Expanded(
                          child: InkWell(
                            key: Key('player_hero_segment_${mode.name}'),
                            onTap: () {
                              HapticsService().selectionClick();
                              setState(() => _heroMode = mode);
                            },
                            borderRadius: AppRadius.pillBorder,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: _heroMode == mode
                                    ? accent.withValues(alpha: 0.22)
                                    : Colors.transparent,
                                borderRadius: AppRadius.pillBorder,
                                border: Border.all(
                                  color: _heroMode == mode
                                      ? accent
                                      : Colors.transparent,
                                ),
                              ),
                              child: Text(
                                mode.label,
                                textAlign: TextAlign.center,
                                style: AppTypography.badge.copyWith(
                                  color: _heroMode == mode
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                  fontWeight: _heroMode == mode
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Hero Artwork / 3D Biome / Lyrics surface (REQ-P55-HERO-01..02)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: switch (_heroMode) {
                    PlayerHeroMode.biome3d => PlayerLivingBiomeHeroViewport(
                      height: MediaQuery.sizeOf(context).height < 700
                          ? 220
                          : 270,
                    ),
                    PlayerHeroMode.lyrics => SizedBox(
                      height: MediaQuery.sizeOf(context).height < 700
                          ? 200
                          : 260,
                      child: _buildLyricsCard(context, ref, track, accent),
                    ),
                    PlayerHeroMode.artwork => Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).height < 700
                              ? 200
                              : 260,
                          maxHeight: MediaQuery.sizeOf(context).height < 700
                              ? 200
                              : 260,
                        ),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Hero(
                            tag: 'now_playing_art_${track.id}',
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: AppGradients.forGenre(track.genre),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withAlpha(80),
                                    blurRadius: 40,
                                    spreadRadius: -8,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: PhosphorIcon(
                                  AppIcons.piano,
                                  size: 72,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  },
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
                              style: AppTypography.titleLarge.copyWith(
                                fontSize: 22,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 2,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  track.creatorName,
                                  style: AppTypography.bodyMuted.copyWith(
                                    fontSize: 15,
                                  ),
                                ),
                                PhosphorIcon(
                                  AppIcons.verified,
                                  color: accent,
                                  size: 16,
                                ),
                                Text(
                                  '• ${track.genre}',
                                  style: AppTypography.caption,
                                ),
                                if (ref
                                    .watch(libraryTracksProvider)
                                    .any(
                                      (t) =>
                                          t.id == track.id &&
                                          t.isOfflineAvailable,
                                    ))
                                  const OfflineIndicatorBadge(isCompact: true),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Semantics(
                        label: _isFavorite(ref, track.id)
                            ? 'Remove from favourites'
                            : 'Add to favourites',
                        child: IconButton(
                          key: const Key('player_meta_favorite_btn'),
                          icon: PhosphorIcon(
                            _isFavorite(ref, track.id)
                                ? AppIcons.heart
                                : AppIcons.heartOutline,
                            color: _isFavorite(ref, track.id)
                                ? accent
                                : AppColors.textSecondary,
                            size: 26,
                          ),
                          tooltip: _isFavorite(ref, track.id)
                              ? 'Remove from favourites'
                              : 'Add to favourites',
                          onPressed: () {
                            HapticsService().selectionClick();
                            ref
                                .read(libraryTracksProvider.notifier)
                                .toggleFavorite(track.id);
                          },
                        ),
                      ),
                      IconButton(
                        key: const Key('player_meta_share_btn'),
                        icon: PhosphorIcon(
                          AppIcons.share,
                          color: AppColors.textSecondary,
                          size: 22,
                        ),
                        tooltip: 'Share Track',
                        onPressed: () async {
                          await _handleShare(context, track);
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Waveform Scrubber with 60 Hz masterRmsBytes Visualizer
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      GestureDetector(
                        key: const Key('cockpit_waveform_scrubber'),
                        onHorizontalDragUpdate: (details) {
                          final box = context.findRenderObject() as RenderBox?;
                          if (box != null) {
                            final ratio =
                                (details.localPosition.dx / box.size.width)
                                    .clamp(0.0, 1.0);
                            notifier.seekByRatio(ratio);
                          }
                        },
                        child: Container(
                          height: 44,
                          alignment: Alignment.center,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: List.generate(60, (index) {
                              final barRatio = index / 60.0;
                              final isElapsed =
                                  barRatio <= playerState.progressRatio;

                              double amplitude = 0.35;
                              if (rmsBytes.isNotEmpty) {
                                final sampleIndex =
                                    (barRatio * (rmsBytes.length - 1))
                                        .toInt()
                                        .clamp(0, rmsBytes.length - 1);
                                amplitude = (rmsBytes[sampleIndex] / 255.0)
                                    .clamp(0.15, 1.0);
                              } else {
                                amplitude = 0.2 + ((index % 6) * 0.12);
                              }

                              final barHeight = 8.0 + (amplitude * 34.0);

                              return Expanded(
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 1.0,
                                  ),
                                  height: barHeight,
                                  decoration: BoxDecoration(
                                    color: isElapsed
                                        ? accent
                                        : AppColors.borderSubtle,
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
                          Text(
                            playerState.formattedPosition,
                            style: AppTypography.caption,
                          ),
                          Text(
                            playerState.formattedDuration,
                            style: AppTypography.caption,
                          ),
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
                      Semantics(
                        label: playerState.isShuffle
                            ? 'Shuffle on'
                            : 'Shuffle off',
                        child: IconButton(
                          icon: Icon(
                            AppIcons.shuffle,
                            color: playerState.isShuffle
                                ? accent
                                : AppColors.textSecondary,
                            size: 24,
                          ),
                          onPressed: () {
                            HapticsService().selectionClick();
                            notifier.toggleShuffle();
                          },
                        ),
                      ),
                      Semantics(
                        label: 'Skip previous track',
                        child: IconButton(
                          icon: const PhosphorIcon(
                            AppIcons.skipBack,
                            size: 36,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            HapticsService().lightImpact();
                            notifier.skipPrevious();
                          },
                        ),
                      ),
                      // Primary 64x64px Play/Pause Orb
                      Semantics(
                        label: playerState.isPlaying ? 'Pause' : 'Play',
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: accent.withAlpha(100),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: Icon(
                              playerState.isPlaying
                                  ? AppIcons.pause
                                  : AppIcons.play,
                              size: 36,
                              color: _contrastTextColor(accent),
                            ),
                            onPressed: () {
                              HapticsService().mediumImpact();
                              notifier.togglePlayPause();
                            },
                          ),
                        ),
                      ),
                      Semantics(
                        label: 'Skip next track',
                        child: IconButton(
                          icon: const PhosphorIcon(
                            AppIcons.skipForward,
                            size: 36,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            HapticsService().lightImpact();
                            notifier.skipNext();
                          },
                        ),
                      ),
                      Semantics(
                        label: playerState.repeatMode == AudioRepeatMode.one
                            ? 'Repeat one'
                            : playerState.repeatMode == AudioRepeatMode.all
                            ? 'Repeat all'
                            : 'Repeat off',
                        child: IconButton(
                          icon: Icon(
                            playerState.repeatMode == AudioRepeatMode.one
                                ? AppIcons.repeat
                                : AppIcons.repeat,
                            color: playerState.repeatMode != AudioRepeatMode.off
                                ? accent
                                : AppColors.textTertiary,
                            size: 24,
                          ),
                          onPressed: () {
                            HapticsService().selectionClick();
                            notifier.cycleRepeatMode();
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Track Utility Tray
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    borderRadius: AppRadius.pillBorder,
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    alignment: WrapAlignment.center,
                    children: [
                      _UtilityItem(
                        key: const Key('player_lyrics_btn'),
                        icon: _showLyrics ? AppIcons.disc : AppIcons.mic,
                        label: _showLyrics ? 'Artwork' : 'Lyrics',
                        onTap: () => setState(() {
                          _heroMode = (_heroMode == PlayerHeroMode.lyrics)
                              ? PlayerHeroMode.artwork
                              : PlayerHeroMode.lyrics;
                        }),
                      ),
                      _UtilityItem(
                        key: const Key('player_biome_btn'),
                        icon: AppIcons.dna,
                        label: '3D DNA',
                        onTap: () {
                          HapticsService().selectionClick();
                          setState(() => _heroMode = PlayerHeroMode.biome3d);
                        },
                      ),
                      _UtilityItem(
                        key: const Key('player_stems_btn'),
                        icon: AppIcons.beatstore,
                        label: 'Stems',
                        onTap: () {
                          HapticsService().selectionClick();
                          showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => Container(
                              height: MediaQuery.sizeOf(context).height * 0.85,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceModal,
                                borderRadius: AppRadius.modalBorder,
                              ),
                              child: SafeArea(
                                top: false,
                                child: StemMixerDeck(
                                  title: track.title,
                                  masterUrl: track.audioUrl,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      _UtilityItem(
                        key: const Key('player_track_info_btn'),
                        icon: AppIcons.info,
                        label: 'Details',
                        onTap: () {
                          final libraryTrack = ref
                              .read(libraryTracksProvider)
                              .cast<LibraryTrack?>()
                              .firstWhere(
                                (t) => t?.id == track.id,
                                orElse: () => null,
                              );
                          if (libraryTrack != null) {
                            TrackDetailsModal.show(context, libraryTrack);
                          }
                        },
                      ),
                      _UtilityItem(
                        key: const Key('player_export_btn'),
                        icon: AppIcons.sparkle,
                        label: 'Export Reel',
                        onTap: () => _openContentStudio(context, track),
                      ),
                      _UtilityItem(
                        key: const Key('player_mux_btn'),
                        icon: AppIcons.lightning,
                        label: 'Native Muxer',
                        onTap: () => VideoExportModal.show(
                          context,
                          job: VideoExportJob(
                            id: 'job_${track.id}',
                            title: track.title,
                            creatorHandle: '@${track.creatorName}',
                            genre: track.genre,
                            audioPath: track.audioUrl ?? '',
                          ),
                        ),
                      ),
                      _UtilityItem(
                        icon: AppIcons.playlist,
                        label: 'Queue',
                        onTap: () => QueueDrawer.show(context),
                      ),
                      // 1-Tap Master A/B Auditioning Chip with LED indicator (Phase 25 & Phase 42)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildHardwareDspLed(context, isMasteredActive),
                          const SizedBox(height: 2),
                          _UtilityItem(
                            key: const Key('cockpit_master_ab_btn'),
                            icon: AppIcons.mastering,
                            label: isMasteredActive ? 'Mastered' : 'Raw AI',
                            onTap: _toggleMasterAB,
                          ),
                        ],
                      ),
                      // Studio Remixing Preset Chip (Phase 21/27 & Phase 42)
                      _UtilityItem(
                        key: const Key('cockpit_remix_in_studio_btn'),
                        icon: AppIcons.remix,
                        label: 'Remix',
                        onTap: () => _remixInStudio(context, track),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the scrollable Lyrics reading card shown when [_showLyrics] is on.
  ///
  /// Resolves the active track's vault record for its bracketed stanza text;
  /// falls back to a friendly empty state when none is attached.
  Widget _buildLyricsCard(
    BuildContext context,
    WidgetRef ref,
    Track track,
    Color accent,
  ) {
    final lyrics = ref
        .read(libraryTracksProvider)
        .cast<LibraryTrack?>()
        .firstWhere((t) => t?.id == track.id, orElse: () => null)
        ?.lyrics;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card header + Copy action
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                PhosphorIcon(AppIcons.mic, size: 18, color: accent),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Lyrics',
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (lyrics != null && lyrics.trim().isNotEmpty)
                  IconButton(
                    key: const Key('cockpit_copy_lyrics'),
                    tooltip: 'Copy lyrics',
                    icon: PhosphorIcon(
                      AppIcons.edit,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () {
                      HapticsService().mediumImpact();
                      Clipboard.setData(ClipboardData(text: lyrics));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.surfaceModal,
                          content: Text(
                            'Lyrics copied to clipboard',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.borderSubtle),
          Expanded(
            child: (lyrics == null || lyrics.trim().isEmpty)
                ? _LyricsEmptyState()
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: _buildLyricsBody(lyrics, accent),
                  ),
          ),
        ],
      ),
    );
  }

  /// Renders bracketed stanza headers (`[Chorus]`) in bold brand color and
  /// lyric lines in [AppTypography.bodyLarge], preserving blank-line spacing.
  Widget _buildLyricsBody(String lyrics, Color accent) {
    final widgets = <Widget>[];
    for (final line in lyrics.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: AppSpacing.sm));
        continue;
      }
      final isHeader = trimmed.startsWith('[') && trimmed.endsWith(']');
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
          child: Text(
            trimmed,
            style: isHeader
                ? AppTypography.bodyLarge.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  )
                : AppTypography.bodyLarge.copyWith(
                    color: AppColors.textPrimary,
                  ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  void _openContentStudio(BuildContext context, Track track) {
    final libraryTrack = ref
        .read(libraryTracksProvider)
        .cast<LibraryTrack?>()
        .firstWhere((t) => t?.id == track.id, orElse: () => null);
    final dna =
        libraryTrack?.toSongMetadataDna() ??
        SongMetadataDna.fromTrackInfo(
          id: track.id,
          title: track.title,
          genre: track.genre,
          language: track.language,
          durationSec: track.duration.inSeconds,
          lyrics: libraryTrack?.lyrics,
          coverUrl: track.coverUrl,
        );
    ContentStudioDockView.open(
      context,
      dna: dna,
      audioUrl: track.audioUrl ?? 'https://r2.vhunambi.com/audio/default.mp3',
      coverArtUrl:
          track.coverUrl ?? 'https://r2.vhunambi.com/visuals/default_9_16.png',
    );
  }

  /// Shares the track via the system share sheet (VH-016).
  Future<void> _handleShare(BuildContext context, Track track) async {
    await Share.share(
      'Check out "${track.title}" by ${track.creatorName} on Vhunambi!\nhttps://vhunambi.com/track/${track.id}',
      subject: track.title,
    );
  }

  Widget _buildHardwareDspLed(BuildContext context, bool isMasteredActive) {
    return Container(
      key: const Key('cockpit_dsp_led_indicator'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isMasteredActive
            ? AppColors.accentSuccess.withValues(alpha: 0.15)
            : AppColors.surfaceSecondaryOf(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isMasteredActive
              ? AppColors.accentSuccess
              : AppColors.borderSubtleOf(context),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isMasteredActive
                  ? AppColors.accentSuccess
                  : AppColors.textSecondaryOf(context),
              boxShadow: isMasteredActive
                  ? [
                      BoxShadow(
                        color: AppColors.accentSuccess.withValues(alpha: 0.8),
                        blurRadius: 4,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            isMasteredActive ? 'DSP' : 'RAW',
            style: AppTypography.caption.copyWith(
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
              color: isMasteredActive
                  ? AppColors.accentSuccess
                  : AppColors.textSecondaryOf(context),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleMasterAB() {
    ref.read(masteringSessionProvider.notifier).togglePreviewBypass();
    HapticsService().mediumImpact();
  }

  void _remixInStudio(BuildContext context, Track track) {
    ref.read(studioFormProvider.notifier).setGenre(track.genre);
    ref
        .read(studioFormProvider.notifier)
        .updatePrompt('Remix of ${track.title} (${track.genre})');

    // Phase 42: Switch active RootShell tab to Studio Cockpit (Tab index 2)
    ref.read(appNavigationTabProvider.notifier).state = 2;

    ref
        .read(notificationsProvider.notifier)
        .addNotification(
          NotificationEntity(
            id: 'notif_remix_${DateTime.now().millisecondsSinceEpoch}',
            title: 'Studio Remix Loaded',
            message: 'Loaded "${track.title}" stems into Studio Cockpit.',
            category: NotificationCategory.creatorActivity,
            priority: NotificationPriority.high,
            createdAt: DateTime.now(),
          ),
        );

    Navigator.of(context).pop();
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

class _LyricsEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PhosphorIcon(AppIcons.songs, size: 48, color: AppColors.textTertiary),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No written lyrics for this track',
            style: AppTypography.bodyMuted,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _UtilityItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _UtilityItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticsService().selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            PhosphorIcon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
