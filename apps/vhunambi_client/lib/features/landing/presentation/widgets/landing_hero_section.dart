import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../providers/landing_providers.dart';

/// Hero funnel section: new-music badge, gradient headline, quick-prompt bar and
/// the cinematic sample showcase (REQ-MKT-07).
class LandingHeroSection extends ConsumerStatefulWidget {
  static const String badgeLabel = '⚡ New: African AI Music';
  static const String headlineLead = 'Create ';
  static const String headlineAccent = 'African Music';
  static const String headlineTail = ' with a Single Prompt';
  static const String subtitle =
      'Type an idea, pick a genre, and create high-quality songs with authentic African rhythms and indigenous languages.';
  static const String generateLabel = 'Generate';
  static const String promptHint =
      'A powerful amapiano anthem about rising from hardship...';

  final VoidCallback? onGetStarted;

  const LandingHeroSection({super.key, this.onGetStarted});

  @override
  ConsumerState<LandingHeroSection> createState() => _LandingHeroSectionState();
}

class _LandingHeroSectionState extends ConsumerState<LandingHeroSection> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(landingHeroPromptProvider),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submitPrompt() {
    final messenger = ScaffoldMessenger.of(context);
    final draft = submitLandingPrompt(ref);

    if (draft == null) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceModal,
          duration: const Duration(seconds: 3),
          content: Text(
            'Describe your song first — then hit Generate.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
      );
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceModal,
        duration: const Duration(seconds: 3),
        content: Text(
          'Prompt loaded into the Studio cockpit.',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
    widget.onGetStarted?.call();
  }

  @override
  Widget build(BuildContext context) {
    final showcase = ref.watch(landingShowcaseTrackProvider);
    final isShowcasePlaying = ref.watch(
      playerStateProvider
          .select((s) => s.isPlaying && s.currentTrack?.id == showcase.id),
    );

    // Orange-to-amber gradient fill applied to the headline accent span.
    final accentPaint = Paint()
      ..shader = AppGradients.heroTextGradient.createShader(
        const Rect.fromLTWH(0, 0, 260, 40),
      );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      child: Column(
        children: [
          // `⚡ New: African AI Music` badge
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: AppColors.brandPrimary.withAlpha(38),
              borderRadius: AppRadius.pillBorder,
              border: Border.all(color: AppColors.brandPrimary),
            ),
            child: Text(
              LandingHeroSection.badgeLabel,
              style: AppTypography.caption.copyWith(
                color: AppColors.brandPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Gradient headline
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: LandingHeroSection.headlineLead),
                  TextSpan(
                    text: LandingHeroSection.headlineAccent,
                    style: TextStyle(foreground: accentPaint),
                  ),
                  const TextSpan(text: LandingHeroSection.headlineTail),
                ],
              ),
              textAlign: TextAlign.center,
              style: AppTypography.displayLarge,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Text(
              LandingHeroSection.subtitle,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMuted.copyWith(height: 1.5),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Quick-prompt bar
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Container(
              height: 52,
              padding: const EdgeInsets.only(
                left: AppSpacing.sm,
                right: AppSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: AppRadius.pillBorder,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Center(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        onChanged: (value) => ref
                            .read(landingHeroPromptProvider.notifier)
                            .state = value,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textPrimary,
                        ),
                        cursorColor: AppColors.brandPrimary,
                        decoration: InputDecoration(
                          hintText: LandingHeroSection.promptHint,
                          hintStyle: AppTypography.caption,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  ElevatedButton(
                    onPressed: _submitPrompt,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      foregroundColor: AppColors.brandContrast,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.pillBorder,
                      ),
                    ),
                    child: Text(
                      LandingHeroSection.generateLabel,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.brandContrast,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Cinematic showcase card
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: AppRadius.cardBorder,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => auditionLandingShowcase(ref),
                    borderRadius: AppRadius.pillBorder,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppColors.brandPrimary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isShowcasePlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 22,
                        color: AppColors.brandContrast,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          showcase.title,
                          style: AppTypography.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${showcase.genre} • ${showcase.language}',
                          style: AppTypography.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _AmplitudeBars(isPlaying: isShowcasePlaying),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Static amplitude visualizer with tap-to-seek scrubbing.
///
/// Intentionally not a repeating animation: the landing page must stay
/// `pumpAndSettle`-friendly for widget tests and idle-friendly on battery.
class _AmplitudeBars extends ConsumerWidget {
  static const double _width = 120;
  static const List<double> _barHeights = [8, 16, 22, 12, 19, 10, 20, 14];

  final bool isPlaying;

  const _AmplitudeBars({required this.isPlaying});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: _width,
      height: 28,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) {
          final ratio = (details.localPosition.dx / _width).clamp(0.0, 1.0);
          ref.read(playerStateProvider.notifier).seekByRatio(ratio);
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (final height in _barHeights)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 3,
                height: height,
                decoration: BoxDecoration(
                  color: isPlaying
                      ? AppColors.brandPrimary
                      : AppColors.textTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
