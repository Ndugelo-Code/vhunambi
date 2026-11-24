import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/vhunambi_glass_surface.dart';
import '../../../media/domain/models/uploaded_media_asset.dart';
import '../../../media/presentation/providers/media_upload_queue_provider.dart';
import '../../data/services/studio_ai_assist_service.dart';
import '../../domain/models/studio_form_state.dart';
import '../providers/studio_form_provider.dart';

/// Full `vhunambi.com/create` production controls deck (`Phase 80` / `T80.3.4`):
/// Instrumental toggle, 3-mode Lyrics (`AI writes` / `My own` / `From photo`),
/// Engine Tier (`Fast Draft` / `Studio Bake` / `Sovereign Custom`) + live resolved
/// engine & MiniMax-Music3 attribution preview, Song Length (`10-360s`),
/// Auto/Custom Title, and Batch Take Count (`1-4`).
class StudioLyricsAndBakeDeck extends ConsumerStatefulWidget {
  const StudioLyricsAndBakeDeck({super.key});

  @override
  ConsumerState<StudioLyricsAndBakeDeck> createState() =>
      _StudioLyricsAndBakeDeckState();
}

class _StudioLyricsAndBakeDeckState
    extends ConsumerState<StudioLyricsAndBakeDeck> {
  late final TextEditingController _lyricsController;
  late final TextEditingController _titleController;
  late final TextEditingController _photoCaptionController;
  bool _isExtractingPhotoLyrics = false;

  @override
  void initState() {
    super.initState();
    final state = ref.read(studioFormProvider);
    _lyricsController = TextEditingController(text: state.customLyrics ?? '');
    _titleController = TextEditingController(text: state.customTitle ?? '');
    _photoCaptionController = TextEditingController();
  }

  @override
  void dispose() {
    _lyricsController.dispose();
    _titleController.dispose();
    _photoCaptionController.dispose();
    super.dispose();
  }

  Future<void> _pickPhotoAndExtractLyrics() async {
    if (_isExtractingPhotoLyrics) return;
    unawaited(HapticFeedback.mediumImpact());
    final picker = ImagePicker();
    XFile? picked;
    try {
      picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
    } catch (_) {
      picked = null;
    }

    if (!mounted || picked == null) return;
    final bytes = await picked.readAsBytes();
    await _extractFromImageBytes(
      bytes: bytes,
      filename: picked.name.isNotEmpty ? picked.name : 'studio_photo.jpg',
    );
  }

  Future<void> _extractFromImageBytes({
    required Uint8List bytes,
    required String filename,
  }) async {
    setState(() => _isExtractingPhotoLyrics = true);
    try {
      final asset = await ref
          .read(mediaUploadQueueProvider.notifier)
          .stageAndEnqueue(
            bytes: bytes,
            filename: filename,
            mimeType: 'image/jpeg',
            kind: MediaAssetKind.image,
            title: 'Lyrics Photo Seed',
            sourceSurface: 'studio',
          );
      if (!mounted) return;
      final photoUrl = asset.remoteUrl ?? asset.localFilePath ?? filename;
      ref.read(studioFormProvider.notifier).setSourcePhoto(
            path: asset.localFilePath ?? filename,
            url: asset.remoteUrl ?? photoUrl,
          );
      final form = ref.read(studioFormProvider);
      final extracted = await ref
          .read(studioAiAssistServiceProvider)
          .generateLyricsFromPhoto(
            photoUrl: photoUrl,
            captionHint: _photoCaptionController.text.trim(),
            genre: form.genre,
            language: form.language,
            mood: form.mood,
            ensemble: form.vocalVoices.name,
          );
      if (!mounted) return;
      ref.read(studioFormProvider.notifier).setCustomLyrics(extracted);
      _lyricsController.text = extracted;
    } finally {
      if (mounted) {
        setState(() => _isExtractingPhotoLyrics = false);
      }
    }
  }

  void _openVaultPhotoPicker(BuildContext context) {
    final images = ref
        .read(mediaUploadQueueProvider)
        .where((a) => a.kind == MediaAssetKind.image)
        .toList(growable: false);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceModalOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pick Photo from My Uploads',
                  style: AppTypography.titleSmall.copyWith(
                    color: AppColors.textPrimaryOf(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (images.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Text(
                      'No uploaded photos in your vault yet. Tap "Upload Photo" to add one.',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final img in images)
                          ListTile(
                            leading: const PhosphorIcon(
                              PhosphorIconsFill.image,
                              color: AppColors.brandPrimary,
                            ),
                            title: Text(img.title),
                            subtitle: Text(img.filename),
                            onTap: () async {
                              Navigator.of(sheetCtx).pop();
                              setState(() => _isExtractingPhotoLyrics = true);
                              try {
                                final form = ref.read(studioFormProvider);
                                final url = img.remoteUrl ?? img.localFilePath ?? img.filename;
                                ref
                                    .read(studioFormProvider.notifier)
                                    .setSourcePhoto(path: img.localFilePath, url: url);
                                final extracted = await ref
                                    .read(studioAiAssistServiceProvider)
                                    .generateLyricsFromPhoto(
                                      photoUrl: url,
                                      captionHint: _photoCaptionController.text.trim(),
                                      genre: form.genre,
                                      language: form.language,
                                      mood: form.mood,
                                      ensemble: form.vocalVoices.name,
                                    );
                                if (!mounted) return;
                                ref
                                    .read(studioFormProvider.notifier)
                                    .setCustomLyrics(extracted);
                                _lyricsController.text = extracted;
                              } finally {
                                if (mounted) {
                                  setState(() => _isExtractingPhotoLyrics = false);
                                }
                              }
                            },
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studioFormProvider);
    final notifier = ref.read(studioFormProvider.notifier);

    ref.listen(studioFormProvider.select((s) => s.customLyrics), (_, next) {
      final value = next ?? '';
      if (_lyricsController.text != value) {
        _lyricsController.text = value;
      }
    });
    ref.listen(studioFormProvider.select((s) => s.customTitle), (_, next) {
      final value = next ?? '';
      if (_titleController.text != value) {
        _titleController.text = value;
      }
    });

    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final borderSubtle = AppColors.borderSubtleOf(context);
    final surfaceSecondary = AppColors.surfaceSecondaryOf(context);

    return VhunambiGlassSurface(
      borderRadius: AppRadius.cardBorder,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header + Instrumental Only Toggle
          Row(
            children: [
              const PhosphorIcon(
                PhosphorIconsFill.slidersHorizontal,
                size: 18,
                color: AppColors.brandPrimary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Lyrics & Bake Production',
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
              ),
              Text(
                'Instrumental Only',
                style: AppTypography.caption.copyWith(
                  color: textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Switch(
                key: const Key('studio_instrumental_switch'),
                value: state.isInstrumental,
                onChanged: (val) {
                  unawaited(HapticFeedback.selectionClick());
                  notifier.toggleInstrumental(val);
                },
                activeThumbColor: AppColors.brandPrimary,
              ),
            ],
          ),

          // 3-Mode Lyrics Segment (when vocal mode is active)
          if (!state.isInstrumental) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Lyrics Mode',
              style: AppTypography.caption.copyWith(
                color: textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              key: const Key('studio_lyrics_mode_bar'),
              children: [
                _buildSegmentChip(
                  context: context,
                  chipKey: const Key('studio_lyrics_mode_ai'),
                  label: 'AI writes',
                  icon: AppIcons.sparkle,
                  isSelected: state.lyricsMode == LyricsMode.aiWrite,
                  onTap: () => notifier.setLyricsMode(LyricsMode.aiWrite),
                ),
                const SizedBox(width: 6),
                _buildSegmentChip(
                  context: context,
                  chipKey: const Key('studio_lyrics_mode_own'),
                  label: 'My own',
                  icon: AppIcons.edit,
                  isSelected: state.lyricsMode == LyricsMode.myOwn,
                  onTap: () => notifier.setLyricsMode(LyricsMode.myOwn),
                ),
                const SizedBox(width: 6),
                _buildSegmentChip(
                  context: context,
                  chipKey: const Key('studio_lyrics_mode_photo'),
                  label: 'From photo',
                  icon: PhosphorIconsRegular.camera,
                  isSelected: state.lyricsMode == LyricsMode.fromPhoto,
                  onTap: () => notifier.setLyricsMode(LyricsMode.fromPhoto),
                ),
              ],
            ),
            if (state.lyricsMode == LyricsMode.fromPhoto) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: surfaceSecondary.withValues(alpha: 0.7),
                  borderRadius: AppRadius.cardBorder,
                  border: Border.all(color: borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _photoCaptionController,
                      style: AppTypography.bodySmall.copyWith(color: textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Optional scene note (e.g. Sunset in Thohoyandou)...',
                        hintStyle: AppTypography.caption.copyWith(color: textSecondary),
                        isDense: true,
                        border: InputBorder.none,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        InkWell(
                          key: const Key('studio_from_photo_pick_btn'),
                          onTap: _pickPhotoAndExtractLyrics,
                          borderRadius: AppRadius.pillBorder,
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 44),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.brandPrimary.withValues(alpha: 0.16),
                              borderRadius: AppRadius.pillBorder,
                              border: Border.all(color: AppColors.brandPrimary),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PhosphorIcon(
                                  _isExtractingPhotoLyrics
                                      ? PhosphorIconsRegular.hourglassMedium
                                      : PhosphorIconsRegular.camera,
                                  size: 16,
                                  color: AppColors.brandPrimary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _isExtractingPhotoLyrics
                                      ? 'Extracting...'
                                      : 'Upload Photo & Extract',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.brandPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        InkWell(
                          key: const Key('studio_from_photo_vault_btn'),
                          onTap: () => _openVaultPhotoPicker(context),
                          borderRadius: AppRadius.pillBorder,
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 44),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: surfaceSecondary,
                              borderRadius: AppRadius.pillBorder,
                              border: Border.all(color: borderSubtle),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PhosphorIcon(
                                  PhosphorIconsRegular.images,
                                  size: 16,
                                  color: textPrimary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'From My Uploads',
                                  style: AppTypography.caption.copyWith(
                                    color: textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            if (state.lyricsMode == LyricsMode.myOwn ||
                (state.lyricsMode == LyricsMode.fromPhoto &&
                    (state.customLyrics?.trim().isNotEmpty ?? false))) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                decoration: BoxDecoration(
                  color: surfaceSecondary.withValues(alpha: 0.65),
                  borderRadius: AppRadius.inputBorder,
                  border: Border.all(color: borderSubtle),
                ),
                child: TextField(
                  key: const Key('studio_custom_lyrics_input'),
                  controller: _lyricsController,
                  onChanged: notifier.setCustomLyrics,
                  maxLines: 5,
                  minLines: 3,
                  style: AppTypography.bodySmall.copyWith(color: textPrimary),
                  decoration: InputDecoration(
                    hintText:
                        '[VERSE 1]\n[VOICE A]\nWrite your lyrics here...\n[VOICE B]\nAnswer with duet harmonies...',
                    hintStyle: AppTypography.caption.copyWith(color: textSecondary),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(AppSpacing.sm),
                  ),
                ),
              ),
            ],
          ],

          const SizedBox(height: AppSpacing.md),

          // Engine Tier Selector + Live Resolution Pill
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Bake Engine Tier',
                style: AppTypography.caption.copyWith(
                  color: textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                key: const Key('studio_resolved_engine_badge'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withValues(alpha: 0.14),
                  borderRadius: AppRadius.pillBorder,
                  border: Border.all(
                    color: AppColors.brandPrimary.withValues(alpha: 0.45),
                  ),
                ),
                child: Text(
                  state.resolvedAttributionTag != null
                      ? '${state.resolvedEnginePreview} • ${state.resolvedAttributionTag}'
                      : state.resolvedEnginePreview,
                  style: AppTypography.badge.copyWith(
                    color: AppColors.brandPrimary,
                    fontSize: 10.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            key: const Key('studio_engine_tier_selector'),
            children: [
              for (var i = 0; i < StudioEngineTier.values.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: _buildEngineTierCard(
                    context: context,
                    tier: StudioEngineTier.values[i],
                    isSelected: state.engineTier == StudioEngineTier.values[i],
                    onTap: () {
                      unawaited(HapticFeedback.selectionClick());
                      notifier.setEngineTier(StudioEngineTier.values[i]);
                    },
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Song Length Slider (10s - 360s, 300s sweet spot marker)
          Row(
            children: [
              Text(
                'Song Length',
                style: AppTypography.caption.copyWith(
                  color: textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                _formatDuration(state.durationSeconds),
                style: AppTypography.caption.copyWith(
                  color: AppColors.brandPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          Slider(
            key: const Key('studio_duration_slider'),
            min: 10,
            max: 360,
            divisions: 35,
            value: state.durationSeconds.clamp(10, 360).toDouble(),
            activeColor: AppColors.brandPrimary,
            onChanged: (val) => notifier.setDurationSeconds(val.round()),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final presetSec in const <int>[30, 90, 180, 240, 300])
                InkWell(
                  onTap: () => notifier.setDurationSeconds(presetSec),
                  borderRadius: AppRadius.pillBorder,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 36),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: state.durationSeconds == presetSec
                          ? AppColors.brandPrimary.withValues(alpha: 0.18)
                          : surfaceSecondary,
                      borderRadius: AppRadius.pillBorder,
                      border: Border.all(
                        color: state.durationSeconds == presetSec
                            ? AppColors.brandPrimary
                            : borderSubtle,
                      ),
                    ),
                    child: Text(
                      _formatDuration(presetSec),
                      style: AppTypography.caption.copyWith(
                        color: state.durationSeconds == presetSec
                            ? AppColors.brandPrimary
                            : textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Auto / Custom Song Title + Batch Count (1-4 Takes)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Title',
                    style: AppTypography.caption.copyWith(
                      color: textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    key: const Key('studio_title_mode_toggle'),
                    onTap: () => notifier.toggleAutoTitle(!state.isAutoTitle),
                    borderRadius: AppRadius.pillBorder,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: surfaceSecondary,
                        borderRadius: AppRadius.pillBorder,
                        border: Border.all(color: borderSubtle),
                      ),
                      child: Text(
                        state.isAutoTitle ? 'Auto Title' : 'Custom Title',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.brandPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Songs',
                    style: AppTypography.caption.copyWith(
                      color: textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Row(
                    key: const Key('studio_batch_count_selector'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final count in const <int>[1, 2, 3, 4])
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: InkWell(
                            key: Key('studio_batch_chip_$count'),
                            onTap: () => notifier.setBatchCount(count),
                            borderRadius: AppRadius.pillBorder,
                            child: Container(
                              constraints: const BoxConstraints(
                                minWidth: 44,
                                minHeight: 44,
                              ),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: state.batchCount == count
                                    ? AppColors.brandPrimary
                                    : surfaceSecondary,
                                borderRadius: AppRadius.pillBorder,
                                border: Border.all(
                                  color: state.batchCount == count
                                      ? AppColors.brandPrimary
                                      : borderSubtle,
                                ),
                              ),
                              child: Text(
                                '$count',
                                style: AppTypography.caption.copyWith(
                                  color: state.batchCount == count
                                      ? AppColors.brandContrast
                                      : textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          if (!state.isAutoTitle) ...[
            const SizedBox(height: AppSpacing.xs),
            Container(
              decoration: BoxDecoration(
                color: surfaceSecondary.withValues(alpha: 0.65),
                borderRadius: AppRadius.inputBorder,
                border: Border.all(color: borderSubtle),
              ),
              child: TextField(
                key: const Key('studio_custom_title_input'),
                controller: _titleController,
                onChanged: notifier.setCustomTitle,
                style: AppTypography.bodySmall.copyWith(color: textPrimary),
                decoration: InputDecoration(
                  hintText: 'Enter song title...',
                  hintStyle: AppTypography.caption.copyWith(color: textSecondary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSegmentChip({
    required BuildContext context,
    required Key chipKey,
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        key: chipKey,
        onTap: onTap,
        borderRadius: AppRadius.pillBorder,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.brandPrimary
                : AppColors.surfaceSecondaryOf(context),
            borderRadius: AppRadius.pillBorder,
            border: Border.all(
              color: isSelected
                  ? AppColors.brandPrimary
                  : AppColors.borderSubtleOf(context),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PhosphorIcon(
                icon,
                size: 14,
                color: isSelected
                    ? AppColors.brandContrast
                    : AppColors.textSecondaryOf(context),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: isSelected
                        ? AppColors.brandContrast
                        : AppColors.textPrimaryOf(context),
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEngineTierCard({
    required BuildContext context,
    required StudioEngineTier tier,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: Key('engine_tier_${tier.wireValue}'),
      onTap: onTap,
      borderRadius: AppRadius.cardBorder,
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brandPrimary.withValues(alpha: 0.16)
              : AppColors.surfaceSecondaryOf(context),
          borderRadius: AppRadius.cardBorder,
          border: Border.all(
            color: isSelected
                ? AppColors.brandPrimary
                : AppColors.borderSubtleOf(context),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tier.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: isSelected
                    ? AppColors.brandPrimary
                    : AppColors.textPrimaryOf(context),
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              tier.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondaryOf(context),
                fontSize: 9.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDuration(int totalSeconds) {
    final mins = totalSeconds ~/ 60;
    final secs = totalSeconds % 60;
    if (mins == 0) return '${secs}s';
    if (secs == 0) return '${mins}m';
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }
}
