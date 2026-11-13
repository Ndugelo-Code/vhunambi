import 'dart:async';

import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/services/haptics_service.dart';
import '../../../../core/design_system/theme/vhunambi_theme_extension.dart';
import '../../../../core/design_system/tokens/design_enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/studio_form_state.dart';
import '../providers/generation_pipeline_providers.dart';
import '../providers/lyrics_review_provider.dart';
import '../providers/melody_sketchpad_provider.dart';
import '../providers/studio_form_provider.dart';
import 'lyrics_review_modal.dart';

class StudioActionBar extends ConsumerWidget {
  const StudioActionBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(studioFormProvider);
    final notifier = ref.read(studioFormProvider.notifier);
    final genre = _mapStringToGenre(state.genre);
    final extension = VhunambiThemeExtension.of(context);
    final accent = extension.genreAccent(genre);

    // VH-002: Visibility subtitle tracks current state ("public" | "private").
    final isPublic = state.visibility == 'public';
    final isAiLyrics =
        !state.isInstrumental && state.lyricsMode == LyricsMode.aiWrite;
    final ctaLabel = isAiLyrics ? 'Write Lyrics First' : 'Generate Song';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sleek Single-Row Action Deck: Compact Visibility Pill + Un-truncated CTA
        Row(
          children: [
            Container(
              key: const Key('studio_visibility_toggle'),
              height: 46,
              padding: const EdgeInsets.only(left: AppSpacing.sm, right: 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: AppRadius.pillBorder,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PhosphorIcon(
                    isPublic
                        ? PhosphorIconsRegular.globe
                        : PhosphorIconsRegular.lockKey,
                    color: AppColors.brandPrimary,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isPublic ? 'Public' : 'Private',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Transform.scale(
                    scale: 0.72,
                    child: Switch(
                      value: isPublic,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (val) {
                        HapticsService().selectionClick();
                        notifier.setVisibility(val ? 'public' : 'private');
                      },
                      activeThumbColor: accent,
                      activeTrackColor: accent.withAlpha(80),
                      inactiveThumbColor: AppColors.textSecondary,
                      inactiveTrackColor: AppColors.surfaceElevated,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: () => _handleGenerate(context, ref),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: _contrastTextColor(accent),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.pillBorder,
                    ),
                    elevation: 3,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PhosphorIcon(
                        isAiLyrics
                            ? PhosphorIconsRegular.fileText
                            : PhosphorIconsRegular.sparkle,
                        size: 18,
                        color: _contrastTextColor(accent),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          ctaLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.titleSmall.copyWith(
                            color: _contrastTextColor(accent),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),

        // Commercial Licensing Terms — compact single-line footer (VH-003)
        Center(
          child: Text(
            'By generating, you agree to our Terms of Service. See licensing →',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
              fontSize: 9.5,
              height: 1.1,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  /// REQ-LYR-01/02 — AI lyrics mode pauses in `generatingLyrics`, drafts the
  /// stanzas, then opens the review cockpit before beat production.
  Future<void> _handleGenerate(BuildContext context, WidgetRef ref) async {
    HapticsService().heavyImpact();
    final formNotifier = ref.read(studioFormProvider.notifier);
    final formState = ref.read(studioFormProvider);
    final reviewLyrics =
        !formState.isInstrumental && formState.lyricsMode == LyricsMode.aiWrite;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceModal,
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.brandPrimary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                reviewLyrics
                    ? 'Synthesizing lyrics in ${formState.language} for review...'
                    : 'Generating ${formState.genre} track...',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );

    if (!reviewLyrics) {
      formNotifier.triggerGeneration();
      final rawLyrics = formState.customLyrics?.trim();
      final customLyrics = formState.isInstrumental
          ? null
          : ((rawLyrics != null && rawLyrics.isNotEmpty) ? rawLyrics : null);
      final musicalKey =
          formState.referenceAudioPath?.startsWith('sketchpad://') == true
          ? ref.read(melodySketchpadProvider).attachedPattern?.musicalKey ??
                formState.toSongMetadataDna().musical.key
          : formState.toSongMetadataDna().musical.key;
      unawaited(
        ref
            .read(generationProgressProvider.notifier)
            .submitAndStartGeneration(
              trackTitle: formState.resolvedTitle,
              prompt: formState.prompt,
              genre: formState.genre,
              language: formState.language,
              lyrics: customLyrics,
              isInstrumental: formState.isInstrumental,
              tempoBpm: formState.tempo.defaultBpm,
              musicalKey: musicalKey,
            ),
      );
      return;
    }

    formNotifier.beginLyricsReview();
    await ref
        .read(lyricsReviewProvider.notifier)
        .loadGeneratedLyrics(
          prompt: formState.prompt,
          genre: formState.genre,
          language: formState.language,
        );
    if (!context.mounted) return;
    formNotifier.markReviewingLyrics();

    await LyricsReviewModal.show(context);
    if (context.mounted &&
        ref.read(studioFormProvider).phase == GenerationPhase.reviewingLyrics) {
      formNotifier.cancelLyricsReview();
    }
  }

  /// Maps a free-form [genre] string from [StudioFormState] to a
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
