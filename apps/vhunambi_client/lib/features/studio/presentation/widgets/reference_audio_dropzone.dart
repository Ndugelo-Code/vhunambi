import '../../../sound_signature/domain/services/audio_import_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/melody_sketchpad_provider.dart';
import '../providers/studio_form_provider.dart';
import 'melody_sketchpad_modal.dart';
import '../../../library/presentation/providers/library_providers.dart';
import '../../../beats/presentation/providers/beats_provider.dart';

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

    final isPlayingSketchpad = ref.watch(
      melodySketchpadProvider.select((s) => s.isPlayingPreview),
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(
          color: (referenceAudio != null || attachedPattern != null)
              ? AppColors.brandPrimary.withAlpha(80)
              : AppColors.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar / Accordion Toggle (Never squishes title text!)
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: AppRadius.cardBorder,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (referenceAudio != null && attachedPattern == null)
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
                      TextButton.icon(
                        key: const Key('dropzone_load_licensed_beat_btn'),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(44, 36),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                          ),
                          backgroundColor: AppColors.surfaceSecondary,
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.pillBorder,
                          ),
                        ),
                        onPressed: () => _showBeatPicker(context),
                        icon: const Icon(
                          Icons.shopping_bag_rounded,
                          color: AppColors.coinGold,
                          size: 16,
                        ),
                        label: Text(
                          'My Beats',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.coinGold,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                      TextButton.icon(
                        key: const Key('dropzone_open_sketchpad_btn'),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(44, 36),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                          ),
                          backgroundColor: AppColors.surfaceSecondary,
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.pillBorder,
                          ),
                        ),
                        onPressed: () {
                          MelodySketchpadModal.show(context);
                        },
                        icon: const Icon(
                          Icons.piano_rounded,
                          color: AppColors.brandPrimary,
                          size: 16,
                        ),
                        label: Text(
                          'Sketchpad',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.brandPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                  if (attachedPattern != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      key: const Key('dropzone_active_sketchpad_badge'),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withAlpha(30),
                        borderRadius: AppRadius.pillBorder,
                        border: Border.all(
                          color: AppColors.success.withAlpha(90),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${attachedPattern.instrument.emoji} ${attachedPattern.name} (${attachedPattern.musicalKey})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => ref
                                .read(melodySketchpadProvider.notifier)
                                .togglePreviewPlayback(),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              child: Icon(
                                isPlayingSketchpad
                                    ? Icons.stop_circle_rounded
                                    : Icons.play_circle_fill_rounded,
                                size: 18,
                                color: AppColors.success,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => ref
                                .read(melodySketchpadProvider.notifier)
                                .detachSongReference(),
                            child: Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Collapsible Content
          if (_isExpanded) ...[
            Divider(color: AppColors.borderSubtle, height: 1),
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
                            icon: Icon(
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
                      onTap: () async {
                        try {
                          const importService = AudioImportService();
                          final result = await importService.pickAndDecodeAudioFile();
                          if (result != null && context.mounted) {
                            ref
                                .read(studioFormProvider.notifier)
                                .setReferenceAudio(result.fileName);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(e.toString()),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        }
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
                              decoration: BoxDecoration(
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

  void _showBeatPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceModal,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.modalBorder,
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      builder: (bottomSheetContext) {
        return Consumer(
          builder: (context, ref, _) {
            final libraryTracks = ref.watch(libraryTracksProvider);
            final licensed = libraryTracks
                .where((t) =>
                    !t.isDeleted &&
                    (t.id.startsWith('market_') ||
                        (t.isInstrumental &&
                            t.licenseType.trim().isNotEmpty && t.licenseType != 'Commercial')))
                .toList();
            final produced = ref.watch(beatsProvider);
            final hasAny = licensed.isNotEmpty || produced.isNotEmpty;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.borderActive,
                          borderRadius: AppRadius.pillBorder,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Select Backing Beat',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Select a licensed or produced beat to lock tempo, key, and style.',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (!hasAny)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                        child: Center(
                          child: Text(
                            'No beats found in your vault yet.',
                            style: AppTypography.bodyMuted,
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            if (licensed.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  '🛍️ Licensed Beats',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.coinGold,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              for (final beat in licensed)
                                ListTile(
                                  leading: const Icon(
                                    Icons.album_rounded,
                                    color: AppColors.coinGold,
                                  ),
                                  title: Text(beat.title, style: AppTypography.bodySmall),
                                  subtitle: Text(
                                    '${beat.creatorName} • ${beat.genre}',
                                    style: AppTypography.caption,
                                  ),
                                  onTap: () {
                                    ref
                                        .read(studioFormProvider.notifier)
                                        .setReferenceAudio(beat.remoteAudioUrl);
                                    ref
                                        .read(studioFormProvider.notifier)
                                        .setGenre(beat.genre);
                                    ref
                                        .read(melodySketchpadProvider.notifier)
                                        .initializeFromRemixDna(genre: beat.genre);
                                    Navigator.of(bottomSheetContext).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Attached "${beat.title}" as backing beat 🎤',
                                        ),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                  },
                                ),
                            ],
                            if (produced.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  '🎛️ My Produced Beats',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.brandPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              for (final beat in produced)
                                ListTile(
                                  leading: const Icon(
                                    Icons.graphic_eq_rounded,
                                    color: AppColors.brandPrimary,
                                  ),
                                  title: Text(beat.title, style: AppTypography.bodySmall),
                                  subtitle: Text(
                                    '${beat.bpm} BPM • ${beat.musicalKey} • ${beat.genre}',
                                    style: AppTypography.caption,
                                  ),
                                  onTap: () {
                                    ref
                                        .read(studioFormProvider.notifier)
                                        .setReferenceAudio(beat.previewAudioUrl);
                                    ref
                                        .read(studioFormProvider.notifier)
                                        .setGenre(beat.genre);
                                    ref
                                        .read(melodySketchpadProvider.notifier)
                                        .initializeFromRemixDna(
                                          musicalKey: beat.musicalKey,
                                          bpm: beat.bpm,
                                          genre: beat.genre,
                                        );
                                    Navigator.of(bottomSheetContext).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Attached "${beat.title}" as backing beat 🎤',
                                        ),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
