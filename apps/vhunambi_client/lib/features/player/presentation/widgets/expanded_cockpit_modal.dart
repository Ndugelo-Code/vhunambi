import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/song_metadata_dna.dart';
import 'package:vhunambi_client/features/content_studio/domain/utils/lyric_karaoke_sanitizer.dart';
import 'package:vhunambi_client/features/content_studio/presentation/views/kinetic_reel_studio_view.dart';
import 'package:vhunambi_client/features/track/domain/models/track_detail_models.dart';
import 'package:vhunambi_client/features/track/presentation/providers/track_providers.dart';
import 'package:vhunambi_client/features/track/presentation/views/track_detail_view.dart';
import 'package:vhunambi_client/features/track/presentation/widgets/lyrics_teleprompter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/design_system/services/haptics_service.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/navigation/profile_navigation_helper.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/creator_id_utils.dart';
import '../../../../core/widgets/vhunambi_track_artwork.dart';
import '../../../../shared/models/track.dart';
import '../../../content_studio/presentation/providers/master_media_object_provider.dart';
import '../../../library/domain/models/library_models.dart';
import '../../../library/presentation/providers/library_providers.dart';
import '../../../library/presentation/widgets/track_actions_sheet.dart';
import '../../../library/presentation/widgets/track_details_modal.dart';
import '../../../mastering/presentation/providers/mastering_session_provider.dart';
import '../../../notifications/domain/models/notification_entity.dart';
import '../../../notifications/domain/models/notification_enums.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../../offline/presentation/widgets/offline_indicator_badge.dart';
import '../../../profile/presentation/views/artist_profile_view.dart';
import '../../../profile/presentation/views/owner_profile_view.dart';
import '../../../social/domain/models/video_export_job.dart';
import '../../../social/presentation/widgets/video_export_modal.dart';
import '../../../studio/presentation/providers/studio_form_provider.dart';
import '../../domain/models/player_state.dart';
import '../providers/mini_player_controller.dart';
import '../providers/player_provider.dart';
import 'player_chromatic_resolver_mixin.dart';
import 'queue_drawer.dart';
import 'stem_mixer_deck.dart';

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
    // Allow morphing between the 88% docked sheet (artwork) and true full screen (lyrics).
    showGeneralDialog(
      context: navContext,
      useRootNavigator: false,
      barrierDismissible: true,
      barrierLabel: 'Dismiss now playing',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 340),
      pageBuilder: (context, _, _) => const Align(
        alignment: Alignment.bottomCenter,
        child: ExpandedCockpitModal(),
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

class _ExpandedCockpitModalState extends ConsumerState<ExpandedCockpitModal>
    with PlayerChromaticPaletteMixin<ExpandedCockpitModal> {
  static const double _dismissDragThresholdPx = 120.0;
  static const double _dismissVelocityThreshold = 500.0;

  bool _showLyrics = false;
  bool _toolsExpanded = false;
  double _dragOffsetY = 0.0;
  bool _isVerticalDragging = false;
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

  void _dismissSheet(BuildContext context) {
    final nav = Navigator.maybeOf(context);
    if (nav != null && nav.canPop()) {
      nav.pop();
    } else if (mounted) {
      setState(() {
        _isVerticalDragging = false;
        _dragOffsetY = 0.0;
      });
    }
  }

  void _handleVerticalDragStart(DragStartDetails details) {
    setState(() => _isVerticalDragging = true);
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    final next = (_dragOffsetY + details.delta.dy).clamp(0.0, 600.0);
    setState(() {
      _isVerticalDragging = true;
      _dragOffsetY = next;
    });
  }

  void _handleVerticalDragEnd(BuildContext context, DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0.0;
    if (_dragOffsetY >= _dismissDragThresholdPx ||
        velocity > _dismissVelocityThreshold) {
      HapticsService().lightImpact();
      _dismissSheet(context);
      return;
    }
    setState(() {
      _isVerticalDragging = false;
      _dragOffsetY = 0.0;
    });
  }

  void _handleVerticalDragCancel() {
    setState(() {
      _isVerticalDragging = false;
      _dragOffsetY = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerStateProvider);
    final track = playerState.currentTrack;

    if (track == null) {
      return const SizedBox.shrink();
    }

    final notifier = ref.read(playerStateProvider.notifier);
    final palette = resolvePlayerChromaticPalette(context, track);
    final accent = palette.accent;
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final borderSubtle = AppColors.borderSubtleOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMasteredActive = ref
        .watch(masteringSessionProvider)
        .isMasteredPreviewActive;

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
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Material(
      type: MaterialType.transparency,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxAvailableHeight = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : screenHeight;
          final targetHeight = _showLyrics
              ? maxAvailableHeight
              : math.min(maxAvailableHeight, screenHeight * 0.88);
          final dragRadius = _showLyrics && _dragOffsetY <= 1
              ? BorderRadius.zero
              : AppRadius.modalBorder;

          return AnimatedContainer(
            key: const Key('cockpit_chromatic_backdrop'),
            duration: _isVerticalDragging
                ? Duration.zero
                : const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: targetHeight,
            transform: Matrix4.translationValues(0.0, _dragOffsetY, 0.0),
            decoration: buildChromaticStageDecoration(
              context: context,
              palette: palette,
              baseSurface: AppColors.surfaceModalOf(context),
              borderRadius: dragRadius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.54 : 0.16),
                  blurRadius: 30,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: SafeArea(
              top: _showLyrics,
              bottom: true,
              child: Column(
                children: [
                  _buildTopChrome(
                    context: context,
                    track: track,
                    accent: accent,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    borderSubtle: borderSubtle,
                  ),
                  Expanded(
                    child: _showLyrics
                        ? _buildFullScreenLyricsSurface(
                            context,
                            ref,
                            track,
                            accent,
                          )
                        : _buildArtworkCockpitBody(
                            context: context,
                            track: track,
                            playerState: playerState,
                            notifier: notifier,
                            palette: palette,
                            accent: accent,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            borderSubtle: borderSubtle,
                            isDark: isDark,
                            isMasteredActive: isMasteredActive,
                            rmsBytes: rmsBytes,
                            screenHeight: screenHeight,
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopChrome({
    required BuildContext context,
    required Track track,
    required Color accent,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderSubtle,
  }) {
    final libraryTrack = _findLibraryTrack(track.id);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragStart: _handleVerticalDragStart,
      onVerticalDragUpdate: _handleVerticalDragUpdate,
      onVerticalDragEnd: (details) => _handleVerticalDragEnd(context, details),
      onVerticalDragCancel: _handleVerticalDragCancel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            key: const Key('cockpit_drag_handle'),
            behavior: HitTestBehavior.opaque,
            onVerticalDragStart: _handleVerticalDragStart,
            onVerticalDragUpdate: _handleVerticalDragUpdate,
            onVerticalDragEnd: (details) =>
                _handleVerticalDragEnd(context, details),
            onVerticalDragCancel: _handleVerticalDragCancel,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: borderSubtle,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
            child: Row(
              children: [
                IconButton(
                  key: const Key('player_dismiss_btn'),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  icon: PhosphorIcon(
                    AppIcons.caretDown,
                    size: 26,
                    color: textPrimary,
                  ),
                  tooltip: 'Minimize player',
                  onPressed: () => _dismissSheet(context),
                ),
                Expanded(
                  child: Text(
                    'Now Playing',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppTypography.titleMedium.copyWith(
                      color: textSecondary,
                    ),
                  ),
                ),
                Semantics(
                  label: _showLyrics ? 'Show artwork' : 'Show lyrics',
                  child: IconButton(
                    key: const Key('player_lyrics_toggle'),
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    style: IconButton.styleFrom(
                      shape: const CircleBorder(),
                      backgroundColor: _showLyrics
                          ? accent.withValues(alpha: 0.16)
                          : Colors.transparent,
                    ),
                    icon: PhosphorIcon(
                      _showLyrics ? AppIcons.disc : AppIcons.mic,
                      size: 21,
                      color: _showLyrics ? accent : textPrimary,
                    ),
                    tooltip: _showLyrics ? 'Show artwork' : 'Show lyrics',
                    onPressed: () {
                      HapticsService().selectionClick();
                      setState(() => _showLyrics = !_showLyrics);
                    },
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  style: IconButton.styleFrom(shape: const CircleBorder()),
                  icon: PhosphorIcon(
                    _isFavorite(ref, track.id)
                        ? AppIcons.heart
                        : AppIcons.heartOutline,
                    size: 21,
                    color: _isFavorite(ref, track.id)
                        ? AppColors.brandPrimary
                        : textPrimary,
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
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  style: IconButton.styleFrom(shape: const CircleBorder()),
                  icon: PhosphorIcon(
                    AppIcons.sparkle,
                    size: 21,
                    color: textPrimary,
                  ),
                  tooltip: 'Create 9:16 Lyric Reel',
                  onPressed: () => _openContentStudio(context, track),
                ),
                IconButton(
                  key: const Key('player_more_actions_btn'),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  icon: PhosphorIcon(
                    AppIcons.dotsHorizontal,
                    size: 22,
                    color: textPrimary,
                  ),
                  tooltip: 'More actions',
                  onPressed: () {
                    if (libraryTrack != null) {
                      TrackActionsSheet.show(context, libraryTrack);
                    } else {
                      _openTrackDetails(context, track);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtworkCockpitBody({
    required BuildContext context,
    required Track track,
    required PlayerState playerState,
    required PlayerNotifier notifier,
    required dynamic palette,
    required Color accent,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderSubtle,
    required bool isDark,
    required bool isMasteredActive,
    required List<int> rmsBytes,
    required double screenHeight,
  }) {
    final artSize = screenHeight < 700 ? 196.0 : 248.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        key: const Key('cockpit_playback_section'),
        children: [
          const SizedBox(height: 8),

          // Swipe-to-dismiss enabled Hero Artwork
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragStart: _handleVerticalDragStart,
            onVerticalDragUpdate: _handleVerticalDragUpdate,
            onVerticalDragEnd: (details) =>
                _handleVerticalDragEnd(context, details),
            onVerticalDragCancel: _handleVerticalDragCancel,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: artSize,
                    maxHeight: artSize,
                  ),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Hero(
                      tag: 'now_playing_art_${track.id}',
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: (palette.primaryGlow as Color).withValues(
                                alpha: isDark ? 0.36 : 0.22,
                              ),
                              blurRadius: 36,
                              spreadRadius: -6,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: VhunambiTrackArtwork(
                          key: const Key('cockpit_hero_artwork'),
                          coverUrl: track.coverUrl,
                          genre: track.genre,
                          trackId: track.id,
                          borderRadius: BorderRadius.circular(24),
                          badgeIconSize: 56,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 22),

          // Track Info Row (Clickable Song Title -> TrackDetailView, Clickable Artist -> Creator Profile)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        key: const Key('player_track_title_tap'),
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _openTrackDetails(context, track),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  track.title,
                                  style: AppTypography.titleLarge.copyWith(
                                    fontSize: 22,
                                    color: textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              PhosphorIcon(
                                AppIcons.caretRight,
                                size: 16,
                                color: textSecondary.withValues(alpha: 0.72),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          InkWell(
                            key: const Key('player_artist_name_tap'),
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => _openCreatorProfile(context, track),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    track.creatorName,
                                    style: AppTypography.bodyMuted.copyWith(
                                      fontSize: 15,
                                      color: textSecondary,
                                      decoration: TextDecoration.underline,
                                      decorationColor: accent.withValues(
                                        alpha: 0.45,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  PhosphorIcon(
                                    AppIcons.verified,
                                    color: accent,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Text(
                            '• ${track.genre}',
                            style: AppTypography.caption.copyWith(
                              color: textSecondary,
                            ),
                          ),
                          if (ref
                              .watch(libraryTracksProvider)
                              .any(
                                (t) =>
                                    t.id == track.id && t.isOfflineAvailable,
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
                          : textSecondary,
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
                    color: textSecondary,
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

          const SizedBox(height: 18),

          // Waveform Scrubber with 60 Hz masterRmsBytes Visualizer + exact LayoutBuilder seek
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth <= 0
                        ? 1.0
                        : constraints.maxWidth;
                    return GestureDetector(
                      key: const Key('cockpit_waveform_scrubber'),
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) {
                        final ratio = (details.localPosition.dx / width).clamp(
                          0.0,
                          1.0,
                        );
                        notifier.seekByRatio(ratio);
                      },
                      onHorizontalDragUpdate: (details) {
                        final ratio = (details.localPosition.dx / width).clamp(
                          0.0,
                          1.0,
                        );
                        notifier.seekByRatio(ratio);
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
                              amplitude = (rmsBytes[sampleIndex] / 255.0).clamp(
                                0.15,
                                1.0,
                              );
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
                                  color: isElapsed ? accent : borderSubtle,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      playerState.formattedPosition,
                      style: AppTypography.caption.copyWith(
                        color: textSecondary,
                      ),
                    ),
                    Text(
                      playerState.formattedDuration,
                      style: AppTypography.caption.copyWith(
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // DAW Transport Control Deck
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Semantics(
                  label: playerState.isShuffle ? 'Shuffle on' : 'Shuffle off',
                  child: IconButton(
                    icon: PhosphorIcon(
                      AppIcons.shuffle,
                      color: playerState.isShuffle ? accent : textSecondary,
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
                    icon: PhosphorIcon(
                      AppIcons.skipBack,
                      size: 36,
                      color: textPrimary,
                    ),
                    onPressed: () {
                      HapticsService().lightImpact();
                      notifier.skipPrevious();
                    },
                  ),
                ),
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
                      icon: PhosphorIcon(
                        playerState.isPlaying
                            ? AppIcons.pause
                            : AppIcons.play,
                        size: 36,
                        color: palette.onAccent as Color,
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
                    icon: PhosphorIcon(
                      AppIcons.skipForward,
                      size: 36,
                      color: textPrimary,
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
                    icon: PhosphorIcon(
                      AppIcons.repeat,
                      color: playerState.repeatMode != AudioRepeatMode.off
                          ? accent
                          : textSecondary.withValues(alpha: 0.72),
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

          const SizedBox(height: 18),

          // Collapsible Secondary Track Tools Tray (Collapsed by default)
          _buildCollapsibleToolsTray(
            context: context,
            track: track,
            accent: accent,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            borderSubtle: borderSubtle,
            isMasteredActive: isMasteredActive,
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsibleToolsTray({
    required BuildContext context,
    required Track track,
    required Color accent,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderSubtle,
    required bool isMasteredActive,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondaryOf(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderSubtle),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            key: const Key('cockpit_tools_toggle'),
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              HapticsService().selectionClick();
              setState(() => _toolsExpanded = !_toolsExpanded);
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    PhosphorIcon(
                      PhosphorIconsRegular.slidersHorizontal,
                      size: 16,
                      color: _toolsExpanded ? accent : textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _toolsExpanded ? 'Hide Track Tools' : 'Track Tools',
                        style: AppTypography.caption.copyWith(
                          color: textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _buildHardwareDspLed(context, isMasteredActive),
                    const SizedBox(width: 8),
                    PhosphorIcon(
                      _toolsExpanded ? AppIcons.caretUp : AppIcons.caretDown,
                      size: 16,
                      color: textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_toolsExpanded) ...[
            Divider(height: 1, color: borderSubtle),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                alignment: WrapAlignment.center,
                children: [
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
                            color: AppColors.surfaceModalOf(context),
                            borderRadius: AppRadius.modalBorder,
                          ),
                          child: SafeArea(
                            top: false,
                            child: StemMixerDeck(
                              title: track.title,
                              masterUrl: track.audioUrl,
                              stemUrls: track.stemUrls,
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
                      final libraryTrack = _findLibraryTrack(track.id);
                      if (libraryTrack != null) {
                        TrackDetailsModal.show(context, libraryTrack);
                      } else {
                        _openTrackDetails(context, track);
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
                    key: const Key('player_queue_btn'),
                    icon: AppIcons.playlist,
                    label: 'Queue',
                    onTap: () => QueueDrawer.show(context),
                  ),
                  _UtilityItem(
                    key: const Key('cockpit_master_ab_btn'),
                    icon: AppIcons.mastering,
                    label: isMasteredActive ? 'Mastered' : 'Raw AI',
                    onTap: _toggleMasterAB,
                  ),
                  _UtilityItem(
                    key: const Key('cockpit_remix_in_studio_btn'),
                    icon: AppIcons.remix,
                    label: 'Remix',
                    onTap: () => _remixInStudio(context, track),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Full-screen distraction-free Synced Karaoke Lyrics surface (`_showLyrics == true`).
  Widget _buildFullScreenLyricsSurface(
    BuildContext context,
    WidgetRef ref,
    Track track,
    Color accent,
  ) {
    final libraryTrack = _findLibraryTrack(track.id);
    final detailTrack = ref.watch(trackDetailFamilyProvider(track.id));
    final rawLyrics = (libraryTrack?.lyrics?.trim().isNotEmpty ?? false)
        ? libraryTrack!.lyrics!
        : detailTrack.lyrics;
    final cleanLyrics = LyricKaraokeSanitizer.cleanLyricsForTeleprompter(
      rawLyrics,
    );
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final borderSubtle = AppColors.borderSubtleOf(context);

    final resolvedEntity = TrackDetailEntity(
      id: track.id,
      title: track.title,
      genre: track.genre,
      language: libraryTrack?.language ?? track.language,
      duration: track.duration,
      creatorId: libraryTrack?.creatorId ?? detailTrack.creatorId,
      creatorName: track.creatorName,
      creatorHandle: track.handleLabel,
      lyrics: rawLyrics,
      coverUrl: track.coverUrl,
      audioUrl: track.audioUrl,
      moodId: track.mood ?? detailTrack.moodId,
    );

    return Container(
      key: const Key('cockpit_lyrics_surface'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: [
                PhosphorIcon(AppIcons.mic, size: 18, color: accent),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMedium.copyWith(
                          color: textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${track.creatorName} • Synced Lyrics',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (cleanLyrics.trim().isNotEmpty)
                  IconButton(
                    key: const Key('cockpit_copy_lyrics'),
                    tooltip: 'Copy clean lyrics',
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    icon: PhosphorIcon(
                      PhosphorIconsRegular.copy,
                      size: 18,
                      color: textSecondary,
                    ),
                    onPressed: () {
                      HapticsService().mediumImpact();
                      Clipboard.setData(ClipboardData(text: cleanLyrics));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.surfaceModalOf(context),
                          content: Text(
                            'Lyrics copied to clipboard',
                            style: AppTypography.bodySmall.copyWith(
                              color: textPrimary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: borderSubtle),
          Expanded(
            child: cleanLyrics.trim().isEmpty
                ? _LyricsEmptyState()
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: AppSpacing.md,
                    ),
                    child: LyricsTeleprompter(
                      track: resolvedEntity,
                      accentColorOverride: accent,
                      embeddedInPlayer: true,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  LibraryTrack? _findLibraryTrack(String trackId) {
    return ref
        .read(libraryTracksProvider)
        .cast<LibraryTrack?>()
        .firstWhere((t) => t?.id == trackId, orElse: () => null);
  }

  void _openTrackDetails(BuildContext context, Track track) {
    HapticsService().selectionClick();
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    }
    nav.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TrackDetailView(trackId: track.id),
      ),
    );
  }

  void _openCreatorProfile(BuildContext context, Track track) {
    HapticsService().selectionClick();
    final libraryTrack = _findLibraryTrack(track.id);
    final detailTrack = ref.read(trackDetailFamilyProvider(track.id));
    final fallbackCreatorId = canonicalizeCreatorId(
      (track.creatorHandle != null && track.creatorHandle!.isNotEmpty)
          ? track.creatorHandle
          : track.creatorName,
    );
    final rawCreatorId = (libraryTrack?.creatorId?.trim().isNotEmpty ?? false)
        ? libraryTrack!.creatorId!
        : (detailTrack.creatorName == track.creatorName &&
                  detailTrack.creatorId.trim().isNotEmpty
              ? detailTrack.creatorId
              : fallbackCreatorId);
    final creatorHandle =
        libraryTrack?.creatorHandle ?? track.creatorHandle ?? track.handleLabel;
    final isOwner = isOwnedByActiveUser(
      ref,
      creatorId: rawCreatorId,
      creatorHandle: creatorHandle,
    );
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    }
    nav.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => isOwner
            ? const OwnerProfileView()
            : ArtistProfileView(artistId: rawCreatorId),
      ),
    );
  }

  void _openContentStudio(BuildContext context, Track track) {
    final libraryTrack = _findLibraryTrack(track.id);
    final rawAudio = libraryTrack?.remoteAudioUrl ?? track.audioUrl ?? '';
    final resolvedAudio = rawAudio.isNotEmpty
        ? AppConstants.normalizeCloudMediaUrl(rawAudio)
        : '${AppConstants.resolveMediaBaseUrl()}/audio/${track.id}.mp3';
    final rawCover = libraryTrack?.coverImageUrl ?? track.coverUrl;
    final resolvedCover = (rawCover != null && rawCover.isNotEmpty)
        ? AppConstants.normalizeCloudMediaUrl(rawCover)
        : null;
    final resolvedTrack =
        libraryTrack ??
        LibraryTrack(
          id: track.id,
          title: track.title,
          creatorName: track.creatorName,
          creatorHandle: track.creatorHandle,
          genre: track.genre,
          language: track.language,
          durationSeconds: track.duration.inSeconds,
          remoteAudioUrl: resolvedAudio,
          coverImageUrl: resolvedCover,
          createdAt: DateTime.now(),
        );
    KineticReelStudioView.show(context, initialTrack: resolvedTrack);
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
    final libraryTrack = _findLibraryTrack(track.id);
    final detailTrack = ref.read(trackDetailFamilyProvider(track.id));
    final resolvedLyrics = (libraryTrack?.lyrics?.trim().isNotEmpty ?? false)
        ? libraryTrack!.lyrics!
        : (detailTrack.id == track.id ? detailTrack.lyrics : null);
    final refAudio = (libraryTrack?.remoteAudioUrl.trim().isNotEmpty ?? false)
        ? libraryTrack!.remoteAudioUrl
        : track.audioUrl;

    final studioNotifier = ref.read(studioFormProvider.notifier);
    studioNotifier.applyPastTrackRemix(
      trackId: track.id,
      title: track.title,
      genre: track.genre,
      region: ref.read(studioFormProvider).region,
      language: libraryTrack?.language ?? track.language,
      referenceAudioPath: refAudio,
      lyrics: resolvedLyrics,
      isInstrumental: libraryTrack?.isInstrumental ?? false,
    );
    // Preserve unquoted title phrasing expected by Phase 33 & Phase 42 cockpit bridge tests.
    studioNotifier.updatePrompt(
      'Remix of ${track.title} (${track.genre}) — Studio V6 Harmonic Remix',
    );

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

    _dismissSheet(context);
  }
}

class _LyricsEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final textSecondary = AppColors.textSecondaryOf(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PhosphorIcon(
            AppIcons.songs,
            size: 48,
            color: textSecondary.withValues(alpha: 0.72),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No written lyrics for this track',
            style: AppTypography.bodyMuted.copyWith(color: textSecondary),
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
    final borderSubtle = AppColors.borderSubtleOf(context);
    return InkWell(
      onTap: () {
        HapticsService().selectionClick();
        onTap();
      },
      borderRadius: AppRadius.pillBorder,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevatedOf(context),
            borderRadius: AppRadius.pillBorder,
            border: Border.all(color: borderSubtle),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PhosphorIcon(
                icon,
                size: 16,
                color: AppColors.textSecondaryOf(context),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textPrimaryOf(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
