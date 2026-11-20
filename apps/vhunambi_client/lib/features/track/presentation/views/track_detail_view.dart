import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import '../../../playlists/presentation/widgets/add_to_playlist_sheet.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/auth/auth_providers.dart';
import '../../../../core/auth/viewer_role.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../core/widgets/vhunambi_ambient_mesh_backdrop.dart';
import '../../../../core/widgets/vhunambi_top_bar_kit.dart';
import '../../../../shared/models/track.dart';
import '../../../collections/domain/models/collection_entity.dart';
import '../../../collections/presentation/providers/collections_provider.dart';
import '../../../library/domain/models/library_models.dart';
import '../../../mastering/presentation/providers/mastering_session_provider.dart';
import '../../../mastering/presentation/views/desktop_mastering_studio_view.dart';
import '../../../mastering/presentation/widgets/mobile_quick_master_sheet.dart';
import '../../../offline/domain/models/offline_models.dart';
import '../../../offline/presentation/providers/offline_providers.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../player/presentation/widgets/stem_mixer_deck.dart';
import '../../../profile/presentation/views/artist_profile_view.dart';
import '../../../social/domain/models/video_export_job.dart';
import '../../../social/presentation/providers/creator_wallet_provider.dart';
import '../../../social/presentation/providers/reels_comments_provider.dart';
import '../../../social/presentation/widgets/threaded_comments_section.dart';
import '../../../social/presentation/widgets/video_export_modal.dart';
import '../../../studio/presentation/providers/studio_form_provider.dart';
import '../../domain/models/track_detail_models.dart';
import '../providers/track_providers.dart';
import '../widgets/emoji_reaction_deck.dart';
import '../widgets/lyrics_teleprompter.dart';
import '../widgets/more_like_this_shelf.dart';
import '../widgets/prompt_attribution_card.dart';
import '../widgets/track_living_biome_preview_card.dart';
import '../widgets/stem_separation_lab.dart';
import '../widgets/track_actions_bar.dart';
import '../widgets/track_hero_section.dart';
import '../widgets/track_sonic_telemetry_card.dart';
import '../widgets/utility_tool_dock.dart';
import '../widgets/waveform_scrubber.dart';

/// Track Details Cockpit & Audio Dissection View (`/track/:id`) (REQ-TRK-01 … REQ-TRK-11).
class TrackDetailView extends ConsumerStatefulWidget {
  final String trackId;
  final VoidCallback? onNavigateToStudio;

  const TrackDetailView({
    super.key,
    required this.trackId,
    this.onNavigateToStudio,
  });

  @override
  ConsumerState<TrackDetailView> createState() => _TrackDetailViewState();
}

