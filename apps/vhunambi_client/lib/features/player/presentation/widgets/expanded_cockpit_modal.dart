import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../providers/player_provider.dart';
import 'queue_drawer.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/song_metadata_dna.dart';
import 'package:vhunambi_client/features/content_studio/presentation/views/content_studio_dock_view.dart';
import 'package:vhunambi_client/features/social/domain/models/video_export_job.dart';
import 'package:vhunambi_client/features/social/presentation/widgets/video_export_modal.dart';

/// True when the active player [trackId] is hearted in the vault.
bool _isFavorite(WidgetRef ref, String trackId) {
  return ref
      .watch(libraryTracksProvider)
      .any((track) => track.id == trackId && track.isFavorite);
}

class ExpandedCockpitModal extends ConsumerStatefulWidget {
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
  ConsumerState<ExpandedCockpitModal> createState() =>
      _ExpandedCockpitModalState();
}

class _ExpandedCockpitModalState extends ConsumerState<ExpandedCockpitModal> {
  bool _showLyrics = false;

  @override
  Widget build(BuildContext context) {
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
                    key: const Key('player_lyrics_toggle'),
                    icon: Icon(
                      _showLyrics ? Icons.album_rounded : Icons.lyrics_rounded,
                      size: 22,
                      color: _showLyrics
                          ? AppColors.brandPrimary
                          : Colors.white,
                    ),
                    tooltip: _showLyrics ? 'Show artwork' : 'Show lyrics',
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() => _showLyrics = !_showLyrics);
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      _isFavorite(ref, track.id)
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
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
                    icon: const Icon(Icons.movie_creation_rounded, size: 22, color: Colors.white),
                    tooltip: 'Create 9:16 Lyric Reel',
                    onPressed: () => _openContentStudio(context, track),
                  ),
                  IconButton(
                    key: const Key('player_more_actions_btn'),
                    icon: const Icon(Icons.more_horiz_rounded, size: 24, color: Colors.white),
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

            const SizedBox(height: 16),

            // Hero Artwork / Lyrics surface (flip via the header toggle)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: _showLyrics
                    ? _buildLyricsCard(context, ref, track)
                    : Center(
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
                    key: const Key('player_meta_favorite_btn'),
                    icon: Icon(
                      _isFavorite(ref, track.id)
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: _isFavorite(ref, track.id)
                          ? AppColors.brandPrimary
                          : AppColors.textSecondary,
                      size: 26,
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
                    key: const Key('player_meta_share_btn'),
                    icon: const Icon(Icons.ios_share_rounded, color: AppColors.textSecondary, size: 22),
                    tooltip: 'Share Track',
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: 'https://vhunambi.com/track/${track.id}'),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Track link copied to clipboard!'),
                            backgroundColor: AppColors.surfaceModal,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
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
                          : AppColors.textTertiary,
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
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _UtilityItem(
                      key: const Key('player_lyrics_btn'),
                      icon: _showLyrics ? Icons.album_rounded : Icons.lyrics_outlined,
                      label: _showLyrics ? 'Artwork' : 'Lyrics',
                      onTap: () => setState(() => _showLyrics = !_showLyrics),
                    ),
                    _UtilityItem(
                      key: const Key('player_stems_btn'),
                      icon: Icons.tune_rounded,
                      label: 'Stems',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Stem Lab: Queued 4-stem split for "${track.title}" (Vocals, Drums, Bass, Other).'),
                            backgroundColor: AppColors.surfaceModal,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                    _UtilityItem(
                      key: const Key('player_track_info_btn'),
                      icon: Icons.info_outline_rounded,
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
                      icon: Icons.movie_creation_outlined,
                      label: 'Export Reel',
                      onTap: () => _openContentStudio(context, track),
                    ),
                    _UtilityItem(
                      key: const Key('player_mux_btn'),
                      icon: Icons.bolt_rounded,
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
                      icon: Icons.queue_music_rounded,
                      label: 'Queue',
                      onTap: () => QueueDrawer.show(context),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Builds the scrollable Lyrics reading card shown when [_showLyrics] is on.
  ///
  /// Resolves the active track's vault record for its bracketed stanza text;
  /// falls back to a friendly empty state when none is attached.
  Widget _buildLyricsCard(BuildContext context, WidgetRef ref, Track track) {
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
                const Icon(
                  Icons.lyrics_rounded,
                  size: 18,
                  color: AppColors.brandPrimary,
                ),
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
                    icon: const Icon(
                      Icons.copy_rounded,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () {
                      HapticFeedback.mediumImpact();
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
          const Divider(height: 1, color: AppColors.borderSubtle),
          Expanded(
            child: (lyrics == null || lyrics.trim().isEmpty)
                ? _LyricsEmptyState()
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: _buildLyricsBody(lyrics),
                  ),
          ),
        ],
      ),
    );
  }

  /// Renders bracketed stanza headers (`[Chorus]`) in bold brand color and
  /// lyric lines in [AppTypography.bodyLarge], preserving blank-line spacing.
  Widget _buildLyricsBody(String lyrics) {
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
                    color: AppColors.brandPrimary,
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
        .firstWhere(
          (t) => t?.id == track.id,
          orElse: () => null,
        );
    final dna = libraryTrack?.toSongMetadataDna() ??
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
      audioUrl: track.audioUrl ??
          'https://r2.vhunambi.com/audio/default.mp3',
      coverArtUrl: track.coverUrl ??
          'https://r2.vhunambi.com/visuals/default_9_16.png',
    );
  }
}

class _LyricsEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.music_note_rounded,
            size: 48,
            color: AppColors.textTertiary,
          ),
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
