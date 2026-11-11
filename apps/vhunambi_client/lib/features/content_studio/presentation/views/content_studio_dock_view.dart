import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../core/widgets/vhunambi_top_bar_kit.dart';
import '../../domain/models/song_metadata_dna.dart';
import '../providers/content_studio_provider.dart';
import '../providers/master_media_object_provider.dart';
import '../widgets/kinetic_preview_canvas.dart';
import '../widgets/typography_preset_picker.dart';
import '../widgets/duration_trim_scrubber.dart';
import '../widgets/atmospheric_effects_deck.dart';
import '../widgets/export_action_sheet.dart';
import '../widgets/publish_clip_modal.dart';
import '../../../player/presentation/widgets/player_obstacle.dart';

/// Responsive Content Studio Cockpit for turning song DNA, 9:16 cover art,
/// and synchronized lyrics into exportable short-form videos.
class ContentStudioDockView extends ConsumerStatefulWidget {
  final SongMetadataDna? initialDna;
  final String? initialAudioUrl;
  final String? initialCoverArtUrl;

  const ContentStudioDockView({
    super.key,
    this.initialDna,
    this.initialAudioUrl,
    this.initialCoverArtUrl,
  });

  static Future<void> show(
    BuildContext context, {
    required SongMetadataDna dna,
    required String audioUrl,
    required String coverArtUrl,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ContentStudioDockView(
          initialDna: dna,
          initialAudioUrl: audioUrl,
          initialCoverArtUrl: coverArtUrl,
        ),
      ),
    );
  }

  static Future<void> open(
    BuildContext context, {
    required SongMetadataDna dna,
    required String audioUrl,
    required String coverArtUrl,
  }) => show(context, dna: dna, audioUrl: audioUrl, coverArtUrl: coverArtUrl);

  @override
  ConsumerState<ContentStudioDockView> createState() =>
      _ContentStudioDockViewState();
}