class _TrackDetailViewState extends ConsumerState<TrackDetailView> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _lyricsKey = GlobalKey();
  final GlobalKey _commentsKey = GlobalKey();
  final ValueNotifier<bool> _showStickyTitle = ValueNotifier<bool>(false);
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _composerFocusNode = FocusNode();
  StateController<int>? _trackInlinePlayerCounter;
  bool _didIncrementInlinePlayer = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final counter = ref.read(trackDetailInlinePlayerMountedProvider.notifier);
      _trackInlinePlayerCounter = counter;
      _didIncrementInlinePlayer = true;
      counter.state++;
      ref
          .read(reelsCommentsProvider.notifier)
          .syncCommentsForClip(widget.trackId);
    });
  }

  /// Reveals the sticky app-bar title once the hero artwork scrolls away.
  void _onScroll() {
    final shouldShow = _scrollController.offset > 240;
    if (shouldShow != _showStickyTitle.value) {
      _showStickyTitle.value = shouldShow;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _showStickyTitle.dispose();
    _commentController.dispose();
    _composerFocusNode.dispose();
    final counter = _trackInlinePlayerCounter;
    if (_didIncrementInlinePlayer && counter != null) {
      _didIncrementInlinePlayer = false;
      Future<void>.microtask(() {
        if (counter.mounted && counter.state > 0) {
          counter.state = (counter.state - 1).clamp(0, 99);
        }
      });
    }
    super.dispose();
  }

  /// Precision section navigation — scrolls the target widget into view
  /// regardless of screen density, font scale, or dynamic content height.
  void _scrollToSection(GlobalKey key) {
    final targetContext = key.currentContext;
    if (targetContext != null) {
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
        alignment: 0.1,
      );
    }
  }

  void _handleRemix(TrackDetailEntity track) {
    // Write prompt and genre into StudioFormNotifier
    ref.read(studioFormProvider.notifier).updatePrompt(track.prompt);
    ref.read(studioFormProvider.notifier).setGenre(track.genre);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Prompt transferred to Studio: "${track.prompt}"'),
        backgroundColor: AppColors.surfaceElevated,
      ),
    );
    if (widget.onNavigateToStudio != null) {
      widget.onNavigateToStudio!();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _showTipModal(TrackDetailEntity track) {
    // Resolve whether this track belongs to a multi-collaborator collection
    final collections = ref.read(collectionsProvider);
    CollectionEntity? matchedCollection;
    for (final col in collections) {
      if (col.trackIds.contains(track.id)) {
        matchedCollection = col;
        break;
      }
    }

    final hasSplit =
        matchedCollection != null && matchedCollection.isSplitBalanced;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceModal,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalCtx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const PhosphorIcon(
                    PhosphorIconsRegular.coin,
                    color: AppColors.coinGold,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tip ${track.creatorName}',
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (hasSplit && matchedCollection != null)
                          Text(
                            'Split Sheet: ${matchedCollection.title} (${matchedCollection.participants.length} Collaborators)',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.brandPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const PhosphorIcon(PhosphorIconsRegular.x, size: 20),
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    onPressed: () => Navigator.of(modalCtx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                hasSplit
                    ? 'Tips are automatically split across collaborators according to the signed project split sheet.'
                    : 'Show support for this musical generation. Credits go directly to the creator.',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [5, 10, 25, 50].map((credits) {
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surfaceElevated,
                      foregroundColor: AppColors.coinGold,
                      side: BorderSide(color: AppColors.coinGold.withAlpha(90)),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.pillBorder,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () async {
                      Navigator.of(modalCtx).pop();
                      final ok = await ref
                          .read(creatorWalletProvider.notifier)
                          .distributeTrackTip(
                            trackId: track.id,
                            trackTitle: track.title,
                            creatorId: track.creatorId,
                            creatorName: track.creatorName,
                            credits: credits,
                            collection: matchedCollection,
                          );

                      if (!mounted) return;
                      if (ok) {
                        final splitMsg = hasSplit
                            ? ' Split across ${matchedCollection!.participants.length} collaborators!'
                            : '';
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Tipped $credits credits to ${track.creatorName}!$splitMsg',
                            ),
                            backgroundColor: AppColors.surfaceElevated,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Insufficient coin balance to send tip.',
                            ),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const PhosphorIcon(
                          PhosphorIconsRegular.lightning,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$credits',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDownloadDialog(TrackDetailEntity track) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        final textPrimary = AppColors.textPrimaryOf(dialogCtx);
        final textSecondary = AppColors.textSecondaryOf(dialogCtx);
        return AlertDialog(
          backgroundColor: AppColors.surfaceModalOf(dialogCtx),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
          title: Row(
            children: [
              const PhosphorIcon(
                AppIcons.download,
                color: AppColors.brandPrimary,
              ),
              const SizedBox(width: 8),
              Text(
                'Download Audio',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  'MP3 (320 kbps)',
                  style: TextStyle(color: textPrimary),
                ),
                subtitle: Text(
                  'High-quality stereo stream',
                  style: TextStyle(color: textSecondary),
                ),
                trailing: const PhosphorIcon(
                  AppIcons.download,
                  color: AppColors.brandPrimary,
                ),
                onTap: () {
                  Navigator.of(dialogCtx).pop();
                  final libTrack = LibraryTrack(
                    id: track.id,
                    title: track.title,
                    creatorName: track.creatorName,
                    genre: track.genre,
                    language: track.language,
                    durationSeconds: track.duration.inSeconds,
                    remoteAudioUrl:
                        'https://cdn.vhunambi.com/audio/${track.id}.mp3',
                    createdAt: DateTime.now(),
                  );
                  ref
                      .read(downloadManagerProvider.notifier)
                      .downloadTrack(
                        libTrack,
                        quality: AudioDownloadQuality.mp3HighQuality,
                      );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Downloading "${track.title}.mp3"...'),
                    ),
                  );
                },
              ),
              ListTile(
                title: Text(
                  'WAV (Lossless 24-bit)',
                  style: TextStyle(color: textPrimary),
                ),
                subtitle: Text(
                  'Studio master audio',
                  style: TextStyle(color: textSecondary),
                ),
                trailing: const PhosphorIcon(
                  AppIcons.download,
                  color: AppColors.brandPrimary,
                ),
                onTap: () {
                  Navigator.of(dialogCtx).pop();
                  final libTrack = LibraryTrack(
                    id: track.id,
                    title: track.title,
                    creatorName: track.creatorName,
                    genre: track.genre,
                    language: track.language,
                    durationSeconds: track.duration.inSeconds,
                    remoteAudioUrl:
                        'https://cdn.vhunambi.com/audio/${track.id}.wav',
                    createdAt: DateTime.now(),
                  );
                  ref
                      .read(downloadManagerProvider.notifier)
                      .downloadTrack(
                        libTrack,
                        quality: AudioDownloadQuality.wavLossless,
                      );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Downloading "${track.title}.wav"...'),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _openVideoExport(TrackDetailEntity track) {
    final job = VideoExportJob(
      id: 'job_${track.id}',
      title: track.title,
      creatorHandle: track.creatorHandle,
      genre: track.genre,
      audioPath: 'https://cdn.vhunambi.com/audio/${track.id}.mp3',
      durationSec: track.duration.inSeconds.toDouble(),
    );
    VideoExportModal.show(context, job: job);
  }

  void _copyEmbedCode(TrackDetailEntity track) {
    final embed =
        '<iframe src="https://vhunambi.com/embed/${track.id}" width="100%" height="160" frameborder="0"></iframe>';
    Clipboard.setData(ClipboardData(text: embed));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Embed snippet copied to clipboard!')),
    );
  }

  void _shareTrackLink(TrackDetailEntity track) {
    Clipboard.setData(
      ClipboardData(text: 'https://vhunambi.com/track/${track.id}'),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Track link copied to clipboard!')),
    );
  }

  Future<void> _submitThreadedTrackComment(TrackDetailEntity track) async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    _commentController.clear();
    await ref
        .read(reelsCommentsProvider.notifier)
        .addComment(
          clipId: track.id,
          text: text,
          contentCreatorId: track.creatorId,
          contentCreatorHandle: track.creatorHandle,
        );
  }

  @override
  Widget build(BuildContext context) {
    final track = ref.watch(trackDetailFamilyProvider(widget.trackId));
    final recommendations = ref.watch(moreLikeThisProvider(widget.trackId));
    final playerState = ref.watch(playerStateProvider);
    final activeCreatorId = ref.watch(currentCreatorIdProvider);
    final activeHandle = ref.watch(currentCreatorHandleProvider);
    final viewerRole = resolveViewerRole(
      ownerCreatorId: track.creatorId,
      ownerHandle: track.creatorHandle,
      activeCreatorId: activeCreatorId,
      activeHandle: activeHandle,
    );
    final isTrackOwner = viewerRole == ViewerRole.owner;
    final isPlayingThisTrack =
        playerState.isPlaying && playerState.currentTrack?.id == track.id;

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvasOf(context),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(
          VhunambiTopBarMetrics.totalHeight(context),
        ),
        child: _TrackDetailAppBar(
          track: track,
          showStickyTitle: _showStickyTitle,
          onShare: () => _shareTrackLink(track),
        ),
      ),
      body: VhunambiAmbientMeshBackdrop.forGenre(
        genre: track.genre,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  children: [
                    // 1. Role-Gated Hero Artwork Showcase & Provenance (`SC-01`, `SC-03`)
                    TrackHeroSection(
                      track: track,
                      viewerRole: viewerRole,
                      onTapCreator: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                ArtistProfileView(artistId: track.creatorId),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    // 2. High-Contrast Glass Action Bar (`SC-04`)
                    TrackActionsBar(
                      track: track,
                      onToggleLike: () {
                        ref
                            .read(
                              trackDetailFamilyProvider(
                                widget.trackId,
                              ).notifier,
                            )
                            .toggleLike();
                      },
                      onRemix: (isTrackOwner || track.allowOpenStemsRemix)
                          ? () => _handleRemix(track)
                          : null,
                      onTip: () => _showTipModal(track),
                      onShare: () => _shareTrackLink(track),
                      onAddToPlaylist: () {
                        AddToPlaylistSheet.show(
                          context,
                          Track(
                            id: track.id,
                            title: track.title,
                            creatorName: track.creatorName,
                            genre: track.genre,
                            language: track.language,
                            duration: track.duration,
                            coverUrl: track.coverUrl,
                          ),
                        );
                      },
                    ),

                    // 3. Compact Horizontal Vector Reaction Rail (`REQ-P70-SCUX-03`)
                    EmojiReactionDeck(
                      track: track,
                      onToggleReaction: (key) {
                        ref
                            .read(
                              trackDetailFamilyProvider(
                                widget.trackId,
                              ).notifier,
                            )
                            .toggleReaction(key);
                      },
                    ),

                    // 4. Interactive Amplitude Waveform Scrubber
                    WaveformScrubber(
                      track: track,
                      currentPosition: isPlayingThisTrack
                          ? playerState.position
                          : Duration.zero,
                      isPlaying: isPlayingThisTrack,
                      onTogglePlay: () {
                        if (isPlayingThisTrack) {
                          ref.read(playerStateProvider.notifier).pause();
                        } else {
                          ref
                              .read(playerStateProvider.notifier)
                              .playTrack(
                                Track(
                                  id: track.id,
                                  title: track.title,
                                  creatorName: track.creatorName,
                                  genre: track.genre,
                                  language: track.language,
                                  duration: track.duration,
                                  coverUrl: track.coverUrl,
                                ),
                              );
                        }
                      },
                      onSeek: (pos) {
                        ref.read(playerStateProvider.notifier).seek(pos);
                      },
                    ),

                    // 5. Structured Song Description & Sonic Telemetry Glass Card (`SC-05`)
                    TrackSonicTelemetryCard(track: track),

                    // 6. Conditional Visitor Open-Stems Remix CTA (when creator opted in)
                    if (!isTrackOwner && track.allowOpenStemsRemix)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: OutlinedButton.icon(
                          key: const Key('track_visitor_open_stems_remix_btn'),
                          onPressed: () => _handleRemix(track),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            side: const BorderSide(
                              color: AppColors.brandPrimary,
                            ),
                            shape: const RoundedRectangleBorder(
                              borderRadius: AppRadius.pillBorder,
                            ),
                          ),
                          icon: const PhosphorIcon(
                            AppIcons.remix,
                            size: 18,
                            color: AppColors.brandPrimary,
                          ),
                          label: Text(
                            'Remix Open Stems',
                            style: AppTypography.titleSmall.copyWith(
                              color: AppColors.brandPrimary,
                            ),
                          ),
                        ),
                      ),

                    // 7. Synchronized Lyrics Teleprompter
                    LyricsTeleprompter(key: _lyricsKey, track: track),

                    // 8. Owner-Only Creator Studio Cockpit (`SC-02` Sovereignty Gate)
                    if (isTrackOwner) ...[
                      UtilityToolDock(
                        track: track,
                        onDownload: () => _showDownloadDialog(track),
                        onExportVideo: () => _openVideoExport(track),
                        onAddToPlaylist: () {
                          AddToPlaylistSheet.show(
                            context,
                            Track(
                              id: track.id,
                              title: track.title,
                              creatorName: track.creatorName,
                              genre: track.genre,
                              language: track.language,
                              duration: track.duration,
                              coverUrl: track.coverUrl,
                            ),
                          );
                        },
                        onStartRadio: () {
                          ref
                              .read(playerStateProvider.notifier)
                              .playTrack(
                                Track(
                                  id: track.id,
                                  title: track.title,
                                  creatorName: track.creatorName,
                                  genre: track.genre,
                                  language: track.language,
                                  duration: track.duration,
                                  coverUrl: track.coverUrl,
                                ),
                              );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Radio station started: ${track.genre}',
                              ),
                            ),
                          );
                        },
                        onJumpToLyrics: () => _scrollToSection(_lyricsKey),
                        onVariation: () => _handleRemix(track),
                        onJumpToComments: () => _scrollToSection(_commentsKey),
                        onEmbed: () => _copyEmbedCode(track),
                      ),

                      StemSeparationLab(
                        stemState: track.stemState,
                        onSeparateStems: () {
                          ref
                              .read(
                                trackDetailFamilyProvider(
                                  widget.trackId,
                                ).notifier,
                              )
                              .separateStems();
                        },
                        onToggleMuteStem: (id) {
                          ref
                              .read(
                                trackDetailFamilyProvider(
                                  widget.trackId,
                                ).notifier,
                              )
                              .toggleMuteStem(id);
                        },
                        onToggleSoloStem: (id) {
                          ref
                              .read(
                                trackDetailFamilyProvider(
                                  widget.trackId,
                                ).notifier,
                              )
                              .toggleSoloStem(id);
                        },
                        onDownloadStem: (stem) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Downloading stem: "${stem.name}.wav"...',
                              ),
                            ),
                          );
                        },
                      ),

                      TrackLivingBiomePreviewCard(
                        trackTitle: track.title,
                        genre: track.genre,
                      ),

                      const SizedBox(height: AppSpacing.sm),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: OutlinedButton.icon(
                          key: const Key('track_open_mixer_btn'),
                          onPressed: () {
                            showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (ctx) => FractionallySizedBox(
                                heightFactor: 0.9,
                                child: _FrostedStemMixerSheet(
                                  title: track.title,
                                ),
                              ),
                            );
                          },
                          icon: const PhosphorIcon(
                            AppIcons.sliders,
                            color: AppColors.brandPrimary,
                            size: 20,
                          ),
                          label: Text(
                            'Open Pocket Stem Mixer',
                            style: AppTypography.bodyLarge.copyWith(
                              color: AppColors.brandPrimary,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: AppColors.brandPrimary,
                            ),
                            minimumSize: const Size.fromHeight(48),
                            shape: const RoundedRectangleBorder(
                              borderRadius: AppRadius.inputBorder,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: AppSpacing.sm),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: OutlinedButton.icon(
                          key: const Key('track_detail_open_mastering_btn'),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            ref
                                .read(masteringSessionProvider.notifier)
                                .initializeForTrack(
                                  trackId: track.id,
                                  trackTitle: track.title,
                                  genre: track.genre,
                                );
                            if (ResponsiveUtils.isDesktop(context)) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => DesktopMasteringStudioView(
                                    trackId: track.id,
                                    trackTitle: track.title,
                                    genre: track.genre,
                                  ),
                                ),
                              );
                            } else {
                              showModalBottomSheet<void>(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (ctx) => FractionallySizedBox(
                                  heightFactor: 0.9,
                                  child: MobileQuickMasterSheet(
                                    trackId: track.id,
                                    trackTitle: track.title,
                                    genre: track.genre,
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const PhosphorIcon(
                            AppIcons.sparkle,
                            color: AppColors.brandPrimary,
                          ),
                          label: Text(
                            'Master Track (Studio Polisher)',
                            style: AppTypography.bodyLarge.copyWith(
                              color: AppColors.brandPrimary,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: AppColors.brandPrimary,
                            ),
                            minimumSize: const Size.fromHeight(48),
                            shape: const RoundedRectangleBorder(
                              borderRadius: AppRadius.inputBorder,
                            ),
                          ),
                        ),
                      ),

                      PromptAttributionCard(
                        track: track,
                        onRemixPrompt: () => _handleRemix(track),
                      ),
                    ],

                    // 9. Shared Threaded Discussion Thread (`EP-P69-THREADED-COMMENTS`)
                    Padding(
                      key: _commentsKey,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ThreadedCommentsSection(
                        clipOrPostId: track.id,
                        contentCreatorId: track.creatorId,
                        contentCreatorHandle: track.creatorHandle,
                        onRequestReplyFocus: () =>
                            _composerFocusNode.requestFocus(),
                      ),
                    ),

                    // 10. "More Like This" Recommendations Shelf (`VhunambiTrackArtwork`)
                    MoreLikeThisShelf(
                      recommendations: recommendations,
                      onSelectTrack: (selected) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => TrackDetailView(
                              trackId: selected.id,
                              onNavigateToStudio: widget.onNavigateToStudio,
                            ),
                          ),
                        );
                      },
                      onAuditionTrack: (selected) {
                        ref
                            .read(playerStateProvider.notifier)
                            .playTrack(
                              Track(
                                id: selected.id,
                                title: selected.title,
                                creatorName: selected.creatorName,
                                genre: selected.genre,
                                language: selected.language,
                                duration: selected.duration,
                                coverUrl: selected.coverUrl,
                              ),
                            );
                      },
                    ),

                    // Bottom clearance above sticky StudioReactionComposerBar
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: StudioReactionComposerBar(
        clipOrPostId: track.id,
        creatorHandle: track.creatorHandle,
        controller: _commentController,
        focusNode: _composerFocusNode,
        onSubmit: () => _submitThreadedTrackComment(track),
      ),
    );
  }
}

