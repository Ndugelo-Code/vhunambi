import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/vhunambi_top_bar_kit.dart';
import '../../../../core/widgets/vhunambi_bottom_dock_kit.dart';
import '../../../../shared/models/track.dart';
import '../../../library/domain/models/library_models.dart';
import '../../../offline/domain/models/offline_models.dart';
import '../../../offline/presentation/providers/offline_providers.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../player/presentation/widgets/stem_mixer_deck.dart';
import '../../../profile/presentation/views/artist_profile_view.dart';
import '../../../studio/presentation/providers/studio_form_provider.dart';
import '../../domain/models/track_detail_models.dart';
import '../providers/track_providers.dart';
import '../widgets/comments_section.dart';
import '../widgets/emoji_reaction_deck.dart';
import '../widgets/lyrics_teleprompter.dart';
import '../widgets/more_like_this_shelf.dart';
import '../widgets/prompt_attribution_card.dart';
import '../widgets/stem_separation_lab.dart';
import '../widgets/track_actions_bar.dart';
import '../widgets/track_hero_section.dart';
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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
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
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceModal,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.monetization_on_rounded,
                    color: AppColors.coinGold,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Tip ${track.creatorName}',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Show support for this musical generation. Credits go directly to the creator.',
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
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.pillBorder,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Tipped $credits credits to ${track.creatorName}! 🪙',
                          ),
                          backgroundColor: AppColors.surfaceElevated,
                        ),
                      );
                    },
                    child: Text(
                      '⚡ $credits',
                      style: const TextStyle(fontWeight: FontWeight.bold),
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
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceModal,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
          title: Row(
            children: [
              const Icon(Icons.download_rounded, color: AppColors.brandPrimary),
              const SizedBox(width: 8),
              Text(
                'Download Audio',
                style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('MP3 (320 kbps)', style: TextStyle(color: Colors.white)),
                subtitle: const Text('High-quality stereo stream', style: TextStyle(color: AppColors.textSecondary)),
                trailing: const Icon(Icons.download_rounded, color: AppColors.brandPrimary),
                onTap: () {
                  Navigator.of(context).pop();
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
                  ref.read(downloadManagerProvider.notifier).downloadTrack(
                    libTrack,
                    quality: AudioDownloadQuality.mp3HighQuality,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Downloading "${track.title}.mp3"...')),
                  );
                },
              ),
              ListTile(
                title: const Text('WAV (Lossless 24-bit)', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Studio master audio', style: TextStyle(color: AppColors.textSecondary)),
                trailing: const Icon(Icons.download_rounded, color: AppColors.brandPrimary),
                onTap: () {
                  Navigator.of(context).pop();
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
                  ref.read(downloadManagerProvider.notifier).downloadTrack(
                    libTrack,
                    quality: AudioDownloadQuality.wavLossless,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Downloading "${track.title}.wav"...')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _copyEmbedCode(TrackDetailEntity track) {
    final embed = '<iframe src="https://vhunambi.com/embed/${track.id}" width="100%" height="160" frameborder="0"></iframe>';
    Clipboard.setData(ClipboardData(text: embed));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Embed snippet copied to clipboard! 📋')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final track = ref.watch(trackDetailFamilyProvider(widget.trackId));
    final comments = ref.watch(trackCommentsProvider(widget.trackId));
    final recommendations = ref.watch(moreLikeThisProvider(widget.trackId));
    final playerState = ref.watch(playerStateProvider);
    final isPlayingThisTrack =
        playerState.isPlaying && playerState.currentTrack?.id == track.id;

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(
          VhunambiTopBarMetrics.totalHeight(context),
        ),
        child: _TrackDetailAppBar(track: track, showStickyTitle: _showStickyTitle),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                children: [
                  // 1. Hero Artwork Showcase & Metadata
                  TrackHeroSection(
                    track: track,
                    onTapCreator: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => ArtistProfileView(
                            artistId: track.creatorId,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  // 2. Primary Social Action Row
                  TrackActionsBar(
                    track: track,
                    onToggleLike: () {
                      ref
                          .read(trackDetailFamilyProvider(widget.trackId).notifier)
                          .toggleLike();
                    },
                    onRemix: () => _handleRemix(track),
                    onTip: () => _showTipModal(track),
                  ),

                  // 3. Secondary Utility Dock
                  UtilityToolDock(
                    track: track,
                    onDownload: () => _showDownloadDialog(track),
                    onAddToPlaylist: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Added to My Playlist ✨')),
                      );
                    },
                    onStartRadio: () {
                      ref.read(playerStateProvider.notifier).playTrack(
                            Track(
                              id: track.id,
                              title: track.title,
                              creatorName: track.creatorName,
                              genre: track.genre,
                              language: track.language,
                              duration: track.duration,
                            ),
                          );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Radio station started: ${track.genre}')),
                      );
                    },
                    onJumpToLyrics: () => _scrollToSection(_lyricsKey),
                    onVariation: () => _handleRemix(track),
                    onJumpToComments: () => _scrollToSection(_commentsKey),
                    onEmbed: () => _copyEmbedCode(track),
                  ),

                  // 4. Cultural Emoji Reaction Dock
                  EmojiReactionDeck(
                    track: track,
                    onToggleReaction: (key) {
                      ref
                          .read(trackDetailFamilyProvider(widget.trackId).notifier)
                          .toggleReaction(key);
                    },
                  ),

                  // 5. Interactive Amplitude Waveform Scrubber
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
                        ref.read(playerStateProvider.notifier).playTrack(
                              Track(
                                id: track.id,
                                title: track.title,
                                creatorName: track.creatorName,
                                genre: track.genre,
                                language: track.language,
                                duration: track.duration,
                              ),
                            );
                      }
                    },
                    onSeek: (pos) {
                      ref.read(playerStateProvider.notifier).seek(pos);
                    },
                  ),

                  // 6. Synchronized Lyrics Teleprompter
                  LyricsTeleprompter(key: _lyricsKey, track: track),

                  // 7. 4-Stem Separation Lab
                  StemSeparationLab(
                    stemState: track.stemState,
                    onSeparateStems: () {
                      ref
                          .read(trackDetailFamilyProvider(widget.trackId).notifier)
                          .separateStems();
                    },
                    onToggleMuteStem: (id) {
                      ref
                          .read(trackDetailFamilyProvider(widget.trackId).notifier)
                          .toggleMuteStem(id);
                    },
                    onToggleSoloStem: (id) {
                      ref
                          .read(trackDetailFamilyProvider(widget.trackId).notifier)
                          .toggleSoloStem(id);
                    },
                    onDownloadStem: (stem) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Downloading stem: "${stem.name}.wav"...')),
                      );
                    },
                  ),

                  // 7b. Open Pocket Stem Mixer (Phase 21)
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    key: const Key('track_open_mixer_btn'),
                    onPressed: () {
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (ctx) => FractionallySizedBox(
                          heightFactor: 0.9,
                          child: _FrostedStemMixerSheet(title: track.title),
                        ),
                      );
                    },
                    icon: const Icon(Icons.tune_rounded,
                        color: AppColors.brandPrimary),
                    label: Text(
                      'Open Pocket Stem Mixer',
                      style: AppTypography.bodyLarge
                          .copyWith(color: AppColors.brandPrimary),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.brandPrimary),
                      minimumSize: const Size.fromHeight(48),
                      shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.inputBorder),
                    ),
                  ),

                  // 8. Generative Prompt Attribution Card
                  PromptAttributionCard(
                    track: track,
                    onRemixPrompt: () => _handleRemix(track),
                  ),

                  // 9. Discussion Thread & Comment Composer
                  CommentsSection(
                    key: _commentsKey,
                    comments: comments,
                    onAddComment: (content) {
                      ref
                          .read(trackCommentsProvider(widget.trackId).notifier)
                          .addComment(content);
                    },
                    onToggleLikeComment: (cmtId) {
                      ref
                          .read(trackCommentsProvider(widget.trackId).notifier)
                          .toggleLikeComment(cmtId);
                    },
                  ),

                  // 10. "More Like This" Recommendations Shelf
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
                      ref.read(playerStateProvider.notifier).playTrack(
                            Track(
                              id: selected.id,
                              title: selected.title,
                              creatorName: selected.creatorName,
                              genre: selected.genre,
                              language: selected.language,
                              duration: selected.duration,
                            ),
                          );
                    },
                  ),

                  // Bottom dock clearance so the floating transport never
                  // occludes the final recommendation cards.
                  SizedBox(
                    height: VhunambiBottomDockMetrics.scrollInset(
                      hasActiveTrack: playerState.hasActiveTrack,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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

  const _TrackDetailAppBar({
    required this.track,
    required this.showStickyTitle,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: AppColors.surfaceCanvas.withAlpha(200),
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
                    const VhunambiBackButton(color: Colors.white),
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
                                : const _BrandMark(
                                    key: ValueKey('brand-mark'),
                                  ),
                          );
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_rounded, color: Colors.white),
                      tooltip: 'Share',
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(
                            text: 'https://vhunambi.com/track/${track.id}',
                          ),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Track link copied to clipboard! 🔗'),
                          ),
                        );
                      },
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
        const Icon(
          Icons.music_note_rounded,
          color: AppColors.brandPrimary,
          size: 20,
        ),
        const SizedBox(width: 6),
        Text(
          'VHUNAMBI',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
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
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
          ),
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
