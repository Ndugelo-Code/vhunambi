import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/melody_sketchpad_provider.dart';
import '../providers/studio_form_provider.dart';
import 'melody_sketchpad_modal.dart';

class ReferenceAudioDropzone extends ConsumerStatefulWidget {
  const ReferenceAudioDropzone({super.key});

  @override
  ConsumerState<ReferenceAudioDropzone> createState() =>
      _ReferenceAudioDropzoneState();
}

class _ReferenceAudioDropzoneState
    extends ConsumerState<ReferenceAudioDropzone> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final referenceAudio = ref.watch(
      studioFormProvider.select((s) => s.referenceAudioPath),
    );
    final attachedPattern = ref.watch(
      melodySketchpadProvider.select((s) => s.attachedPattern),
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(
          color: referenceAudio != null
              ? AppColors.brandPrimary.withAlpha(80)
              : AppColors.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar / Accordion Toggle
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: AppRadius.cardBorder,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.graphic_eq_rounded,
                    size: 20,
                    color: AppColors.brandPrimary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Reference Audio (optional)',
                      style: AppTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (attachedPattern != null)
                    Container(
                      key: const Key('dropzone_active_sketchpad_badge'),
                      margin: const EdgeInsets.only(right: AppSpacing.xs),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withAlpha(35),
                        borderRadius: AppRadius.pillBorder,
                      ),
                      child: Text(
                        '${attachedPattern.instrument.emoji} ${attachedPattern.name} (${attachedPattern.musicalKey})',
                        style: AppTypography.badge.copyWith(
                          color: AppColors.success,
                        ),
                      ),
                    )
                  else if (referenceAudio != null)
                    Container(
                      margin: const EdgeInsets.only(right: AppSpacing.xs),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brandPrimary.withAlpha(40),
                        borderRadius: AppRadius.pillBorder,
                      ),
                      child: Text(
                        '1 Attached',
                        style: AppTypography.badge.copyWith(
                          color: AppColors.brandPrimary,
                        ),
                      ),
                    ),
                  IconButton(
                    key: const Key('dropzone_open_sketchpad_btn'),
                    tooltip: 'Compose Melody / Log-Drum Pattern',
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    icon: const Icon(
                      Icons.piano_rounded,
                      color: AppColors.brandPrimary,
                      size: 20,
                    ),
                    onPressed: () {
                      MelodySketchpadModal.show(context);
                    },
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),

          // Collapsible Content
          if (_isExpanded) ...[
            const Divider(color: AppColors.borderSubtle, height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Upload a song to use as a melody reference, remix source, or style inspiration. The AI will generate a new song influenced by your reference track.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // File Attached State vs Dropzone Container
                  if (referenceAudio != null)
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSecondary,
                        borderRadius: AppRadius.inputBorder,
                        border: Border.all(color: AppColors.brandPrimary),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.audio_file_rounded,
                            color: AppColors.brandPrimary,
                            size: 28,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  referenceAudio.split('/').last,
                                  style: AppTypography.bodyLarge.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Ready for style conditioning (Audio-to-Audio)',
                                  style: AppTypography.caption,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: AppColors.textSecondary,
                            ),
                            onPressed: () {
                              ref
                                  .read(studioFormProvider.notifier)
                                  .setReferenceAudio(null);
                            },
                          ),
                        ],
                      ),
                    )
                  else
                    // Upload Target Box
                    InkWell(
                      onTap: () {
                        // Mock simulated reference audio selection
                        ref
                            .read(studioFormProvider.notifier)
                            .setReferenceAudio('user_sample_stem_vocal.wav');
                      },
                      borderRadius: AppRadius.inputBorder,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xl,
                          horizontal: AppSpacing.md,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSecondary,
                          borderRadius: AppRadius.inputBorder,
                          border: Border.all(
                            color: AppColors.borderActive,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              decoration: const BoxDecoration(
                                color: AppColors.surfaceElevated,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.file_upload_rounded,
                                size: 28,
                                color: AppColors.brandPrimary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Drop audio file here or click to browse',
                              style: AppTypography.bodyLarge.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              'MP3, WAV, M4A, FLAC — max 50MB, up to 8 min',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