/// Frosted, scroll-aware top bar for the track cockpit.
///
/// Defaults to the brand mark; once the hero artwork scrolls away it
/// cross-fades to the track title + creator so context is never lost.
class _TrackDetailAppBar extends StatelessWidget {
  final TrackDetailEntity track;
  final ValueNotifier<bool> showStickyTitle;
  final VoidCallback onShare;

  const _TrackDetailAppBar({
    required this.track,
    required this.showStickyTitle,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryOf(context);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          color: AppColors.surfaceCanvasOf(context).withAlpha(200),
          child: Padding(
            padding: EdgeInsets.only(
              top: VhunambiTopBarMetrics.topInset(context),
            ),
            child: SizedBox(
              height: 56,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Row(
                  children: [
                    VhunambiBackButton(color: textPrimary),
                    Expanded(
                      child: ValueListenableBuilder<bool>(
                        valueListenable: showStickyTitle,
                        builder: (context, showTitle, _) {
                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: showTitle
                                ? _StickyTrackTitle(
                                    key: const ValueKey('sticky-title'),
                                    track: track,
                                  )
                                : const _BrandMark(key: ValueKey('brand-mark')),
                          );
                        },
                      ),
                    ),
                    IconButton(
                      icon: PhosphorIcon(
                        AppIcons.share,
                        color: textPrimary,
                        size: 20,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      tooltip: 'Share',
                      onPressed: onShare,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const PhosphorIcon(
          AppIcons.songs,
          color: AppColors.brandPrimary,
          size: 20,
        ),
        const SizedBox(width: 6),
        Text(
          'VHUNAMBI',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: AppColors.textPrimaryOf(context),
          ),
        ),
      ],
    );
  }
}

class _StickyTrackTitle extends StatelessWidget {
  final TrackDetailEntity track;
  const _StickyTrackTitle({super.key, required this.track});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          track.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          track.creatorName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// Frosted Pocket Stem Mixer modal — elevated surfaceModal surface with a
/// pill drag-handle and a canonical close affordance (audit DEF-TRK-04).
class _FrostedStemMixerSheet extends StatelessWidget {
  final String? title;
  const _FrostedStemMixerSheet({this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceModal,
        borderRadius: AppRadius.modalBorder,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(120),
            blurRadius: 30,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Pill drag-handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(9999),
                ),
              ),
            ),
            // Canonical close affordance
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xs),
                child: VhunambiBackButton(
                  color: AppColors.textPrimary,
                  tooltip: 'Close Mixer',
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Expanded(child: StemMixerDeck(title: title)),
          ],
        ),
      ),
    );
  }
}
