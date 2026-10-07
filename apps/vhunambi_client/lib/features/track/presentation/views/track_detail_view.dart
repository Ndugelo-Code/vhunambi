import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/models/track.dart';
import '../../../library/domain/models/library_models.dart';
import '../../../offline/domain/models/offline_models.dart';
import '../../../offline/presentation/providers/offline_providers.dart';
import '../../../player/presentation/providers/player_provider.dart';
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollTo(double offset) {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
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
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCanvas,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Row(
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
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Colors.white),
            onPressed: () {
              Clipboard.setData(
                ClipboardData(text: 'https://vhunambi.com/track/${track.id}'),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Track link copied to clipboard! 🔗')),
              );
            },
          ),
        ],
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
                    onJumpToLyrics: () => _scrollTo(520),
                    onVariation: () => _handleRemix(track),
                    onJumpToComments: () => _scrollTo(1100),
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
                  LyricsTeleprompter(track: track),

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

                  // 8. Generative Prompt Attribution Card
                  PromptAttributionCard(
                    track: track,
                    onRemixPrompt: () => _handleRemix(track),
                  ),

                  // 9. Discussion Thread & Comment Composer
                  CommentsSection(
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