class _ContentStudioDockViewState extends ConsumerState<ContentStudioDockView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialDna != null &&
          widget.initialAudioUrl != null &&
          widget.initialCoverArtUrl != null) {
        ref
            .read(contentStudioProvider.notifier)
            .initializeWithDna(
              dna: widget.initialDna!,
              audioUrl: widget.initialAudioUrl!,
              coverArtUrl: widget.initialCoverArtUrl!,
            );
      }
    });
  }

  void _openExportSheet(BuildContext context) {
    final notifier = ref.read(contentStudioProvider.notifier);
    notifier.exportVideo();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Consumer(
          builder: (context, ref, child) {
            final state = ref.watch(contentStudioProvider);
            return ExportActionSheet(
              isExporting: state.isExporting,
              progress: state.exportProgress,
              exportedFilePath: state.exportedFilePath,
              errorMessage: state.errorMessage,
              onDismiss: () => Navigator.of(sheetContext).pop(),
              onPublish: () {
                Navigator.of(sheetContext).pop();
                PublishClipModal.show(context);
              },
            );
          },
        );
      },
    );
  }

  void _openPublishModal(BuildContext context) {
    PublishClipModal.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(contentStudioProvider);
    final notifier = ref.read(contentStudioProvider.notifier);
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final modulationSnapshot = state.dna != null
        ? ref.watch(
            frameModulationSnapshotProvider((
              dna: state.dna!,
              positionMs: (state.playbackPositionSec * 1000).round(),
            )),
          )
        : null;

    final title = state.dna?.title ?? 'Lyric Video Studio';
    final genre = state.dna?.genre ?? 'African Rhythm';

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceElevated,
        elevation: 0,
        leading: VhunambiBackButton(color: AppColors.textPrimary),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTypography.bodyLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'CONTENT STUDIO • $genre (9:16 REEL)',
              style: AppTypography.caption.copyWith(
                color: AppColors.brandPrimary,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              key: const Key('app_bar_export_button'),
              onPressed: () => _openExportSheet(context),
              icon: const Icon(
                Icons.download_rounded,
                color: AppColors.brandContrast,
                size: 18,
              ),
              label: Text(
                'Export MP4',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.brandContrast,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.inputBorder,
                ),
              ),
            ),
          ),
        ],
      ),
      body: isDesktop
          ? _buildDesktopLayout(state, notifier, modulationSnapshot)
          : _buildMobileLayout(state, notifier, modulationSnapshot),
    );
  }

  Widget _buildDesktopLayout(
    ContentStudioState state,
    ContentStudioNotifier notifier,
    FrameModulationSnapshot? modulationSnapshot,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: 9:16 Kinetic Video Canvas Dock
        Expanded(
          flex: 5,
          child: Container(
            color: AppColors.surfaceCanvas,
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Center(
                    child: KineticPreviewCanvas(
                      coverArtUrl: state.coverArtUrl,
                      words: state.words,
                      preset: state.typographyPreset,
                      effects: state.effects,
                      playbackPositionSec: state.playbackPositionSec,
                      isPlaying: state.isPlaying,
                      onPlayPauseToggle: notifier.togglePlayPause,
                      modulationSnapshot: modulationSnapshot,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.filled(
                      onPressed: notifier.togglePlayPause,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.brandPrimary,
                      ),
                      icon: Icon(
                        state.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: AppColors.brandContrast,
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        final newSeed = DateTime.now().millisecondsSinceEpoch;
                        notifier.reRollCoverArt(
                          AppConstants.normalizeCloudMediaUrl(
                            'https://r2.vhunambi.com/visuals/reroll_${newSeed}_9_16.png',
                          ),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Dispatched fresh 9:16 artwork to ComfyUI!',
                            ),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.refresh_rounded,
                        size: 16,
                        color: AppColors.brandPrimary,
                      ),
                      label: Text(
                        'Re-roll Artwork',
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppColors.brandPrimary,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.brandPrimary),
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.inputBorder,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Right Column: Controls, Typography & Effects Cockpit
        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DurationTrimScrubber(
                  selectedPreset: state.durationPreset,
                  startSeconds: state.startSeconds,
                  endSeconds: state.endSeconds,
                  maxDurationSec:
                      state.dna?.musical.durationSec.toDouble() ?? 180.0,
                  playbackPositionSec: state.playbackPositionSec,
                  onPresetChanged: notifier.setDurationPreset,
                  onTrimBoundsChanged: notifier.setTrimBounds,
                  onSeek: notifier.seekTo,
                ),
                const SizedBox(height: 28),
                Divider(color: AppColors.borderSubtle),
                const SizedBox(height: 20),
                TypographyPresetPicker(
                  selectedPreset: state.typographyPreset,
                  onPresetSelected: notifier.setPreset,
                ),
                const SizedBox(height: 28),
                Divider(color: AppColors.borderSubtle),
                const SizedBox(height: 20),
                AtmosphericEffectsDeck(
                  effects: state.effects,
                  onToggle: notifier.toggleEffect,
                ),
                const SizedBox(height: 40),
                ElevatedButton.icon(
                  onPressed: () => _openExportSheet(context),
                  icon: const Icon(
                    Icons.movie_creation_rounded,
                    color: AppColors.brandContrast,
                  ),
                  label: Text(
                    'Render & Export 1080x1920 MP4',
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.brandContrast,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    minimumSize: const Size.fromHeight(52),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.cardBorder,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(
    ContentStudioState state,
    ContentStudioNotifier notifier,
    FrameModulationSnapshot? modulationSnapshot,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Pinned 9:16 Preview Box
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 460),
            child: Center(
              child: KineticPreviewCanvas(
                coverArtUrl: state.coverArtUrl,
                words: state.words,
                preset: state.typographyPreset,
                effects: state.effects,
                playbackPositionSec: state.playbackPositionSec,
                isPlaying: state.isPlaying,
                onPlayPauseToggle: notifier.togglePlayPause,
                modulationSnapshot: modulationSnapshot,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filled(
                onPressed: notifier.togglePlayPause,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                ),
                icon: Icon(
                  state.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: AppColors.brandContrast,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {
                  final newSeed = DateTime.now().millisecondsSinceEpoch;
                  notifier.reRollCoverArt(
                    AppConstants.normalizeCloudMediaUrl(
                      'https://r2.vhunambi.com/visuals/reroll_${newSeed}_9_16.png',
                    ),
                  );
                },
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 14,
                  color: AppColors.brandPrimary,
                ),
                label: Text(
                  'Re-roll Art',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.brandPrimary,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.brandPrimary),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.thumbBorder,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          DurationTrimScrubber(
            selectedPreset: state.durationPreset,
            startSeconds: state.startSeconds,
            endSeconds: state.endSeconds,
            maxDurationSec: state.dna?.musical.durationSec.toDouble() ?? 180.0,
            playbackPositionSec: state.playbackPositionSec,
            onPresetChanged: notifier.setDurationPreset,
            onTrimBoundsChanged: notifier.setTrimBounds,
            onSeek: notifier.seekTo,
          ),
          const SizedBox(height: 24),
          TypographyPresetPicker(
            selectedPreset: state.typographyPreset,
            onPresetSelected: notifier.setPreset,
          ),
          const SizedBox(height: 24),
          AtmosphericEffectsDeck(
            effects: state.effects,
            onToggle: notifier.toggleEffect,
          ),
          PlayerObstacle(
            id: 'content_studio_dock',
            child: Column(
              children: [
                OutlinedButton.icon(
                  key: const Key('dock_publish_to_profile_btn'),
                  onPressed: () => _openPublishModal(context),
                  icon: const Icon(
                    Icons.campaign_rounded,
                    color: AppColors.brandPrimary,
                  ),
                  label: Text(
                    'Publish to Profile',
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.brandPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.brandPrimary),
                    minimumSize: const Size.fromHeight(48),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.inputBorder,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => _openExportSheet(context),
                  icon: const Icon(
                    Icons.download_rounded,
                    color: AppColors.brandContrast,
                  ),
                  label: Text(
                    'Export MP4',
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.brandContrast,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    minimumSize: const Size.fromHeight(48),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.inputBorder,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
