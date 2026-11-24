import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/vhunambi_glass_surface.dart';
import '../../domain/models/generation_pipeline_state.dart';
import '../../../library/domain/models/library_models.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../track/domain/models/track_entity.dart';
import '../providers/generation_pipeline_providers.dart';
import '../providers/stem_download_provider.dart';
import 'package:vhunambi_client/features/content_studio/presentation/views/kinetic_reel_studio_view.dart';

/// Live result panel for the audio synthesis pipeline (T10.4).
///
/// Driven entirely by `generationProgressProvider`: a null session renders a
/// pulsing skeleton, an active session renders the equalizer + 4-step FSM, and a
/// failed session renders an inline error banner with a retry CTA.
class GenerationPipelineCard extends ConsumerStatefulWidget {
  final VoidCallback? onNewSong;

  const GenerationPipelineCard({super.key, this.onNewSong});

  @override
  ConsumerState<GenerationPipelineCard> createState() =>
      _GenerationPipelineCardState();
}

class _GenerationPipelineCardState extends ConsumerState<GenerationPipelineCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _equalizerController;
  bool _showLyrics = false;

  @override
  void initState() {
    super.initState();
    _equalizerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _equalizerController.dispose();
    super.dispose();
  }

  /// Pauses the equalizer whenever the pipeline is not actively synthesizing.
  void _syncEqualizer(bool isGenerating) {
    if (isGenerating) {
      if (!_equalizerController.isAnimating) {
        _equalizerController.repeat(reverse: true);
      }
    } else if (_equalizerController.isAnimating) {
      _equalizerController.stop();
    }
  }

  /// Re-opens the pipeline socket for the failed session.
  void _retry(GenerationProgressState state) {
    ref
        .read(generationProgressProvider.notifier)
        .startGeneration(
          generationId: state.generationId,
          trackTitle: state.trackTitle,
          genre: state.genre,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(generationProgressProvider);
    _syncEqualizer(state?.isGenerating ?? false);

    return VhunambiGlassSurface(
      borderRadius: AppRadius.cardBorder,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Result + New Song Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Result',
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
              if (widget.onNewSong != null)
                TextButton.icon(
                  key: const Key('generation_pipeline_dismiss_btn'),
                  onPressed: widget.onNewSong,
                  icon: const PhosphorIcon(
                    PhosphorIconsRegular.arrowCounterClockwise,
                    size: 16,
                  ),
                  label: const Text('New song'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.brandPrimary,
                    textStyle: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: state == null
                ? const _PipelineSkeletonLoader(
                    key: ValueKey<String>('pipeline-skeleton'),
                  )
                : _buildPipelineBody(state),
          ),
        ],
      ),
    );
  }

  /// State-driven body: title row, equalizer progress box and lyrics shelf.
  Widget _buildPipelineBody(GenerationProgressState state) {
    return Column(
      key: ValueKey<String>('pipeline-step-${state.currentStep.name}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Track Title, Genre Badge & Generating Pill
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Text(
                    state.trackTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleLarge.copyWith(fontSize: 22),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondaryOf(context),
                      borderRadius: AppRadius.pillBorder,
                      border: Border.all(
                        color: AppColors.borderSubtleOf(context),
                      ),
                    ),
                    child: Text(
                      state.genre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.badge.copyWith(
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  ),
                  if (state.attributionTag != null &&
                      state.attributionTag!.isNotEmpty)
                    Container(
                      key: const Key('pipeline_minimax_attribution_badge'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.coinGold.withValues(alpha: 0.16),
                        borderRadius: AppRadius.pillBorder,
                        border: Border.all(
                          color: AppColors.coinGold.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        'Engine: ${state.attributionTag}',
                        style: AppTypography.badge.copyWith(
                          color: AppColors.coinGold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (state.isGenerating) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.amberInset,
                  borderRadius: AppRadius.pillBorder,
                  border: Border.all(
                    color: AppColors.brandPrimary.withAlpha(120),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.brandPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Generating',
                      style: AppTypography.badge.copyWith(
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),

        // Inner Pipeline Progress Box
        Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          decoration: BoxDecoration(
            color: AppColors.surfaceSecondaryOf(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderSubtleOf(context)),
          ),
          child: Column(
            children: [
              // Animated Equalizer Visualizer
              AnimatedBuilder(
                animation: _equalizerController,
                builder: (context, _) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(11, (index) {
                      final centerDist = (index - 5).abs();
                      final baseHeight = 32.0 - (centerDist * 4.0);
                      final wave =
                          (_equalizerController.value * 12.0) *
                          (index % 2 == 0 ? 1 : -0.6);
                      final height = (baseHeight + wave).clamp(8.0, 36.0);

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: 4,
                        height: height,
                        decoration: BoxDecoration(
                          color: AppColors.brandPrimary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Dynamic Status Context Message
              Text(
                state.statusMessage,
                style: AppTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.coinGold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // 4-Stage Cinematic Telemetry Strip (Planning -> Composing -> Vocals/Stems -> Mastering)
              _BakeStageStrip(bakeStage: state.bakeStage),
              if (state.isGenerating) ...[
                const SizedBox(height: 10),
                Container(
                  key: const Key('pipeline_safe_to_explore_banner'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary.withValues(alpha: 0.1),
                    borderRadius: AppRadius.pillBorder,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const PhosphorIcon(
                        PhosphorIconsRegular.bellRinging,
                        size: 13,
                        color: AppColors.brandPrimary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Safe to explore — we notify you when your bake completes',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondaryOf(context),
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // 4-Step Synthesis Machine
              _buildStep(
                stepNumber: 1,
                label: 'Starting up...',
                isDone: state.stepNumber > 1,
                isActive: state.stepNumber == 1,
              ),
              const SizedBox(height: 12),
              _buildStep(
                stepNumber: 2,
                label: 'Writing lyrics...',
                isDone: state.stepNumber > 2,
                isActive: state.stepNumber == 2,
              ),
              const SizedBox(height: 12),
              _buildStep(
                stepNumber: 3,
                label: 'Producing the beat...',
                isDone: state.stepNumber > 3,
                isActive: state.stepNumber == 3,
              ),
              const SizedBox(height: 12),
              _buildStep(
                stepNumber: 4,
                label: 'Your song is ready!',
                isDone: state.stepNumber >= 4,
                isActive: false,
              ),
            ],
          ),
        ),
        if (state.hasFailed) ...[
          const SizedBox(height: 14),
          _ErrorBanner(
            message:
                state.errorMessage ?? 'Generation failed. Please try again.',
            onRetry: () => _retry(state),
          ),
        ],

        if (state.takes.length > 1) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < state.takes.length; i++)
                InkWell(
                  key: Key('pipeline_take_chip_$i'),
                  onTap: () => ref
                      .read(generationProgressProvider.notifier)
                      .selectActiveTake(i),
                  borderRadius: AppRadius.pillBorder,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 40),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: state.activeTakeIndex == i
                          ? AppColors.brandPrimary
                          : AppColors.surfaceSecondaryOf(context),
                      borderRadius: AppRadius.pillBorder,
                      border: Border.all(
                        color: state.activeTakeIndex == i
                            ? AppColors.brandPrimary
                            : AppColors.borderSubtleOf(context),
                      ),
                    ),
                    child: Text(
                      'Take ${i + 1}',
                      style: AppTypography.caption.copyWith(
                        color: state.activeTakeIndex == i
                            ? AppColors.brandContrast
                            : AppColors.textPrimaryOf(context),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],

        if (state.isReady && state.activeCompletedTrack != null) ...[
          const SizedBox(height: 14),
          _ReadyTrackCard(track: state.activeCompletedTrack!),
        ],
        if (state.generatedLyrics != null) ...[
          const SizedBox(height: 14),
          // Collapsible Lyrics Viewer Toggle
          InkWell(
            onTap: () => setState(() => _showLyrics = !_showLyrics),
            child: Row(
              children: [
                PhosphorIcon(
                  _showLyrics ? AppIcons.caretUp : AppIcons.caretDown,
                  color: AppColors.brandPrimary,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  _showLyrics ? 'Hide lyrics' : 'Show lyrics',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.brandPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          if (_showLyrics) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Text(
                    state.generatedLyrics!,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildStep({
    required int stepNumber,
    required String label,
    required bool isDone,
    required bool isActive,
  }) {
    Widget leading;
    Color textColor;

    if (isDone) {
      leading = Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          color: AppColors.brandPrimary,
          shape: BoxShape.circle,
        ),
        child: const PhosphorIcon(
          AppIcons.check,
          size: 14,
          color: AppColors.brandContrast,
        ),
      );
      textColor = AppColors.textPrimary;
    } else if (isActive) {
      leading = const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.brandPrimary),
        ),
      );
      textColor = AppColors.brandPrimary;
    } else {
      leading = Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.borderSubtle),
        ),
        alignment: Alignment.center,
        child: Text(
          '$stepNumber',
          style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
        ),
      );
      textColor = AppColors.textTertiary;
    }

    return Row(
      children: [
        leading,
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: textColor,
              fontWeight: isDone || isActive
                  ? FontWeight.w600
                  : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

/// Compact 4-pill backend stage strip (`Queued/Lyrics`, `Composing`, `Vocals/Stems`, `Mastering`).
class _BakeStageStrip extends StatelessWidget {
  final BakeStage bakeStage;

  const _BakeStageStrip({required this.bakeStage});

  static const List<String> _labels = <String>[
    'Plan Lyrics',
    'Compose Audio',
    'Vocals & Stems',
    'Master',
  ];

  @override
  Widget build(BuildContext context) {
    final activeIdx = bakeStage.stripIndex;
    return Wrap(
      key: const Key('pipeline_bake_stage_strip'),
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        for (var i = 0; i < _labels.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: activeIdx >= i
                  ? AppColors.brandPrimary.withValues(alpha: 0.16)
                  : AppColors.surfaceElevatedOf(context),
              borderRadius: AppRadius.pillBorder,
              border: Border.all(
                color: activeIdx == i
                    ? AppColors.brandPrimary
                    : AppColors.borderSubtleOf(context),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (activeIdx > i || bakeStage == BakeStage.ready)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: PhosphorIcon(
                      PhosphorIconsFill.checkCircle,
                      size: 11,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                Text(
                  _labels[i],
                  style: AppTypography.caption.copyWith(
                    color: activeIdx >= i
                        ? AppColors.brandPrimary
                        : AppColors.textSecondaryOf(context),
                    fontWeight: activeIdx == i
                        ? FontWeight.w800
                        : FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Pulsing placeholder shown before the pipeline reports its first frame.
class _PipelineSkeletonLoader extends StatefulWidget {
  const _PipelineSkeletonLoader({super.key});

  @override
  State<_PipelineSkeletonLoader> createState() =>
      _PipelineSkeletonLoaderState();
}

class _PipelineSkeletonLoaderState extends State<_PipelineSkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = _controller.drive(
      Tween<double>(
        begin: 0.35,
        end: 0.9,
      ).chain(CurveTween(curve: Curves.easeInOut)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FadeTransition(
          opacity: _opacity,
          child: const _SkeletonBar(widthFactor: 0.55, height: 18),
        ),
        const SizedBox(height: 18),
        for (var index = 0; index < 4; index++) ...[
          FadeTransition(
            opacity: _opacity,
            child: _SkeletonBar(widthFactor: 1.0 - (index * 0.12), height: 14),
          ),
          if (index < 3) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// Neutral placeholder row (token-driven, never raw hex).
class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({required this.widthFactor, required this.height});

  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surfaceSecondary,
          borderRadius: AppRadius.pillBorder,
        ),
      ),
    );
  }
}

/// Inline failure state with a retry CTA.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withAlpha(28),
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.error.withAlpha(120)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PhosphorIcon(
            PhosphorIconsRegular.warningCircle,
            size: 18,
            color: AppColors.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Generation failed',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.brandPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
              ),
              child: Text(
                'Retry',
                style: AppTypography.caption.copyWith(
                  color: AppColors.brandPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Action strip rendered once the pipeline reports ready with a master track.
class _ReadyTrackCard extends ConsumerWidget {
  final TrackEntity track;

  const _ReadyTrackCard({required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PhosphorIcon(
                AppIcons.checkCircle,
                color: AppColors.brandPrimary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  track.title,
                  style: AppTypography.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(track.formattedDuration, style: AppTypography.caption),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              ElevatedButton.icon(
                key: const Key('pipeline_play_master'),
                onPressed: () {
                  ref
                      .read(playerStateProvider.notifier)
                      .playTrack(track.toTrack());
                },
                icon: const PhosphorIcon(
                  AppIcons.play,
                  color: AppColors.brandContrast,
                ),
                label: Text(
                  'Play Master',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.brandContrast,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  minimumSize: const Size(0, 44),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.pillBorder,
                  ),
                ),
              ),
              OutlinedButton.icon(
                key: const Key('pipeline_create_reel_btn'),
                onPressed: () {
                  final normalizedAudio = AppConstants.normalizeCloudMediaUrl(
                    track.masterMp3Url,
                  );
                  final normalizedCover =
                      (track.coverUrl != null && track.coverUrl!.isNotEmpty)
                      ? AppConstants.normalizeCloudMediaUrl(track.coverUrl!)
                      : null;
                  final libTrack = LibraryTrack(
                    id: track.id,
                    title: track.title,
                    creatorName: 'Vhunambi Studio',
                    genre: track.genre,
                    language: track.language,
                    durationSeconds: track.duration.inSeconds,
                    remoteAudioUrl: normalizedAudio,
                    coverImageUrl: normalizedCover,
                    lyrics: track.lyrics,
                    createdAt: DateTime.now(),
                  );
                  KineticReelStudioView.show(context, initialTrack: libTrack);
                },
                icon: const PhosphorIcon(
                  AppIcons.reels,
                  size: 16,
                  color: AppColors.brandPrimary,
                ),
                label: Text(
                  'Create Reel',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.brandPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.brandPrimary),
                  minimumSize: const Size(0, 44),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.pillBorder,
                  ),
                ),
              ),
              if (track.hasStems)
                OutlinedButton.icon(
                  key: const Key('pipeline_download_stems'),
                  onPressed: () {
                    final downloader = ref.read(stemDownloadServiceProvider);
                    downloader.downloadStems(track.stemsUrl!);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Downloading stem bundle for ${track.title}...',
                        ),
                        backgroundColor: AppColors.surfaceElevatedOf(context),
                      ),
                    );
                  },
                  icon: PhosphorIcon(
                    AppIcons.download,
                    size: 16,
                    color: AppColors.textPrimaryOf(context),
                  ),
                  label: Text(
                    'Stems',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.borderSubtle),
                    minimumSize: const Size(0, 44),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.pillBorder,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
